# Builds the Windows installer: Flutter release build -> payload dir -> Inno Setup.
# A local build has no signing certificate, so pass -Unsigned; the release workflow
# signs the installer itself and calls iscc directly with its own flags.
param(
    [switch]$Unsigned,
    [string]$SignToolCommand,
    # Reuses the payload dir instead of rebuilding, e.g. after editing the .iss.
    [switch]$SkipBuild,
    # Defaults to <repo>\build\windows-payload. Keep it short: Inno Setup still
    # hits the 260-character limit on deeply nested payload trees.
    [string]$PayloadDir,
    # Defaults to <repo>\build\windows-installer.
    [string]$ResultDir
)

# Every path below is relative to the repo root, so do not depend on the caller's
# current directory.
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $Root

if (-not $PayloadDir) { $PayloadDir = Join-Path $Root 'build\windows-payload' }
if (-not $ResultDir) { $ResultDir = Join-Path $Root 'build\windows-installer' }

if (-not $SkipBuild) {
    $makepri = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin\10.*\x64\makepri.exe' | Select-Object -Last 1
    & $makepri.FullName new /pr support\build\msix\content /cf support\build\msix\priconfig.xml /mn support\build\msix\content\AppxManifest.xml /of support\build\msix\content\resources.pri /o
    & 'C:\Program Files (x86)\Windows Kits\10\App Certification Kit\makeappx.exe' pack /o /d support\build\msix\content /nv /p app\windows\sonar_msix_helper.msix

    Push-Location app
    fvm flutter clean
    fvm flutter pub get
    fvm flutter build windows
    Pop-Location

    Remove-Item $PayloadDir -Force -Recurse -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $PayloadDir | Out-Null
    Copy-Item -Path 'app\build\windows\x64\runner\Release\*' -Destination $PayloadDir -Recurse
    Copy-Item -Path 'app\assets\packaging\logo.ico' -Destination $PayloadDir
    Copy-Item -Path 'support\build\windows\x64\*' -Destination $PayloadDir -Recurse
}

Remove-Item $ResultDir -Force -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null

# Inno Setup 7 replaced /D and /S with --define= and --signtool=; the CI runner still
# has Inno 6 preinstalled, so take the syntax from the compiler that is installed.
$iscc = (Get-Command iscc -ErrorAction Stop).Source
$isccMajor = (Get-Item $iscc).VersionInfo.FileMajorPart
$definePrefix = if ($isccMajor -ge 7) { '--define=' } else { '/D' }

$isccArgs = @("${definePrefix}PayloadDir=$PayloadDir", "${definePrefix}ResultDir=$ResultDir")
if ($Unsigned) {
    $isccArgs += "${definePrefix}SkipSignTool", "${definePrefix}SkipMsixHelper"
}
elseif ($SignToolCommand) {
    $signArg = if ($isccMajor -ge 7) { "--signtool=MySignTool=$SignToolCommand" } else { "/SMySignTool=$SignToolCommand" }
    $isccArgs += $signArg
}
$isccArgs += '.\support\scripts\compile_windows_exe-inno.iss'
& $iscc @isccArgs

Write-Output "Generated Windows exe installer in $ResultDir"
