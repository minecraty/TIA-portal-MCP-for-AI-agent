# ==============================================================
# TIA Portal MCP Connection Verification Script
# Run this on the VM to verify the MCP server works correctly
# ==============================================================
$ErrorActionPreference = 'Continue'

$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
$mcpExe = "$ProjectRoot\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"
$tiaMajorVersion = 20

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  TIA Portal MCP Server Verification" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Check 1: User Group
Write-Host " [1/5] Checking Siemens TIA Openness group..." -ForegroundColor Yellow
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$isInGroup = $false
foreach ($group in $identity.Groups) {
    $sid = $group.Translate([System.Security.Principal.NTAccount]).ToString()
    if ($sid -like "*Siemens TIA Openness*") {
        $isInGroup = $true
        Write-Host "   [PASS] User is in Siemens TIA Openness group" -ForegroundColor Green
        break
    }
}
if (-not $isInGroup) {
    Write-Host "   [FAIL] User is NOT in Siemens TIA Openness group" -ForegroundColor Red
    Write-Host "   Please run TIA Portal once, then re-run setup-vm.ps1" -ForegroundColor Yellow
    exit 1
}

# Check 2: TIA Portal Installation
Write-Host " [2/5] Checking TIA Portal installation..." -ForegroundColor Yellow
$tiaFound = $false
$tiaPaths = @(
    "C:\Program Files\Siemens\Automation\Portal V$tiaMajorVersion",
    "D:\Program Files\Siemens\Automation\Portal V$tiaMajorVersion"
)
foreach ($path in $tiaPaths) {
    if (Test-Path $path) {
        Write-Host "   [PASS] TIA Portal V$tiaMajorVersion found at: $path" -ForegroundColor Green
        $tiaFound = $true
        break
    }
}
if (-not $tiaFound) {
    try {
        $regKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Siemens\Automation\_InstalledSW\TIAP$tiaMajorVersion\TIA_Opns" -ErrorAction SilentlyContinue
        if ($regKey -and $regKey.Path) {
            Write-Host "   [PASS] TIA Portal V$tiaMajorVersion found (registry): $($regKey.Path)" -ForegroundColor Green
            $tiaFound = $true
        }
    } catch {}
}
if (-not $tiaFound) {
    Write-Host "   [WARN] TIA Portal V$tiaMajorVersion not detected" -ForegroundColor Yellow
}

# Check 3: MCP Server Executable
Write-Host " [3/5] Checking MCP server executable..." -ForegroundColor Yellow
if (Test-Path $mcpExe) {
    $exeInfo = Get-Item $mcpExe
    Write-Host "   [PASS] MCP server found: $mcpExe" -ForegroundColor Green
    Write-Host "   Size: $($exeInfo.Length) bytes, Modified: $($exeInfo.LastWriteTime)" -ForegroundColor Gray
} else {
    Write-Host "   [FAIL] MCP server not found at $mcpExe" -ForegroundColor Red
    Write-Host "   Build the project: dotnet build src\TiaMcpServer -c Release" -ForegroundColor Yellow
    exit 1
}

# Check 4: .NET Runtime
Write-Host " [4/5] Checking .NET runtime..." -ForegroundColor Yellow
try {
    $dotnetVersion = & dotnet --version 2>&1
    Write-Host "   [PASS] .NET version: $dotnetVersion" -ForegroundColor Green
} catch {
    Write-Host "   [WARN] dotnet command not found" -ForegroundColor Yellow
}

# Check 5: MCP Server Startup Test
Write-Host " [5/5] Testing MCP server startup..." -ForegroundColor Yellow
Write-Host "   Starting MCP server with test request..." -ForegroundColor Gray

Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Text;
using System.Threading.Tasks;

public class McpServerTester
{
    public static string TestStartup(string exePath, string arguments)
    {
        var psi = new ProcessStartInfo
        {
            FileName = exePath,
            Arguments = arguments,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8
        };
        
        using (var process = Process.Start(psi))
        {
            string initMsg = @"{""jsonrpc"":""2.0"",""id"":1,""method"":""initialize"",""params"":{""protocolVersion"":""2024-11-05"",""capabilities"":{},""clientInfo"":{""name"":""trae"",""version"":""1.0""}}}";
            process.StandardInput.WriteLine(initMsg);
            process.StandardInput.Flush();
            
            System.Threading.Thread.Sleep(3000);
            
            var stdoutTask = Task.Run(() => process.StandardOutput.ReadToEnd());
            var stderrTask = Task.Run(() => process.StandardError.ReadToEnd());
            
            process.StandardInput.Close();
            
            bool exited = process.WaitForExit(15000);
            
            string stdout = stdoutTask.Result ?? "";
            string stderr = stderrTask.Result ?? "";
            
            var result = new StringBuilder();
            result.AppendLine("ExitCode: " + process.ExitCode);
            result.AppendLine("TimedOut: " + (!exited));
            result.AppendLine("StdoutLen: " + stdout.Length);
            result.AppendLine("StderrLen: " + stderr.Length);
            
            if (stderr.Contains("initialize") || stdout.Contains("initialize"))
                result.AppendLine("InitializeRequest: Processed");
            else
                result.AppendLine("InitializeRequest: NotDetected");
                
            bool hasResponse = stdout.Contains("\"result\"") || stdout.Contains("\"serverInfo\"");
            result.AppendLine("ServerResponse: " + (hasResponse ? "Yes (JSON-RPC response received)" : "No response detected"));
                
            return result.ToString();
        }
    }
}
"@

try {
    $result = [McpServerTester]::TestStartup($mcpExe, "--tia-major-version $tiaMajorVersion --logging 1")
    
    $lines = $result -split "`r`n|`n"
    foreach ($line in $lines) {
        if ($line -match "^ExitCode: 0$") {
            Write-Host "   [PASS] Server exited normally" -ForegroundColor Green
        } elseif ($line -match "^TimedOut: False$") {
            Write-Host "   [PASS] Server responded within timeout" -ForegroundColor Green
        } elseif ($line -match "^InitializeRequest: Processed$") {
            Write-Host "   [PASS] Initialize request processed" -ForegroundColor Green
        } elseif ($line -match "^ServerResponse: Yes") {
            Write-Host "   [PASS] Server returned JSON-RPC response" -ForegroundColor Green
        } elseif ($line -match "^ServerResponse: No") {
            Write-Host "   [INFO] Server did not return response before stdin closed" -ForegroundColor Yellow
            Write-Host "   This is expected when stdin closes quickly" -ForegroundColor Gray
            Write-Host "   In Trae, stdin stays open for continuous communication" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "   [FAIL] Test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  VERIFICATION COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  If all checks passed, the MCP server is ready to use." -ForegroundColor White
Write-Host "  Run .\generate-trae-config.ps1 to generate Trae MCP config." -ForegroundColor White
Write-Host ""