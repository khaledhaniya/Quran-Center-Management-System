# Auto-Sync Watcher for Quran Center Project
$repoPath = $PSScriptRoot
Set-Location $repoPath

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   AlBayan Quran Center - Auto Git Sync Watcher" -ForegroundColor Green
Write-Host "   جاري مراقبة التعديلات... أي تعديل تحفظه سيتم رفعه تلقائياً إلى GitHub" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Cyan

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $repoPath
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName

$global:pendingChanges = $false

$action = {
    $path = $Event.SourceEventArgs.FullPath
    if ($path -match "\\\.git\\" -or $path -match "\\bin\\" -or $path -match "\\obj\\" -or $path -match "quran\.db" -or $path -match "scratch") {
        return
    }
    $global:pendingChanges = $true
}

Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null
Register-ObjectEvent $watcher "Deleted" -Action $action | Out-Null
Register-ObjectEvent $watcher "Renamed" -Action $action | Out-Null

while ($true) {
    Start-Sleep -Seconds 3
    if ($global:pendingChanges) {
        # انتظار 8 ثوانٍ للتأكد من انتهاء المستخدم من الحفظ والكتابة (Debounce)
        Start-Sleep -Seconds 8
        $global:pendingChanges = $false
        
        $status = git status --porcelain
        if ($status) {
            $timeStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Write-Host "`n[$timeStr] 🔄 تم رصد تعديلات جديدة، جاري الرفع التلقائي إلى GitHub..." -ForegroundColor Cyan
            git add .
            git reset -- QuranCircles.Api/QuranCircles.Api/quran.db 2>$null
            git commit -m "Auto-sync update ($timeStr)"
            git push origin main
            Write-Host "[$timeStr] ✅ تم الرفع والمزامنة مع GitHub بنجاح تام!" -ForegroundColor Green
        }
    }
}
