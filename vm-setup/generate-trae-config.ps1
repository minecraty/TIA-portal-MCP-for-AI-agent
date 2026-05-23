param(
    [int]$TiaMajorVersion = 20,
    [string]$McpExePath
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path "$PSScriptRoot\.."

if (-not $McpExePath) {
    $McpExePath = "$ProjectRoot\src\TiaMcpServer\bin\Release\net48\TiaMcpServer.exe"
}

function Write-Ok($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "     $msg" -ForegroundColor Gray }

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  Generate Trae MCP Configuration" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""

if (-not (Test-Path $McpExePath)) {
    Write-Host "[FAIL] MCP server not found: $McpExePath" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Build the project first:" -ForegroundColor Yellow
    Write-Host "    dotnet build src\TiaMcpServer\TiaMcpServer.csproj -c Release" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Ok "MCP server found: $McpExePath"

$mcpConfig = @{
    mcpServers = @{
        "tiaportal-mcp" = @{
            command = $McpExePath
            args = @(
                "--tia-major-version",
                "$TiaMajorVersion"
            )
            env = @{}
        }
    }
} | ConvertTo-Json -Depth 5

Write-Host ""
Write-Host "=== Trae MCP Configuration ===" -ForegroundColor Cyan
Write-Host ""
Write-Host $mcpConfig -ForegroundColor White
Write-Host ""

$configFile = Join-Path $PSScriptRoot "trae-mcp-config.json"
$mcpConfig | Out-File -FilePath $configFile -Encoding UTF8 -NoNewline

Write-Ok "Configuration saved to: $configFile"
Write-Host ""
Write-Host "=== Usage Instructions ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Open Trae settings" -ForegroundColor White
Write-Host "2. Find MCP server configuration" -ForegroundColor White
Write-Host "3. Copy the configuration above" -ForegroundColor White
Write-Host "4. Restart Trae" -ForegroundColor White
Write-Host ""
Write-Host "Or use the saved file: $configFile" -ForegroundColor Gray
Write-Host ""