Write-Host "=== 检查 TIA Portal 状态 ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] 检查 Siemens 相关进程..." -ForegroundColor Yellow
$processes = Get-Process | Where-Object { $_.ProcessName -like '*Siemens*' -or $_.ProcessName -like '*Portal*' }
if ($processes) {
    $processes | Format-Table ProcessName, Id, MainWindowTitle -AutoSize
} else {
    Write-Host "  未找到运行中的 Siemens/TIA Portal 进程" -ForegroundColor Red
}

Write-Host ""
Write-Host "[2] 检查用户组成员资格..." -ForegroundColor Yellow
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
Write-Host "  当前用户: $($identity.Name)"
$groups = $identity.Groups | ForEach-Object {
    try {
        $_.Translate([System.Security.Principal.NTAccount]).ToString()
    } catch {
        $_.Value
    }
}
$opennessGroup = $groups | Where-Object { $_ -like "*Siemens TIA Openness*" }
if ($opennessGroup) {
    Write-Host "  [PASS] 用户在 Siemens TIA Openness 组中" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] 用户不在 Siemens TIA Openness 组中" -ForegroundColor Red
    Write-Host "  请确保 TIA Portal 至少启动过一次，并重新登录" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[3] 检查 TIA Portal 安装..." -ForegroundColor Yellow
$tiaPaths = @(
    "C:\Program Files\Siemens\Automation\Portal V20",
    "D:\Program Files\Siemens\Automation\Portal V20"
)
foreach ($path in $tiaPaths) {
    if (Test-Path $path) {
        Write-Host "  [PASS] TIA Portal V20 找到: $path" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "[4] 检查 TiaPortalLocation 环境变量..." -ForegroundColor Yellow
$tiaLoc = [Environment]::GetEnvironmentVariable("TiaPortalLocation", "Machine")
if ($tiaLoc) {
    Write-Host "  TiaPortalLocation = $tiaLoc" -ForegroundColor Green
} else {
    Write-Host "  TiaPortalLocation 未设置" -ForegroundColor Yellow
}
