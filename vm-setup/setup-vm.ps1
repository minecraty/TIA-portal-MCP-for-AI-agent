#Requires -RunAsAdministrator

param(
    [int]$TiaMajorVersion = 20
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path "$PSScriptRoot\.."

function Write-Step($title) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

function Write-Ok($msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Fail($msg) {
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
}

function Write-Warn($msg) {
    Write-Host "  [WARN] $msg" -ForegroundColor Yellow
}

function Write-Info($msg) {
    Write-Host "  $msg" -ForegroundColor Gray
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  TIA Portal MCP Server - VM Setup Script" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""

# -------------------------------------------------------
# Step 1: Check .NET Framework 4.8
# -------------------------------------------------------
Write-Step "Step 1/6: Check .NET Framework 4.8"

$ndpKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue
if ($ndpKey -and $ndpKey.Release -ge 528040) {
    Write-Ok ".NET Framework 4.8 is installed (Release: $($ndpKey.Release))"
} else {
    Write-Fail ".NET Framework 4.8 is NOT installed"
    Write-Host ""
    Write-Host "  Please install .NET Framework 4.8 first:" -ForegroundColor Yellow
    Write-Host "  https://dotnet.microsoft.com/download/dotnet-framework/net48" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  For building the project, install the Developer Pack:" -ForegroundColor Yellow
    Write-Host "  https://dotnet.microsoft.com/download/dotnet-framework/net48-developer-pack" -ForegroundColor Yellow
    exit 1
}

# -------------------------------------------------------
# Step 2: Check .NET Framework 4.8 Developer Pack (Targeting Pack)
# -------------------------------------------------------
Write-Step "Step 2/6: Check .NET Framework 4.8 Developer Pack"

$targetingPackPath = "${env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.8"
if (Test-Path $targetingPackPath) {
    Write-Ok ".NET Framework 4.8 Targeting Pack is installed"
} else {
    Write-Warn ".NET Framework 4.8 Targeting Pack (Developer Pack) is NOT installed"
    Write-Host ""
    Write-Host "  The Developer Pack is required for building the project." -ForegroundColor Yellow
    Write-Host "  Download from:" -ForegroundColor Yellow
    Write-Host "  https://dotnet.microsoft.com/download/dotnet-framework/net48-developer-pack" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  After installing, re-run this script." -ForegroundColor Yellow
    exit 1
}

# -------------------------------------------------------
# Step 3: Detect TIA Portal
# -------------------------------------------------------
Write-Step "Step 3/6: Detect TIA Portal V$TiaMajorVersion"

$tiaInstallPath = $null

try {
    $regBaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        [Microsoft.Win32.RegistryView]::Registry64
    )
    $tiaKey = $regBaseKey.OpenSubKey("SOFTWARE\Siemens\Automation\_InstalledSW\TIAP$TiaMajorVersion\TIA_Opns")
    if ($tiaKey) {
        $tiaInstallPath = $tiaKey.GetValue("Path")
        $tiaKey.Close()
    }
    $regBaseKey.Close()
} catch {}

if ($tiaInstallPath) {
    Write-Ok "TIA Portal V$TiaMajorVersion detected at: $tiaInstallPath"
} else {
    Write-Warn "TIA Portal V$TiaMajorVersion not found in registry"
    Write-Info "Searching common install paths..."

    $commonPaths = @(
        "C:\Program Files\Siemens\Automation\Portal V$TiaMajorVersion",
        "D:\Program Files\Siemens\Automation\Portal V$TiaMajorVersion"
    )
    foreach ($p in $commonPaths) {
        if (Test-Path $p) {
            $tiaInstallPath = $p
            Write-Ok "Found TIA Portal at: $tiaInstallPath"
            break
        }
    }

    if (-not $tiaInstallPath) {
        Write-Fail "TIA Portal V$TiaMajorVersion not found"
        $tiaInstallPath = Read-Host "  Enter TIA Portal install path manually (or press Enter to skip)"
        if (-not $tiaInstallPath) {
            Write-Warn "Skipping TIA Portal path configuration"
        }
    }
}

# -------------------------------------------------------
# Step 4: Set TiaPortalLocation environment variable
# -------------------------------------------------------
Write-Step "Step 4/6: Set TiaPortalLocation environment variable"

if ($tiaInstallPath) {
    $currentValue = [Environment]::GetEnvironmentVariable("TiaPortalLocation", "User")
    if ($currentValue -eq $tiaInstallPath) {
        Write-Ok "TiaPortalLocation is already set correctly"
    } else {
        [Environment]::SetEnvironmentVariable("TiaPortalLocation", $tiaInstallPath, "User")
        $env:TiaPortalLocation = $tiaInstallPath
        Write-Ok "TiaPortalLocation set to: $tiaInstallPath"
    }
} else {
    Write-Warn "Skipping - TIA Portal path not available"
}

# -------------------------------------------------------
# Step 5: Add user to Siemens TIA Openness group
# -------------------------------------------------------
Write-Step "Step 5/6: Add user to 'Siemens TIA Openness' group"

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$userName = $currentUser.Split('\')[-1]

try {
    $group = Get-LocalGroup -Name "Siemens TIA Openness" -ErrorAction SilentlyContinue
    if (-not $group) {
        Write-Warn "Group 'Siemens TIA Openness' does not exist yet"
        Write-Info "This group is created when TIA Portal is started for the first time"
        Write-Info "Please start TIA Portal once, then re-run this script"
    } else {
        $members = Get-LocalGroupMember -Name "Siemens TIA Openness" -ErrorAction SilentlyContinue
        $isMember = $members | Where-Object { $_.PrincipalSource -eq 'Local' -and $_.ObjectClass -eq 'User' -and $_.Name -eq $currentUser }

        if ($isMember) {
            Write-Ok "User '$currentUser' is already in 'Siemens TIA Openness' group"
        } else {
            Add-LocalGroupMember -Name "Siemens TIA Openness" -Member $userName -ErrorAction Stop
            Write-Ok "User '$currentUser' added to 'Siemens TIA Openness' group"
            Write-Warn "You must LOG OUT and LOG BACK IN for group membership to take effect"
        }
    }
} catch {
    Write-Warn "Could not add user to group: $($_.Exception.Message)"
    Write-Info "You can add manually: Computer Management > Local Users and Groups > Groups > Siemens TIA Openness > Add"
}

# -------------------------------------------------------
# Step 6: Summary
# -------------------------------------------------------
Write-Step "Step 6/6: Setup Summary"

$mcpExePath = "$ProjectRoot\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"
$mcpBuilt = Test-Path $mcpExePath

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  TIA Portal Version:  V$TiaMajorVersion" -ForegroundColor White
Write-Host "  Project Root:        $ProjectRoot" -ForegroundColor White
Write-Host ""

if ($mcpBuilt) {
    Write-Host "  MCP Server:          $mcpExePath" -ForegroundColor White
    Write-Host ""
    Write-Host "  The MCP server is ready to use." -ForegroundColor Green
} else {
    Write-Host "  Next: Build the MCP server" -ForegroundColor Yellow
    Write-Host "    cd $ProjectRoot" -ForegroundColor White
    Write-Host "    dotnet build src\TiaMcpServer\TiaMcpServer.csproj -c Release" -ForegroundColor White
    Write-Host ""
}

Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "  1. Build the project: dotnet build src\TiaMcpServer\TiaMcpServer.csproj -c Release" -ForegroundColor Yellow
Write-Host "  2. Verify setup:       .\test-local-mcp.ps1" -ForegroundColor Yellow
Write-Host "  3. Generate config:    .\generate-trae-config.ps1" -ForegroundColor Yellow
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host "  VM Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

$groupWarning = $false
try {
    $members = Get-LocalGroupMember -Name "Siemens TIA Openness" -ErrorAction SilentlyContinue
    $isMember = $members | Where-Object { $_.Name -eq $currentUser }
    if (-not $isMember) { $groupWarning = $true }
} catch {
    $groupWarning = $true
}

if ($groupWarning) {
    Write-Host "  IMPORTANT: If you were added to 'Siemens TIA Openness' group," -ForegroundColor Red
    Write-Host "  you MUST log out and log back in before using TiaMcpServer!" -ForegroundColor Red
    Write-Host ""
}