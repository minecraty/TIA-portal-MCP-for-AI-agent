Write-Host "=== TIA Portal 详细信息 ===" -ForegroundColor Cyan

Write-Host ""
Write-Host "[1] TiaPortalLocation 环境变量:" -ForegroundColor Yellow
$tiaLoc = [Environment]::GetEnvironmentVariable("TiaPortalLocation", "Machine")
Write-Host "  $tiaLoc"

Write-Host ""
Write-Host "[2] TIA Portal 进程详情:" -ForegroundColor Yellow
$portal = Get-Process -Name "Siemens.Automation.Portal" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($portal) {
    Write-Host "  Process ID: $($portal.Id)"
    Write-Host "  Path: $($portal.MainModule.FileName)"
    Write-Host "  MainWindowTitle: $($portal.MainWindowTitle)"
}

Write-Host ""
Write-Host "[3] 检查 Openness API:" -ForegroundColor Yellow
$regPath = "HKLM:\SOFTWARE\Siemens\Automation\_InstalledSW\TIAP20\TIA_Opns"
try {
    $reg = Get-ItemProperty -Path $regPath -ErrorAction Stop
    Write-Host "  Openness Path: $($reg.Path)"
    Write-Host "  Openness Version: $($reg.Version)"
} catch {
    Write-Host "  未找到 Openness 注册表项" -ForegroundColor Red
}

Write-Host ""
Write-Host "[4] 尝试加载 Openness 程序集:" -ForegroundColor Yellow
try {
    $asm = [System.Reflection.Assembly]::LoadWithPartialName("Siemens.Engineering")
    if ($asm) {
        Write-Host "  [PASS] Siemens.Engineering 加载成功" -ForegroundColor Green
        Write-Host "  Version: $($asm.GetName().Version)"
    }
} catch {
    Write-Host "  [FAIL] 无法加载 Siemens.Engineering: $($_.Exception.Message)" -ForegroundColor Red
}
