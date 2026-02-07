# RunTests.ps1
# Specialized test runner for AHKv2-Lib

$ProjectRoot = [System.IO.Path]::GetFullPath("$PSScriptRoot\..")
$TestDir = [System.IO.Path]::Combine($ProjectRoot, "source", "tests")
$LogDir = [System.IO.Path]::Combine($TestDir, "logs")
$TestScript = [System.IO.Path]::Combine($TestDir, "RunAllTests.ahk")

# 1. Cleanup old logs
if ([System.IO.Directory]::Exists($LogDir)) {
    [System.IO.Directory]::GetFiles($LogDir) | ForEach-Object { [System.IO.File]::Delete($_) }
} else {
    [System.IO.Directory]::CreateDirectory($LogDir) | Out-Null
}

Write-Host ">>> Starting Unit Tests..." -ForegroundColor Cyan

# 2. Find AutoHotkey v2
$ahkExe = ""
$exeNames = @("AutoHotkey64.exe", "AutoHotkey.exe")

foreach ($name in $exeNames) {
    if (Get-Command $name -ErrorAction SilentlyContinue) {
        $ahkExe = $name
        break
    }
}

if ($ahkExe -eq "") {
    $commonPaths = @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\AutoHotkey64.exe",
        "$env:USERPROFILE\scoop\apps\autohotkey\current\AutoHotkey64.exe",
        "$env:USERPROFILE\scoop\apps\autohotkey\current\AutoHotkey.exe"
    )
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $ahkExe = $path
            break
        }
    }
}

if ($ahkExe -eq "") {
    Write-Host "!!! Error: AutoHotkey v2 executable not found." -ForegroundColor Red
    exit 1
}

# 3. Run AHK v2 script
$process = Start-Process -FilePath $ahkExe -ArgumentList "/ErrorStdOut", "`"$TestScript`"", "`"$LogDir`"" -WorkingDirectory $TestDir -Wait -PassThru -NoNewWindow

# 4. Report Results
if ($null -eq $process -or $process.ExitCode -ne 0) {
    $exitCode = if ($null -eq $process) { 1 } else { $process.ExitCode }
    Write-Host "!!! Tests Failed (ExitCode: $exitCode)" -ForegroundColor Red
} else {
    Write-Host "+++ All Tests Passed!" -ForegroundColor Green
}

# 5. Display the latest log if exists
if ([System.IO.Directory]::Exists($LogDir)) {
    $files = [System.IO.Directory]::GetFiles($LogDir, "*.log")
    if ($files.Count -gt 0) {
        $latestLog = $files | Sort-Object { [System.IO.File]::GetLastWriteTime($_) } -Descending | Select-Object -First 1
        Write-Host "`n--- Test Log Summary ---" -ForegroundColor Gray
        Get-Content $latestLog | Select-Object -Last 20
    }
}

if ($null -eq $process) { exit 1 } else { exit $process.ExitCode }
