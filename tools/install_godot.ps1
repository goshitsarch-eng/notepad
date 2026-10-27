# Downloads Godot 4.7.2 (stable) for this Windows machine, checks it against the checksums in
# tools\godot-4.7.2.sha512, and installs the editor and the export templates.
#
# Usage: pwsh tools/install_godot.ps1 -InstallDir <folder> [-Arch x64|arm64]
# The editor is <folder>\godot.exe afterwards.
param(
  [Parameter(Mandatory = $true)][string]$InstallDir,
  [ValidateSet('x64', 'arm64')][string]$Arch = 'x64'
)
$ErrorActionPreference = 'Stop'

$version = '4.7.2'
$base = "https://github.com/godotengine/godot-builds/releases/download/$version-stable"
$sums = Join-Path $PSScriptRoot "godot-$version.sha512"
$editor = if ($Arch -eq 'arm64') { "Godot_v$version-stable_windows_arm64.exe.zip" } else { "Godot_v$version-stable_win64.exe.zip" }
$templates = "Godot_v$version-stable_export_templates.tpz"
$work = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $work, $InstallDir | Out-Null

function Get-Verified([string]$file) {
  $target = Join-Path $work $file
  Invoke-WebRequest -Uri "$base/$file" -OutFile $target
  $line = Get-Content $sums | Where-Object { $_ -match [regex]::Escape("  $file") + '$' } | Select-Object -First 1
  if (-not $line) { throw "no pinned checksum for $file" }
  $expected = ($line -split ' ')[0]
  $actual = (Get-FileHash -Algorithm SHA512 $target).Hash.ToLower()
  if ($expected -ne $actual) { throw "checksum mismatch for $file" }
  return $target
}

$zip = Get-Verified $editor
Expand-Archive -Path $zip -DestinationPath $InstallDir -Force
$exe = Get-ChildItem $InstallDir -Filter 'Godot_v*.exe' | Where-Object { $_.Name -notmatch 'console' } | Select-Object -First 1
Copy-Item $exe.FullName (Join-Path $InstallDir 'godot.exe') -Force
$console = Get-ChildItem $InstallDir -Filter 'Godot_v*_console.exe' | Select-Object -First 1
if ($console) { Copy-Item $console.FullName (Join-Path $InstallDir 'godot_console.exe') -Force }

$tpz = Get-Verified $templates
$unpacked = Join-Path $work 'templates'
Copy-Item $tpz "$tpz.zip"
Expand-Archive -Path "$tpz.zip" -DestinationPath $unpacked -Force
$destination = Join-Path $env:APPDATA "Godot\export_templates\$version.stable"
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Copy-Item (Join-Path $unpacked 'templates\*') $destination -Recurse -Force

Write-Host "Godot $version is in $InstallDir"
