param(
    [int]$TiaMajorVersion = 20,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
$mcpExe = "$ProjectRoot\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"

function Write-Pass($msg) { Write-Host "[PASS] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Info($msg) { Write-Host "       $msg" -ForegroundColor Gray }
function Write-Step($msg) { Write-Host "`n== $msg ==" -ForegroundColor Cyan }

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  TIA Portal MCP - Local Test" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""

$tests = @{
    NetFramework = $false
    TiaPortal = $false
    UserGroup = $false
    McpServer = $false
    McpResponse = $false
}

Write-Step "1. Check Administrator"
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Pass "Running as Administrator"
} else {
    Write-Warn "Not running as Administrator (not required for testing)"
}

Write-Step "2. Check .NET Framework 4.8"
$ndpKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue
if ($ndpKey -and $ndpKey.Release -ge 528040) {
    Write-Pass ".NET Framework 4.8 installed (Release: $($ndpKey.Release))"
    $tests.NetFramework = $true
} else {
    Write-Fail ".NET Framework 4.8 not found"
}

Write-Step "3. Check TIA Portal V$TiaMajorVersion"
$tiaPaths = @(
    "C:\Program Files\Siemens\Automation\Portal V$TiaMajorVersion",
    "D:\Program Files\Siemens\Automation\Portal V$TiaMajorVersion"
)
$tiaFound = $false
foreach ($path in $tiaPaths) {
    if (Test-Path $path) {
        Write-Pass "TIA Portal V$TiaMajorVersion found: $path"
        $tiaFound = $true
        break
    }
}
if (-not $tiaFound) {
    try {
        $regKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Siemens\Automation\_InstalledSW\TIAP$TiaMajorVersion\TIA_Opns" -ErrorAction SilentlyContinue
        if ($regKey -and $regKey.Path) {
            Write-Pass "TIA Portal V$TiaMajorVersion found (registry): $($regKey.Path)"
            $tiaFound = $true
        }
    } catch {}
}
if ($tiaFound) {
    $tests.TiaPortal = $true
} else {
    Write-Fail "TIA Portal V$TiaMajorVersion not found"
}

Write-Step "4. Check Siemens TIA Openness Group"
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$isInGroup = $false
foreach ($group in $identity.Groups) {
    try {
        $sid = $group.Translate([System.Security.Principal.NTAccount]).ToString()
        if ($sid -like "*Siemens TIA Openness*") {
            $isInGroup = $true
            Write-Pass "User is in Siemens TIA Openness group"
            break
        }
    } catch {}
}
if ($isInGroup) {
    $tests.UserGroup = $true
} else {
    Write-Fail "User is NOT in Siemens TIA Openness group"
    Write-Info "Run TIA Portal once, then run setup-vm.ps1"
}

Write-Step "5. Check MCP Server"
if (Test-Path $mcpExe) {
    $exeInfo = Get-Item $mcpExe
    Write-Pass "MCP server found: $mcpExe"
    Write-Info "Size: $($exeInfo.Length) bytes"
    $tests.McpServer = $true
} else {
    Write-Fail "MCP server not found: $mcpExe"
    Write-Info "Build the project first:"
    Write-Info "  dotnet build src\TiaMcpServer\TiaMcpServer.csproj -c Release"
}

Write-Step "6. Test MCP Server Response"
if ($tests.McpServer) {
    $initRequest = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $mcpExe
    $psi.Arguments = "--tia-major-version $TiaMajorVersion"
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    try {
        $process = [System.Diagnostics.Process]::Start($psi)
        $process.StandardInput.WriteLine($initRequest)
        $process.StandardInput.Flush()
        
        Start-Sleep -Milliseconds 2000
        
        $outputTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        
        $process.StandardInput.Close()
        
        $exited = $process.WaitForExit(10000)
        
        $output = $outputTask.Result
        $stderr = $stderrTask.Result
        
        if ($output -match '"result"') {
            Write-Pass "MCP server responds correctly"
            $tests.McpResponse = $true
            if ($Verbose) {
                Write-Info "Response: $output"
            }
        } else {
            Write-Fail "MCP server did not respond correctly"
            if ($Verbose) {
                Write-Info "Output: $output"
                if ($stderr) {
                    Write-Info "Stderr: $stderr"
                }
            }
        }
    } catch {
        Write-Fail "Failed to start MCP server: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
$passed = ($tests.Values | Where-Object { $_ }).Count
$total = $tests.Count

if ($passed -eq $total) {
    Write-Host "  ALL TESTS PASSED ($passed/$total)" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  MCP server is ready for use!" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "  SOME TESTS FAILED ($passed/$total)" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    exit 1
}