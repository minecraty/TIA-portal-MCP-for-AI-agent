Write-Host "=== 设置 TiaPortalLocation 环境变量 ===" -ForegroundColor Cyan

$tiaPath = "C:\Program Files\Siemens\Automation\Portal V20"

if (Test-Path $tiaPath) {
    Write-Host "设置 TiaPortalLocation = $tiaPath" -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("TiaPortalLocation", $tiaPath, "Machine")
    Write-Host "[PASS] 环境变量已设置" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "验证设置:" -ForegroundColor Yellow
    $verify = [Environment]::GetEnvironmentVariable("TiaPortalLocation", "Machine")
    Write-Host "  TiaPortalLocation = $verify" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "注意: 需要重启 PowerShell 或重新登录才能生效" -ForegroundColor Yellow
} else {
    Write-Host "[FAIL] TIA Portal 路径不存在: $tiaPath" -ForegroundColor Red
}
