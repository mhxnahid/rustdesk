#Requires -RunAsAdministrator
<#
One-time setup of a Windows 10/11 x64 machine for building the Citrus Remote Viewer client.

Run from an elevated PowerShell while signed in as the user who will run build.ps1
(Rust, Python and the pub cache are installed per user). Safe to re-run: each step
skips work that is already done.
#>
param(
    [switch]$NoDefenderExclusions
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Install-WingetPackage([string]$Id, [string]$Command) {
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Host "  $Id already installed"
        return
    }
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements
    Assert-LastExit "winget install $Id"
    Update-SessionPath
}

function Install-Flutter([string]$Version, [string]$Root) {
    if (Test-Path (Join-Path $Root 'bin\flutter.bat')) {
        Write-Host "  Flutter $Version already at $Root"
        return
    }
    $zip = Join-Path $Downloads "flutter_windows_$Version-stable.zip"
    Get-File "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$Version-stable.zip" $zip
    $tmp = New-TempDir
    Expand-Zip $zip $tmp
    Move-Item (Join-Path $tmp 'flutter') $Root
    Remove-Item $tmp -Recurse -Force
}

function Add-GitSafeDirectory([string]$Path) {
    $path = $Path.Replace('\', '/')
    $existing = @(git config --global --get-all safe.directory)
    if ($existing -notcontains $path) { git config --global --add safe.directory $path }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget not found. Install "App Installer" from the Microsoft Store, then re-run.'
}

Write-Step 'Developer Mode (Flutter plugins need symlinks) and long paths'
$devKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path $devKey)) { New-Item -Path $devKey | Out-Null }
Set-ItemProperty -Path $devKey -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1 -Type DWord

Write-Step 'Git and Python'
Install-WingetPackage 'Git.Git' 'git'
Install-WingetPackage 'Python.Python.3.12' 'py'
git config --global core.longpaths true

