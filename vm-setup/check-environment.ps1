param(
    [int]$TiaMajorVersion = 20
)

$ErrorActionPreference = "Continue"
$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
$mcpExe = "$ProjectRoot\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"

function Write-Ok($msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Info($msg) { Write-Host "  $msg" -ForegroundColor Gray }
function Write-Step($msg) { Write-Host "`n[$msg]" -ForegroundColor Cyan }

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  TIA Portal MCP - Environment Check" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""

Write-Step "System"
Write-Info "OS: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)"
Write-Info "User: $env:USERNAME"
Write-Info "Computer: $env:COMPUTERNAME"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Ok "Running as Administrator"
} else {
    Write-Warn "Not running as Administrator"
}

Write-Step ".NET Framework 4.8"
$ndpKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue
if ($ndpKey -and $ndpKey.Release -ge 528040) {
    Write-Ok "Installed (Release: $($ndpKey.Release))"
} else {
    Write-Fail "Not installed"
}

$targetingPack = "${env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8"
if (Test-Path $targetingPack) {
    Write-Ok "Developer Pack installed"
} else {
    Write-Warn "Developer Pack not installed (needed for building)"
}

Write-Step "TIA Portal V$TiaMajorVersion"
$tiaPaths = @(
    "C:\Program Files\Siemens\Automation\Portal V$TiaMajorVersion",
    "D:\Program Files\Siemens\Automation\Portal V$TiaMajorVersion"
)
$tiaFound = $false
foreach ($path in $tiaPaths) {
    if (Test-Path $path) {
        Write-Ok "Found: $path"
        $tiaFound = $true
        
        $tiaExe = Join-Path $path "Bin\Siemens.Automation.Portal.exe"
        if (Test-Path $tiaExe) {
            $exeInfo = Get-Item $tiaExe
            Write-Info "Exe: $($exeInfo.LastWriteTime)"
        }
        break
    }
}
if (-not $tiaFound) {
    Write-Fail "Not found"
}

Write-Step "TiaPortalLocation Environment"
$tiaEnv = [Environment]::GetEnvironmentVariable("TiaPortalLocation", "User")
if ($tiaEnv) {
    Write-Ok "User: $tiaEnv"
} else {
    $tiaEnv = [Environment]::GetEnvironmentVariable("TiaPortalLocation", "Machine")
    if ($tiaEnv) {
        Write-Ok "System: $tiaEnv"
    } else {
        Write-Warn "Not set"
    }
}

Write-Step "Siemens TIA Openness Group"
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$isInGroup = $false
foreach ($group in $identity.Groups) {
    try {
        $sid = $group.Translate([System.Security.Principal.NTAccount]).ToString()
        if ($sid -like "*Siemens TIA Openness*") {
            $isInGroup = $true
            Write-Ok "User is in group"
            break
        }
    } catch {}
}
if (-not $isInGroup) {
    Write-Fail "User is NOT in group"
    Write-Info "Run TIA Portal once, then run setup-vm.ps1"
}

Write-Step "MCP Server"
if (Test-Path $mcpExe) {
    $exeInfo = Get-Item $mcpExe
    Write-Ok "Found: $mcpExe"
    Write-Info "Size: $([math]::Round($exeInfo.Length/1KB, 2)) KB"
    Write-Info "Modified: $($exeInfo.LastWriteTime)"
} else {
    Write-Fail "Not found: $mcpExe"
    Write-Info "Build the project: dotnet build src\TiaMcpServer\TiaMcpServer.csproj -c Release"
}

Write-Step "TIA Portal Process"
$tiaProcess = Get-Process -Name "Siemens.Automation.Portal" -ErrorAction SilentlyContinue
if ($tiaProcess) {
    Write-Ok "Running (PID: $($tiaProcess.Id -join ', '))"
} else {
    Write-Info "Not running"
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Environment Check Complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""