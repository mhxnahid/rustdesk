<#
Regenerates the gitignored flutter_rust_bridge files the same way .github/workflows/bridge.yml
does. build.ps1 runs this automatically when the files are missing or src/flutter_ffi.rs changed.
#>
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$flutterDir = Join-Path $RepoRoot 'flutter'
$backup = New-TempDir
Copy-Item (Join-Path $flutterDir 'pubspec.yaml'), (Join-Path $flutterDir 'pubspec.lock') $backup
$origLocation = Get-Location
$origPath = $env:Path
try {
    Use-BuildEnv -Flutter $BridgeFlutterRoot

    # Same downgrade as bridge.yml: Flutter 3.22.3's Dart cannot resolve extended_text 14.
    $pubspec = Join-Path $flutterDir 'pubspec.yaml'
    $text = [IO.File]::ReadAllText($pubspec)
    [IO.File]::WriteAllText($pubspec, $text.Replace('extended_text: 14.0.0', 'extended_text: 13.0.0'))

    Set-Location $flutterDir
    flutter pub get
    Assert-LastExit 'flutter pub get'

    Set-Location $RepoRoot
    Write-Host '  running cargo expand: compiles the crate without printing anything, slow the first time'
    flutter_rust_bridge_codegen --rust-input .\src\flutter_ffi.rs --dart-output .\flutter\lib\generated_bridge.dart --c-output .\flutter\macos\Runner\bridge_generated.h
    Assert-LastExit 'flutter_rust_bridge_codegen'

    Set-Content -Path $BridgeStamp -Value (Get-FfiHash) -NoNewline
} finally {
    Copy-Item (Join-Path $backup '*') $flutterDir -Force
    Remove-Item $backup -Recurse -Force
    # The copies keep their old timestamps, which would make the next flutter command skip
    # `pub get` and keep the downgraded extended_text resolved above.
    foreach ($name in @('pubspec.yaml', 'pubspec.lock')) {
        (Get-Item (Join-Path $flutterDir $name)).LastWriteTime = Get-Date
    }
    Set-Location $origLocation
    $env:Path = $origPath
}
