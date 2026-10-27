# Circle Master - viewport images for the publication (development tool, not
# shipped in the .rbz). Adapted from tools/tests/run_tests.ps1.
#
# Deploys the plugin of the project into SketchUp 2021, starts it with
# -RubyStartup tools/demo/screenshots.rb, waits for DONE in -OutDir, closes
# that SketchUp and prints the log. The images are then put together by
# tools/demo/make_images.py.
#
#   powershell -File tools\demo\screenshots.ps1 -OutDir <work folder>
#
# SketchUp must be closed: an open session is never touched, and only the
# SketchUp started here is closed. The user's settings are not written.
#
# Keep this file ASCII: Windows PowerShell 5.1 reads a .ps1 without BOM as ANSI.

param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$Version = '2021',
    [int]$Timeout = 300,
    [switch]$NoDeploy
)

$ErrorActionPreference = 'Stop'
$demo = $PSScriptRoot
$project = Split-Path -Parent (Split-Path -Parent $demo)

# Copy of $path in %USERPROFILE%\claude-backups\<date>\LOCALAPPDATA\<path>
# before it is written; only the 5 latest copies of that file are kept.
# Returns $false when the copy failed: the file must not be written then.
function Backup-Preferences([string]$path) {
    $root = Join-Path $env:USERPROFILE 'claude-backups'
    $relative = 'LOCALAPPDATA' + $path.Substring($env:LOCALAPPDATA.Length)
    $copy = Join-Path (Join-Path $root (Get-Date -Format 'yyyy-MM-dd_HHmmss')) $relative
    try {
        New-Item -ItemType Directory -Force (Split-Path -Parent $copy) | Out-Null
        Copy-Item $path $copy -Force
        if ((Get-Item $copy).Length -ne (Get-Item $path).Length) { return $false }
    } catch {
        return $false
    }
    Write-Host "  Preferences backed up: $copy"
    try {
        Get-ChildItem $root -Directory | Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName $relative } | Where-Object { Test-Path $_ } |
            Select-Object -Skip 5 | ForEach-Object { Remove-Item $_ -Force }
    } catch {
        Write-Host "  Older backups not removed: $($_.Exception.Message)"
    }
    $true
}

if (Get-Process SketchUp -ErrorAction SilentlyContinue) {
    Write-Host 'SketchUp is running: close it first (an open session is never touched).'
    exit 2
}
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
foreach ($old in @('DONE', 'shots.log')) {
    $f = Join-Path $OutDir $old
    if (Test-Path $f) { Remove-Item $f -Force }
}

$location = Get-Item "HKLM:\SOFTWARE\SketchUp\SketchUp $Version\InstallLocation" -ErrorAction SilentlyContinue
$exe = if ($location) { Join-Path $location.GetValue('') 'SketchUp.exe' } else { $null }
if (-not $exe -or -not (Test-Path $exe)) { Write-Host "SketchUp $Version not found"; exit 1 }

if (-not $NoDeploy) {
    $plugins = Join-Path $env:APPDATA "SketchUp\SketchUp $Version\SketchUp\Plugins"
    if (-not (Test-Path $plugins)) { Write-Host "Plugins folder of SketchUp $Version not found"; exit 1 }
    Copy-Item (Join-Path $project 'circle_master.rb') $plugins -Force
    robocopy (Join-Path $project 'circle_master') (Join-Path $plugins 'circle_master') /MIR /NJH /NJS /NFL /NDL /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Write-Host "Deployment to SketchUp $Version failed"; exit 1 }
}

# Welcome screen switched off for the run and back on after (as run_tests.ps1:
# UTF-8 without BOM, backup before the first write, file over 20 MB untouched).
$prefs = Join-Path $env:LOCALAPPDATA "SketchUp\SketchUp $Version\SketchUp\PrivatePreferences.json"
$utf8 = New-Object System.Text.UTF8Encoding $false
$welcomeOn = '("WelcomeDialog":\s*\{\s*"ShowOnStartup":\s*)true'
$welcomeOff = '("WelcomeDialog":\s*\{\s*"ShowOnStartup":\s*)false'
$welcomeSwitched = $false
if ((Test-Path $prefs) -and (Get-Item $prefs).Length -gt 20MB) {
    Write-Host "  $prefs is over 20 MB: not touched (welcome screen left as it is)."
} elseif (Test-Path $prefs) {
    $text = [IO.File]::ReadAllText($prefs, $utf8)
    if ($text -match $welcomeOn) {
        if (Backup-Preferences $prefs) {
            [IO.File]::WriteAllText($prefs, ($text -replace $welcomeOn, '${1}false'), $utf8)
            $welcomeSwitched = $true
        } else {
            Write-Host "  $prefs could not be backed up: not touched (welcome screen left as it is)."
        }
    }
}

$env:CM_SHOTS_DIR = $OutDir
$startup = Join-Path $demo 'screenshots.rb'
$start = Get-Date
Write-Host "SketchUp $Version - images being made..."
$process = Start-Process $exe -ArgumentList '-RubyStartup', ('"{0}"' -f $startup) -PassThru
$done = $false
try {
    while (((Get-Date) - $start).TotalSeconds -lt $Timeout) {
        Start-Sleep -Seconds 1
        if (Test-Path (Join-Path $OutDir 'DONE')) { $done = $true; break }
        if ($process.HasExited) { break }
    }
} finally {
    # Only the SketchUp started here is closed.
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    Start-Sleep -Seconds 2
    if ($welcomeSwitched -and (Test-Path $prefs)) {
        try {
            $text = [IO.File]::ReadAllText($prefs, $utf8)
            [IO.File]::WriteAllText($prefs, ($text -replace $welcomeOff, '${1}true'), $utf8)
        } catch {
            Write-Host "  Could not switch the welcome screen of SketchUp $Version back on: $($_.Exception.Message)"
        }
    }
}
$log = Join-Path $OutDir 'shots.log'
if (Test-Path $log) { Get-Content $log -Encoding UTF8 | ForEach-Object { Write-Host $_ } }
if ($done) { Write-Host "Done: $OutDir"; exit 0 }
Write-Host "No DONE after $Timeout s (or SketchUp closed)"
exit 1
