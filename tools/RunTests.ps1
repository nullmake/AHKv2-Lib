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

Write-Host ">>> Starting Unit Tests (Real-time mode)..." -ForegroundColor Cyan

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

# 3. Run AHK v2 script with real-time output
# We use Start-Process with redirection to capture stdout/stderr stream by stream
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ahkExe
$psi.Arguments = "/ErrorStdOut `"$TestScript`" `"$LogDir`""
$psi.WorkingDirectory = $TestDir
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi

# Real-time event handling
$outputAction = {
    if ($EventArgs.Data) {
        Write-Host $EventArgs.Data
    }
}

$errorAction = {
    if ($EventArgs.Data) {
        Write-Host $EventArgs.Data -ForegroundColor Yellow
    }
}

Register-ObjectEvent -InputObject $process -EventName "OutputDataReceived" -Action $outputAction | Out-Null
Register-ObjectEvent -InputObject $process -EventName "ErrorDataReceived" -Action $errorAction | Out-Null

$process.Start() | Out-Null
$process.BeginOutputReadLine()
$process.BeginErrorReadLine()

# Wait for process to exit
while (!$process.HasExited) {
    Start-Sleep -Milliseconds 100
}

$exitCode = $process.ExitCode

# 4. Report Results
if ($exitCode -ne 0) {
    Write-Host "`n!!! Tests Failed (ExitCode: $exitCode)" -ForegroundColor Red
} else {
    Write-Host "`n+++ All Tests Passed!" -ForegroundColor Green
}

exit $exitCode
