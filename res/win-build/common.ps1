# Shared settings for setup.ps1, gen-bridge.ps1 and build.ps1.
# Versions are pinned to match .github/workflows/flutter-build.yml and bridge.yml;
# update them together.

$FlutterVersion       = '3.24.5'
$BridgeFlutterVersion = '3.22.3'
$RustVersion          = '1.75'
$LlvmVersion          = '15.0.6'
$VcpkgCommit          = '9e593bb18ea69cc5095e012465dcd675a822ed0d'
$CargoExpandVersion   = '1.0.95'
$FrbCodegenVersion    = '1.80.1'
$VcpkgTriplet         = 'x64-windows-static'

$FlutterRoot       = 'C:\flutter'
$BridgeFlutterRoot = 'C:\flutter-3.22.3'
$VcpkgRoot         = 'C:\vcpkg'
$LlvmBin           = 'C:\Program Files\LLVM\bin'

$RepoRoot     = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Downloads    = Join-Path $RepoRoot 'target\win-downloads'
$EngineMarker = Join-Path $FlutterRoot 'bin\cache\artifacts\engine\windows-x64-release\.rustdesk-custom-engine'
$BridgeStamp  = Join-Path $RepoRoot 'target\bridge.stamp'
$BridgeFiles  = @(
    'src\bridge_generated.rs',
    'src\bridge_generated.io.rs',
    'flutter\lib\generated_bridge.dart',
    'flutter\lib\generated_bridge.freezed.dart'
)

$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -ItemType Directory -Force $Downloads | Out-Null

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-LastExit([string]$What) {
    if ($LASTEXITCODE -ne 0) { throw "$What failed with exit code $LASTEXITCODE" }
}

# Runs a native command only for its exit code. Windows PowerShell 5.1 turns redirected
# stderr into errors, which would abort a script running with ErrorActionPreference=Stop.
function Test-NativeSuccess([scriptblock]$Command) {
    $ErrorActionPreference = 'Continue'
    & $Command 2>&1 | Out-Null
    return $LASTEXITCODE -eq 0
}

function Get-File([string]$Url, [string]$Dest) {
    if (Test-Path $Dest) { return }
    Write-Host "  downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile "$Dest.part" -UseBasicParsing
    Move-Item "$Dest.part" $Dest
}

function Expand-Zip([string]$Zip, [string]$Dest) {
    New-Item -ItemType Directory -Force $Dest | Out-Null
    # tar.exe ships with Windows 10 1803+ and is much faster than Expand-Archive.
    tar.exe -xf $Zip -C $Dest
    if ($LASTEXITCODE -ne 0) { Expand-Archive -Path $Zip -DestinationPath $Dest -Force }
}

function New-TempDir {
    $dir = Join-Path $env:TEMP ('citrus-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $dir | Out-Null
    return $dir
}

function Get-FfiHash {
    return (Get-FileHash (Join-Path $RepoRoot 'src\flutter_ffi.rs') -Algorithm SHA256).Hash
}

# Puts the pinned toolchain first on PATH for this PowerShell session.
function Use-BuildEnv([string]$Flutter = $FlutterRoot) {
    $cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
    $env:Path = "$Flutter\bin;$cargoBin;$LlvmBin;" +
        [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:VCPKG_ROOT = $VcpkgRoot
    $env:LIBCLANG_PATH = $LlvmBin
    $env:RUSTUP_TOOLCHAIN = $RustVersion
}
