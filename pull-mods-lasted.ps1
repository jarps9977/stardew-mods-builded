<#
.SYNOPSIS
    Install or update Stardew Valley mods from github.com/jarps9977/stardew-mods-builded.

.DESCRIPTION
    1. Installs or updates SMAPI to the latest release.
    2. Downloads the repo archive and syncs every mod folder into the Mods folder.
       Repo is the source of truth: all files, including config.json, are overwritten.
       Mods not in the repo, and stale files inside repo mods, are moved to
       <game>\Mods_backup\<timestamp> (SMAPI bundled mods and dot-folders are kept).
    3. Steam only: sets the game launch options to run SMAPI if not set yet,
       then asks Steam to verify the game files.

.PARAMETER ModsPath
    Target Mods folder. If omitted, the game folder is auto-detected
    (Steam libraries, GOG, common paths), then a folder picker is shown.

.PARAMETER Branch
    Git branch to download. Default: main.

.PARAMETER SkipSmapi
    Do not install or update SMAPI.

.PARAMETER SkipValidate
    Do not ask Steam to verify the game files.

.PARAMETER NoPause
    Skip the final "Press Enter" prompt (for automation).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\pull-mods-lasted.ps1

.EXAMPLE
    # No file on disk (paste into Win+R):
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/jarps9977/stardew-mods-builded/main/pull-mods-lasted.ps1 | iex"
#>
[CmdletBinding()]
param(
    [string]$ModsPath = '',
    [string]$Branch = 'main',
    [switch]$SkipSmapi,
    [switch]$SkipValidate,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoZipUrl = "https://github.com/jarps9977/stardew-mods-builded/archive/refs/heads/$Branch.zip"
$SmapiReleaseApi = 'https://api.github.com/repos/Pathoschild/SMAPI/releases/latest'
$SteamAppId = '413150'
$RootFiles = @('README.md', 'pull-mods-lasted.ps1', 'pull-mods-lasted.bat', '.gitignore', '.gitattributes')
# Installed by SMAPI itself; never move these.
$ProtectedMods = @('ConsoleCommands', 'SaveBackup')
# Runtime data folders inside a mod; not treated as stale files.
$KeepSubdirs = @('cache', 'data', 'saves', 'logs')

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

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "== $Message" -ForegroundColor White
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

function Get-SteamRoot {
    $p = Get-RegValue 'HKCU:\Software\Valve\Steam' 'SteamPath'
    if (-not $p) { $p = Get-RegValue 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' 'InstallPath' }
    if ($p) { return ($p -replace '/', '\') }
    return $null
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

# ---------- SMAPI ----------

function Get-InstalledSmapiVersion([string]$GameDir) {
    $dll = Join-Path $GameDir 'StardewModdingAPI.dll'
    if (-not (Test-Path -LiteralPath $dll)) { return $null }
    try {
        $v = (Get-Item -LiteralPath $dll).VersionInfo.ProductVersion
        return [version](($v -split '[+\- ]')[0])
    } catch { return $null }
}

function Install-Smapi([string]$GameDir, [string]$TempRoot) {
    Write-Step 'SMAPI'
    $release = Invoke-RestMethod -Uri $SmapiReleaseApi -UseBasicParsing
    $latest = [version](($release.tag_name -replace '^v', '' -split '[+\- ]')[0])
    $installed = Get-InstalledSmapiVersion $GameDir

    if ($installed -and $installed -ge $latest) {
        Write-Host "SMAPI $installed is up to date." -ForegroundColor Cyan
        return
    }

    $asset = $release.assets | Where-Object { $_.name -match '^SMAPI-[\d.]+-installer\.zip$' } | Select-Object -First 1
    if (-not $asset) { throw "SMAPI installer not found in release $($release.tag_name)." }

    if ($installed) { Write-Host "Updating SMAPI $installed -> $latest ..." }
    else            { Write-Host "Installing SMAPI $latest ..." }

    $zip = Join-Path $TempRoot $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
    $dir = Join-Path $TempRoot 'smapi'
    Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force

    $exe = Get-ChildItem -LiteralPath $dir -Recurse -File -Filter 'SMAPI.Installer.exe' |
        Where-Object { $_.DirectoryName -match '\\windows$' } | Select-Object -First 1
    if (-not $exe) { throw 'SMAPI.Installer.exe not found in the SMAPI package.' }

    $installerArgs = @('--install', '--game-path', "`"$GameDir`"", '--no-prompt')
    $p = Start-Process -FilePath $exe.FullName -ArgumentList $installerArgs-WorkingDirectory $exe.DirectoryName -NoNewWindow -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "SMAPI installer exited with code $($p.ExitCode)." }

    $now = Get-InstalledSmapiVersion $GameDir
    if (-not $now) { throw 'SMAPI installer finished but StardewModdingAPI.dll was not found.' }
    Write-Host "SMAPI $now installed." -ForegroundColor Green
}

# ---------- Mods ----------

function Move-ToBackup([string]$Path, [string]$RelPath) {
    $dst = Join-Path $script:BackupRoot $RelPath
    $parent = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Move-Item -LiteralPath $Path -Destination $dst -Force
}

function Sync-Mods([string]$SrcRoot, [string]$ModsPath) {
    Write-Step 'Mods'
    $repoMods = @(Get-ChildItem -LiteralPath $SrcRoot -Directory |
        Where-Object { -not $_.Name.StartsWith('.') -and $RootFiles -notcontains $_.Name })
    $repoNames = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($m in $repoMods) { [void]$repoNames.Add($m.Name) }

    $created = 0; $updated = 0; $removed = 0; $stale = 0

    # Move mods that are not part of the repo.
    foreach ($dir in Get-ChildItem -LiteralPath $ModsPath -Directory) {
        if ($dir.Name.StartsWith('.') -or $ProtectedMods -contains $dir.Name -or $repoNames.Contains($dir.Name)) { continue }
        Move-ToBackup $dir.FullName $dir.Name
        $removed++
        Write-Host "[REMOVE] $($dir.Name)" -ForegroundColor Yellow
    }

    foreach ($mod in $repoMods) {
        $dest = Join-Path $ModsPath $mod.Name
        $isNew = -not (Test-Path -LiteralPath $dest)
        if ($isNew) { New-Item -ItemType Directory -Path $dest | Out-Null }

        $repoFiles = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($file in Get-ChildItem -LiteralPath $mod.FullName -Recurse -File) {
            $rel = $file.FullName.Substring($mod.FullName.Length).TrimStart('\', '/')
            [void]$repoFiles.Add($rel)
            $target = Join-Path $dest $rel
            $targetDir = Split-Path -Parent $target
            if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
            Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        }

        # Move leftover files from older versions.
        if (-not $isNew) {
            foreach ($file in Get-ChildItem -LiteralPath $dest -Recurse -File) {
                $rel = $file.FullName.Substring($dest.Length).TrimStart('\', '/')
                if ($repoFiles.Contains($rel)) { continue }
                $first = ($rel -split '[\\/]')[0]
                if ($rel -match '[\\/]' -and $KeepSubdirs -contains $first) { continue }
                Move-ToBackup $file.FullName (Join-Path $mod.Name $rel)
                $stale++
            }
        }

        if ($isNew) { $created++; Write-Host "[NEW]    $($mod.Name)" -ForegroundColor Green }
        else        { $updated++; Write-Host "[UPDATE] $($mod.Name)" -ForegroundColor Cyan }
    }

    Write-Host ''
    Write-Host "Mods: New $created, Updated $updated, Removed $removed, Stale files $stale" -ForegroundColor Green
    if ($removed -or $stale) { Write-Host "Backup: $script:BackupRoot" -ForegroundColor Yellow }
}

# ---------- Steam launch options ----------

function ConvertFrom-Vdf([string]$Text) {
    # Node = ArrayList of @{Key; Value}; Value is a raw (escaped) string or a child node.
    $root = New-Object System.Collections.ArrayList
    $stack = New-Object System.Collections.Stack
    $cur = $root
    $key = $null
    foreach ($m in [regex]::Matches($Text, '"((?:[^"\\]|\\.)*)"|([{}])')) {
        if ($m.Groups[2].Success) {
            if ($m.Value -eq '{') {
                if ($null -eq $key) { throw 'Invalid VDF: block without key.' }
                $child = New-Object System.Collections.ArrayList
                [void]$cur.Add([pscustomobject]@{ Key = $key; Value = $child })
                $stack.Push($cur); $cur = $child; $key = $null
            } else {
                if ($stack.Count -eq 0) { throw 'Invalid VDF: unbalanced braces.' }
                $cur = $stack.Pop()
            }
        } elseif ($null -eq $key) {
            $key = $m.Groups[1].Value
        } else {
            [void]$cur.Add([pscustomobject]@{ Key = $key; Value = $m.Groups[1].Value })
            $key = $null
        }
    }
    if ($stack.Count -ne 0) { throw 'Invalid VDF: unbalanced braces.' }
    return , $root
}

function ConvertTo-Vdf($Node) {
    $sb = New-Object System.Text.StringBuilder
    Write-VdfNode $sb $Node 0
    return $sb.ToString()
}

function Write-VdfNode($Sb, $Node, [int]$Depth) {
    $ind = "`t" * $Depth
    foreach ($e in $Node) {
        if ($e.Value -is [System.Collections.ArrayList]) {
            [void]$Sb.Append("$ind`"$($e.Key)`"`n$ind{`n")
            Write-VdfNode $Sb $e.Value ($Depth + 1)
            [void]$Sb.Append("$ind}`n")
        } else {
            [void]$Sb.Append("$ind`"$($e.Key)`"`t`t`"$($e.Value)`"`n")
        }
    }
}

function Get-VdfNode($Node, [string]$Key, [switch]$Create) {
    foreach ($e in $Node) {
        if ($e.Key -ieq $Key -and $e.Value -is [System.Collections.ArrayList]) { return , $e.Value }
    }
    if (-not $Create) { return $null }
    $child = New-Object System.Collections.ArrayList
    [void]$Node.Add([pscustomobject]@{ Key = $Key; Value = $child })
    return , $child
}

function Get-SteamAppNode($Vdf, [switch]$Create) {
    $n = $Vdf
    foreach ($k in @('UserLocalConfigStore', 'Software', 'Valve', 'Steam')) {
        $n = Get-VdfNode $n $k
        if ($null -eq $n) { return $null }
    }
    $apps = Get-VdfNode $n 'apps' -Create:$Create
    if ($null -eq $apps) { return $null }
    $app = Get-VdfNode $apps $SteamAppId -Create:$Create
    if ($null -eq $app) { return $null }
    return , $app
}

function Test-LaunchOptionsSet($AppNode) {
    if ($null -eq $AppNode) { return $false }
    foreach ($e in $AppNode) {
        if ($e.Key -ieq 'LaunchOptions' -and $e.Value -is [string] -and $e.Value -match 'StardewModdingAPI\.exe') { return $true }
    }
    return $false
}

function Wait-SteamExit([int]$Seconds) {
    for ($i = 0; $i -lt $Seconds; $i++) {
        if (-not (Get-Process -Name 'steam' -ErrorAction SilentlyContinue)) { return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}

function Set-SteamLaunchOptions([string]$GameDir) {
    Write-Step 'Steam launch options'
    $steamRoot = Get-SteamRoot
    $smapiExe = Join-Path $GameDir 'StardewModdingAPI.exe'
    if (-not $steamRoot -or $GameDir -notmatch '\\steamapps\\common\\') { Write-Host 'Not a Steam install. Skipped.'; return $false }
    if (-not (Test-Path -LiteralPath $smapiExe)) { Write-Host 'StardewModdingAPI.exe not found. Skipped.' -ForegroundColor Yellow; return $false }

    $configs = @(Get-ChildItem -Path (Join-Path $steamRoot 'userdata\*\config\localconfig.vdf') -File -ErrorAction SilentlyContinue)
    if (-not $configs) { Write-Host 'No Steam user config found. Skipped.' -ForegroundColor Yellow; return $false }

    $pending = @()
    foreach ($cfg in $configs) {
        try {
            $app = Get-SteamAppNode (ConvertFrom-Vdf ([IO.File]::ReadAllText($cfg.FullName)))
            if (-not (Test-LaunchOptionsSet $app)) { $pending += $cfg }
        } catch { Write-Host "Cannot read $($cfg.FullName): $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    if (-not $pending) { Write-Host 'Launch options already set.' -ForegroundColor Cyan; return $false }

    # Steam rewrites localconfig.vdf on exit, so it must be closed before editing.
    $restartSteam = $false
    if (Get-Process -Name 'steam' -ErrorAction SilentlyContinue) {
        Write-Host 'Closing Steam to update launch options...' -ForegroundColor Yellow
        $steamExe = Join-Path $steamRoot 'steam.exe'
        Start-Process -FilePath $steamExe -ArgumentList '-shutdown'
        if (-not (Wait-SteamExit 30)) {
            # Graceful shutdown stuck (e.g. dialog open); force close Steam and its helpers.
            Write-Host 'Steam did not close in time. Forcing it to close...' -ForegroundColor Yellow
            Get-Process -Name 'steam', 'steamwebhelper', 'steamservice' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            if (-not (Wait-SteamExit 15)) { Write-Host 'Cannot close Steam. Launch options not changed.' -ForegroundColor Yellow; return $false }
        }
        Start-Sleep -Seconds 2
        $restartSteam = $true
    }

    $want = ('"' + $smapiExe + '" %command%').Replace('\', '\\').Replace('"', '\"')
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    foreach ($cfg in $pending) {
        try {
            $vdf = ConvertFrom-Vdf ([IO.File]::ReadAllText($cfg.FullName))
            $app = Get-SteamAppNode $vdf -Create
            if ($null -eq $app) { Write-Host "Unexpected format in $($cfg.FullName). Skipped." -ForegroundColor Yellow; continue }
            if (Test-LaunchOptionsSet $app) { continue }

            $entry = $app | Where-Object { $_.Key -ieq 'LaunchOptions' } | Select-Object -First 1
            if ($entry) { $entry.Value = $want }
            else { [void]$app.Add([pscustomobject]@{ Key = 'LaunchOptions'; Value = $want }) }

            Copy-Item -LiteralPath $cfg.FullName -Destination "$($cfg.FullName).bak-$stamp" -Force
            [IO.File]::WriteAllText($cfg.FullName, (ConvertTo-Vdf $vdf), (New-Object System.Text.UTF8Encoding $false))
            Write-Host "Launch options set: `"$smapiExe`" %command%" -ForegroundColor Green
        } catch { Write-Host "Cannot update $($cfg.FullName): $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    return $restartSteam
}

function Open-SteamUrl([string]$Url) {
    # explorer.exe launches Steam as the normal user even when this script is elevated.
    Start-Process -FilePath 'explorer.exe' -ArgumentList $Url
}

# ---------- Main ----------

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
Write-Host "Game folder: $gameDir"

$gameProcs = @(Get-Process -Name 'Stardew Valley', 'StardewModdingAPI' -ErrorAction SilentlyContinue)
if ($gameProcs) {
    Write-Host 'Stardew Valley is running and will be closed in 5 seconds (unsaved progress is lost). Press Ctrl+C to cancel.' -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    $gameProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    $gameProcs | Wait-Process -Timeout 30 -ErrorAction SilentlyContinue
    if (Get-Process -Name 'Stardew Valley', 'StardewModdingAPI' -ErrorAction SilentlyContinue) {
        Stop-WithError 'Cannot close Stardew Valley. Close the game and run again.'
    }
    Write-Host 'Game closed.'
}

if (-not (Test-Path -LiteralPath $ModsPath)) {
    try { New-Item -ItemType Directory -Path $ModsPath | Out-Null } catch { }
}

# Program Files may need elevation; relaunch as admin when the folders are not writable.
if (-not ((Test-Path -LiteralPath $ModsPath) -and (Test-Writable $ModsPath) -and (Test-Writable $gameDir))) {
    if (Test-IsAdmin) { Stop-WithError "Cannot write to $gameDir." }
    Write-Host 'No write access to game folder. Relaunching as Administrator...' -ForegroundColor Yellow
    $extra = @()
    if ($SkipSmapi) { $extra += '-SkipSmapi' }
    if ($SkipValidate) { $extra += '-SkipValidate' }
    if ($PSCommandPath) {
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-ModsPath', "`"$ModsPath`"", '-Branch', $Branch) + $extra
    } else {
        # Running from memory (irm | iex): re-download the script in the elevated process.
        $selfUrl = "https://raw.githubusercontent.com/jarps9977/stardew-mods-builded/$Branch/pull-mods-lasted.ps1"
        $q = { param($s) "'" + ($s -replace "'", "''") + "'" }
        $cmd = "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; & ([scriptblock]::Create((Invoke-RestMethod -Uri $(& $q $selfUrl) -UseBasicParsing))) -ModsPath $(& $q $ModsPath) -Branch $(& $q $Branch) $($extra -join ' ')"
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd)))
    }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs -Wait
    return
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "stardew-mods-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$script:BackupRoot = Join-Path $gameDir ("Mods_backup\" + (Get-Date -Format 'yyyyMMdd-HHmmss'))

try {
    if (-not $SkipSmapi) {
        try { Install-Smapi $gameDir $tempRoot }
        catch {
            Write-Host "SMAPI step failed: $($_.Exception.Message)" -ForegroundColor Red
            $exitCode = 1
        }
    }

    Write-Step 'Download'
    Write-Host "Downloading $RepoZipUrl ..."
    $zipPath = Join-Path $tempRoot 'repo.zip'
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $zipPath -UseBasicParsing
    $extractDir = Join-Path $tempRoot 'extract'
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
    $srcRoot = Get-ChildItem -LiteralPath $extractDir -Directory | Select-Object -First 1
    if (-not $srcRoot) { throw 'Downloaded archive is empty.' }

    Sync-Mods $srcRoot.FullName $ModsPath

    $restartSteam = $false
    try { $restartSteam = Set-SteamLaunchOptions $gameDir }
    catch { Write-Host "Launch options step failed: $($_.Exception.Message)" -ForegroundColor Yellow }

    if ($gameDir -match '\\steamapps\\common\\') {
        if (-not $SkipValidate) {
            Write-Step 'Steam verify'
            Write-Host 'Asking Steam to verify game files (see Steam window)...'
            Open-SteamUrl "steam://validate/$SteamAppId"
        } elseif ($restartSteam) {
            Open-SteamUrl 'steam://open/main'
        }
    }

    Write-Host ''
    if ($exitCode) { Write-Host 'Done with warnings.' -ForegroundColor Yellow }
    else           { Write-Host 'Done.' -ForegroundColor Green }
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
