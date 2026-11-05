<#
.SYNOPSIS
    Install or update Stardew Valley mods from github.com/jarps9977/stardew-mods-builded.

.DESCRIPTION
    Downloads the repo archive and copies every mod folder into the Stardew Valley Mods folder.
    Existing mod folders are updated (files overwritten), missing ones are created.
    Repo is the source of truth: all files, including config.json, are overwritten.

.PARAMETER ModsPath
    Target Mods folder. If omitted, the game folder is auto-detected
    (Steam libraries, GOG, common paths), then a folder picker is shown.

.PARAMETER Branch
    Git branch to download. Default: main.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\pull-mods-lasted.ps1
#>
[CmdletBinding()]
param(
    [string]$ModsPath = '',
    [string]$Branch = 'main',
    # Skip the final "Press Enter" prompt (for automation).
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$RepoZipUrl = "https://github.com/jarps9977/stardew-mods-builded/archive/refs/heads/$Branch.zip"
$RootFiles = @('README.md', 'pull-mods-lasted.ps1', 'pull-mods-lasted.bat', '.gitignore', '.gitattributes')

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Writable([string]$Path) {
    try {
        $probe = Join-Path $Path ".write_test_$([guid]::NewGuid().ToString('N'))"
        [IO.File]::WriteAllText($probe, '')
        Remove-Item -LiteralPath $probe -Force
        return $true
    } catch { return $false }
}

function Stop-WithError([string]$Message) {
    Write-Host "FAILED: $Message" -ForegroundColor Red
    if (-not $NoPause) { Read-Host 'Press Enter to close' | Out-Null }
    exit 1
}

function Test-GameDir([string]$Dir) {
    if (-not $Dir -or -not (Test-Path -LiteralPath $Dir -PathType Container)) { return $false }
    foreach ($f in @('Stardew Valley.dll', 'Stardew Valley.exe', 'StardewModdingAPI.exe')) {
        if (Test-Path -LiteralPath (Join-Path $Dir $f)) { return $true }
    }
    return $false
}

function Get-RegValue([string]$Key, [string]$Name) {
    try { (Get-ItemProperty -LiteralPath $Key -Name $Name -ErrorAction Stop).$Name } catch { $null }
}

function Find-GameDir {
    $candidates = New-Object System.Collections.Generic.List[string]

    # Steam: every library listed in libraryfolders.vdf.
    $steamRoots = @(
        (Get-RegValue 'HKCU:\Software\Valve\Steam' 'SteamPath'),
        (Get-RegValue 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' 'InstallPath'),
        (Get-RegValue 'HKLM:\SOFTWARE\Valve\Steam' 'InstallPath'),
        'C:\Program Files (x86)\Steam'
    ) | Where-Object { $_ } | ForEach-Object { $_ -replace '/', '\' } | Select-Object -Unique

    foreach ($root in $steamRoots) {
        $candidates.Add(([IO.Path]::Combine($root, 'steamapps\common\Stardew Valley')))
        $vdf = [IO.Path]::Combine($root, 'steamapps\libraryfolders.vdf')
        if (Test-Path -LiteralPath $vdf) {
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $lib = $m.Groups[1].Value -replace '\\\\', '\'
                $candidates.Add(([IO.Path]::Combine($lib, 'steamapps\common\Stardew Valley')))
            }
        }
    }

    # GOG Galaxy registry entry for Stardew Valley.
    $gog = Get-RegValue 'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1453375253' 'path'
    if ($gog) { $candidates.Add($gog) }

    # Common default locations on every fixed drive.
    foreach ($drive in [IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }) {
        $d = $drive.RootDirectory.FullName
        $candidates.Add(([IO.Path]::Combine($d, 'SteamLibrary\steamapps\common\Stardew Valley')))
        $candidates.Add(([IO.Path]::Combine($d, 'Steam\steamapps\common\Stardew Valley')))
        $candidates.Add(([IO.Path]::Combine($d, 'GOG Games\Stardew Valley')))
        $candidates.Add(([IO.Path]::Combine($d, 'Program Files (x86)\GOG Galaxy\Games\Stardew Valley')))
        $candidates.Add(([IO.Path]::Combine($d, 'Games\Stardew Valley')))
    }

    foreach ($c in $candidates | Select-Object -Unique) {
        if (Test-GameDir $c) { return $c }
    }
    return $null
}

function Select-GameDir {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Stardew Valley folder not found. Select the game folder (the one containing "Stardew Valley.exe") or its Mods folder.'
        $dlg.ShowNewFolderButton = $false
        if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
        $sel = $dlg.SelectedPath
    } catch {
        $sel = (Read-Host 'Stardew Valley folder not found. Paste the game folder path').Trim('"', ' ')
    }
    if (-not $sel) { return $null }
    if (Test-GameDir $sel) { return $sel }
    $parent = Split-Path -Parent $sel
    if ((Split-Path -Leaf $sel) -ieq 'Mods' -and (Test-GameDir $parent)) { return $parent }
    return $null
}

$exitCode = 0
if ($ModsPath) {
    $gameDir = Split-Path -Parent $ModsPath
    if (-not (Test-Path -LiteralPath $gameDir)) {
        Stop-WithError "Stardew Valley folder not found: $gameDir"
    }
} else {
    Write-Host 'Looking for Stardew Valley...'
    $gameDir = Find-GameDir
    if (-not $gameDir) { $gameDir = Select-GameDir }
    if (-not $gameDir) { Stop-WithError 'Stardew Valley folder not found or invalid folder selected.' }
    $ModsPath = Join-Path $gameDir 'Mods'
}
Write-Host "Mods folder: $ModsPath"
if (-not (Test-Path -LiteralPath $ModsPath)) {
    New-Item -ItemType Directory -Path $ModsPath | Out-Null
}

# Program Files may need elevation; relaunch as admin when the folder is not writable.
if (-not (Test-Writable $ModsPath)) {
    if (Test-IsAdmin) { Stop-WithError "Cannot write to $ModsPath." }
    if (-not $PSCommandPath) { Stop-WithError "No write access to $ModsPath. Run PowerShell as Administrator." }
    Write-Host 'No write access to Mods folder. Relaunching as Administrator...' -ForegroundColor Yellow
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-ModsPath', "`"$ModsPath`"", '-Branch', $Branch)
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs -Wait
    return
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "stardew-mods-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $zipPath = Join-Path $tempRoot 'repo.zip'
    Write-Host "Downloading $RepoZipUrl ..."
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $zipPath -UseBasicParsing

    $extractDir = Join-Path $tempRoot 'extract'
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
    $srcRoot = Get-ChildItem -LiteralPath $extractDir -Directory | Select-Object -First 1
    if (-not $srcRoot) { throw 'Downloaded archive is empty.' }

    $created = 0; $updated = 0
    foreach ($mod in Get-ChildItem -LiteralPath $srcRoot.FullName -Directory) {
        if ($RootFiles -contains $mod.Name -or $mod.Name.StartsWith('.')) { continue }

        $dest = Join-Path $ModsPath $mod.Name
        $isNew = -not (Test-Path -LiteralPath $dest)
        if ($isNew) { New-Item -ItemType Directory -Path $dest | Out-Null }

        foreach ($file in Get-ChildItem -LiteralPath $mod.FullName -Recurse -File) {
            $rel = $file.FullName.Substring($mod.FullName.Length).TrimStart('\', '/')
            $target = Join-Path $dest $rel

            $targetDir = Split-Path -Parent $target
            if (-not (Test-Path -LiteralPath $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        }

        if ($isNew) { $created++; Write-Host "[NEW]    $($mod.Name)" -ForegroundColor Green }
        else        { $updated++; Write-Host "[UPDATE] $($mod.Name)" -ForegroundColor Cyan }
    }

    Write-Host ''
    Write-Host "Done. New: $created, Updated: $updated -> $ModsPath" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $exitCode = 1
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if (-not $NoPause) { Read-Host 'Press Enter to close' | Out-Null }
if ($exitCode) { exit $exitCode }
