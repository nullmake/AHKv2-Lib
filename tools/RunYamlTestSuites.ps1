# RunYamlTestSuites.ps1
# Specialized test runner for the YAML Test Suite

$ProjectRoot = [System.IO.Path]::GetFullPath("$PSScriptRoot\..")
$TestDir = [System.IO.Path]::Combine($ProjectRoot, "source", "tests")
$LogDir = [System.IO.Path]::Combine($TestDir, "logs")
$TestScript = [System.IO.Path]::Combine($TestDir, "RunYamlTestSuite.ahk")

# 1. Cleanup old logs
if (Test-Path $LogDir -PathType Container) {
    Get-ChildItem $LogDir -Recurse -File `
    | Where-Object { $_.Name -notmatch "failed_cases" } `
    | ForEach-Object { [System.IO.File]::Delete($_.FullName) }
} else {
    [System.IO.Directory]::CreateDirectory($LogDir) | Out-Null
}
Write-Host ">>> Executing YAML Test Suite: $TestScript" -ForegroundColor Cyan
if ($args.Count -gt 0) {
    Write-Host ">>> Target Cases: $($args -join ', ')" -ForegroundColor Cyan
}

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

# 3. Set Location to TestDir to ensure relative paths in AHK work correctly
Set-Location $TestDir

# 4. Run AHK v2 script with stable real-time output
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ahkExe

# Build arguments: /ErrorStdOut "script.ahk" [caseId1 caseId2 ...]
$ahkArgs = @("/ErrorStdOut", "`"$TestScript`"")
if ($args.Count -gt 0) {
    foreach ($arg in $args) {
        $ahkArgs += "`"$arg`""
    }
}

$psi.Arguments = $ahkArgs -join " "
$psi.WorkingDirectory = $TestDir
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $psi

$process.Start() | Out-Null

# Synchronous reading loop to ensure output order
while (!$process.HasExited) {
    while (!$process.StandardOutput.EndOfStream) {
        $line = $process.StandardOutput.ReadLine()
        if ($line) { Write-Host $line }
    }
    while (!$process.StandardError.EndOfStream) {
        $line = $process.StandardError.ReadLine()
        if ($line) { Write-Host $line -ForegroundColor Yellow }
    }
    Start-Sleep -Milliseconds 10
}

# Final drain of remaining output after exit
while (!$process.StandardOutput.EndOfStream) {
    $line = $process.StandardOutput.ReadLine()
    if ($line) { Write-Host $line }
}
while (!$process.StandardError.EndOfStream) {
    $line = $process.StandardError.ReadLine()
    if ($line) { Write-Host $line -ForegroundColor Yellow }
}

$exitCode = $process.ExitCode

# 5. Report Results
if ($exitCode -ne 0) {
    Write-Host "`n!!! Tests Failed (ExitCode: $exitCode)" -ForegroundColor Red
} else {
    Write-Host "`n+++ All Tests Finished!" -ForegroundColor Green
}

exit $exitCode