Write-Step 'Visual Studio 2022 Build Tools (C++ workload)'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
function Test-VcTools {
    if (-not (Test-Path $vswhere)) { return $false }
    $found = & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    return [bool]$found
}
if (Test-VcTools) {
    Write-Host '  MSVC C++ tools already installed'
} else {
    # The VS installer often exits non-zero just to ask for a reboot, so check the result instead.
    winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-package-agreements --accept-source-agreements `
        --override '--wait --quiet --norestart --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.ATL --includeRecommended'
    if (-not (Test-VcTools)) { throw 'Visual Studio C++ build tools did not install. Check the VS installer log in %TEMP%.' }
}

Write-Step "LLVM $LlvmVersion (bindgen, ffigen)"
$clang = Join-Path $LlvmBin 'clang.exe'
$haveLlvm = (Test-Path $clang) -and ((& $clang --version | Out-String) -match "version $([regex]::Escape($LlvmVersion))")
if ($haveLlvm) {
    Write-Host '  already installed'
} else {
    $exe = Join-Path $Downloads "LLVM-$LlvmVersion-win64.exe"
    Get-File "https://github.com/llvm/llvm-project/releases/download/llvmorg-$LlvmVersion/LLVM-$LlvmVersion-win64.exe" $exe
    $proc = Start-Process -FilePath $exe -ArgumentList '/S' -Wait -PassThru
    if ($proc.ExitCode -ne 0) { throw "LLVM installer failed with exit code $($proc.ExitCode)" }
}

Write-Step "Rust $RustVersion and bridge codegen tools"
Install-WingetPackage 'Rustlang.Rustup' 'rustup'
rustup toolchain install $RustVersion --profile minimal -c rustfmt
Assert-LastExit 'rustup toolchain install'
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (-not (Test-Path (Join-Path $cargoBin 'cargo-expand.exe'))) {
    cargo "+$RustVersion" install cargo-expand --version $CargoExpandVersion --locked
    Assert-LastExit 'cargo install cargo-expand'
}
if (-not (Test-Path (Join-Path $cargoBin 'flutter_rust_bridge_codegen.exe'))) {
    cargo "+$RustVersion" install flutter_rust_bridge_codegen --version $FrbCodegenVersion --features uuid --locked
    Assert-LastExit 'cargo install flutter_rust_bridge_codegen'
}

Write-Step "Flutter $FlutterVersion (build) and $BridgeFlutterVersion (bridge codegen)"
Install-Flutter $FlutterVersion $FlutterRoot
Install-Flutter $BridgeFlutterVersion $BridgeFlutterRoot
Add-GitSafeDirectory $FlutterRoot
Add-GitSafeDirectory $BridgeFlutterRoot
$flutter = Join-Path $FlutterRoot 'bin\flutter.bat'
& $flutter config --no-analytics | Out-Null
& $flutter precache --windows
Assert-LastExit 'flutter precache'
& (Join-Path $BridgeFlutterRoot 'bin\flutter.bat') --version
Assert-LastExit "flutter $BridgeFlutterVersion bootstrap"

Write-Step 'RustDesk custom Flutter engine (https://github.com/flutter/flutter/issues/155685)'
if (Test-Path $EngineMarker) {
    Write-Host '  already installed'
} else {
    $zip = Join-Path $Downloads 'rustdesk-engine-windows-x64-release.zip'
    Get-File 'https://github.com/rustdesk/engine/releases/download/main/windows-x64-release.zip' $zip
    $tmp = New-TempDir
    Expand-Zip $zip $tmp
    Copy-Item (Join-Path $tmp '*') (Split-Path $EngineMarker) -Recurse -Force
    Remove-Item $tmp -Recurse -Force
    Set-Content -Path $EngineMarker -Value (Get-Date -Format o)
}

Write-Step 'Flutter dropdown_menu patch'
# The checkout may have CRLF line endings (.gitattributes text=auto); git apply wants LF.
$diff = Join-Path $env:TEMP 'citrus-flutter-dropdown.diff'
$patch = [IO.File]::ReadAllText((Join-Path $RepoRoot '.github\patches\flutter_3.24.4_dropdown_menu_enableFilter.diff'))
[IO.File]::WriteAllText($diff, $patch.Replace("`r`n", "`n"))
if (Test-NativeSuccess { git -C $FlutterRoot apply --check -R --ignore-whitespace $diff }) {
    Write-Host '  already applied'
} else {
    git -C $FlutterRoot apply --ignore-whitespace $diff
    Assert-LastExit 'git apply flutter patch'
}

Write-Step "vcpkg at $VcpkgCommit"
if (-not (Test-Path (Join-Path $VcpkgRoot '.git'))) {
    git clone https://github.com/microsoft/vcpkg $VcpkgRoot
    Assert-LastExit 'git clone vcpkg'
}
Add-GitSafeDirectory $VcpkgRoot
if (-not (Test-NativeSuccess { git -C $VcpkgRoot cat-file -e "$VcpkgCommit^{commit}" })) {
    git -C $VcpkgRoot fetch origin
    Assert-LastExit 'git fetch vcpkg'
}
git -C $VcpkgRoot -c advice.detachedHead=false checkout $VcpkgCommit
Assert-LastExit 'git checkout vcpkg'
& (Join-Path $VcpkgRoot 'bootstrap-vcpkg.bat') -disableMetrics
Assert-LastExit 'bootstrap-vcpkg'

if (-not $NoDefenderExclusions) {
    Write-Step 'Windows Defender exclusions for build directories'
    $paths = @(
        $RepoRoot, $VcpkgRoot, $FlutterRoot, $BridgeFlutterRoot,
        (Join-Path $env:USERPROFILE '.cargo'),
        (Join-Path $env:USERPROFILE '.rustup'),
        (Join-Path $env:LOCALAPPDATA 'vcpkg'),
        (Join-Path $env:LOCALAPPDATA 'Pub\Cache')
    )
    try { Add-MpPreference -ExclusionPath $paths } catch { Write-Warning "Could not add Defender exclusions: $_" }
}

Write-Step 'Done'
Write-Host 'Reboot if the Visual Studio installer asked for it, then run build.ps1 from a normal (non-admin) PowerShell.'
