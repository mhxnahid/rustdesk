<#
Builds the Citrus Remote Viewer Windows x64 client, mirroring the build-for-windows-flutter
CI job. Run setup.ps1 once first.

  -Fast         No LTO and parallel codegen: much quicker rebuilds, for testing only.
                Switching between -Fast and a normal build recompiles everything once.
  -SkipVcpkg    Skip the vcpkg install check (saves ~1 minute when deps are unchanged).
  -ForceBridge  Regenerate the flutter_rust_bridge files even if src/flutter_ffi.rs is unchanged.
  -NoDrivers    Skip bundling the virtual display and printer drivers.
  -Zip          Also write <OutDir>.zip.
#>
param(
    [switch]$Fast,
    [switch]$SkipVcpkg,
    [switch]$ForceBridge,
    [switch]$NoDrivers,
    [switch]$Zip,
    [string]$OutDir
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
if (-not $OutDir) { $OutDir = Join-Path $RepoRoot 'target\dist\CitrusRemoteViewer-win64' }

function Add-Drivers([string]$Dest) {
    Write-Step 'Virtual display driver'
    $zip = Join-Path $Downloads 'usbmmidd_v2.zip'
    Get-File 'https://github.com/rustdesk-org/rdev/releases/download/usbmmidd_v2/usbmmidd_v2.zip' $zip
    $tmp = New-TempDir
    Expand-Zip $zip $tmp
    $usb = Join-Path $tmp 'usbmmidd_v2'
    Remove-Item (Join-Path $usb 'Win32') -Recurse -Force
    Remove-Item (Join-Path $usb 'deviceinstaller64.exe'), (Join-Path $usb 'deviceinstaller.exe'), (Join-Path $usb 'usbmmidd.bat') -Force
    Copy-Item $usb $Dest -Recurse -Force
    Remove-Item $tmp -Recurse -Force

    Write-Step 'Printer driver'
    $base = 'https://github.com/rustdesk/hbb_common/releases/download/driver'
    $driverZip = Join-Path $Downloads 'rustdesk_printer_driver_v4-1.4.zip'
    $adapterZip = Join-Path $Downloads 'printer_driver_adapter.zip'
    $sums = Join-Path $Downloads 'printer-driver-sha256sums'
    try {
        Get-File "$base/rustdesk_printer_driver_v4-1.4.zip" $driverZip
        Get-File "$base/printer_driver_adapter.zip" $adapterZip
        Get-File "$base/sha256sums" $sums
        $sumText = Get-Content $sums -Raw
        foreach ($file in @($driverZip, $adapterZip)) {
            $name = [regex]::Escape((Split-Path $file -Leaf))
            $expected = [regex]::Match($sumText, "(?m)^([a-fA-F0-9]{64}) \*$name\s*$").Groups[1].Value
            if (-not $expected -or $expected -ne (Get-FileHash $file -Algorithm SHA256).Hash) {
                throw "checksum mismatch for $(Split-Path $file -Leaf)"
            }
        }
        $tmp = New-TempDir
        Expand-Zip $driverZip $tmp
        Expand-Zip $adapterZip $tmp
        New-Item -ItemType Directory -Force (Join-Path $Dest 'drivers') | Out-Null
        Move-Item (Join-Path $tmp 'rustdesk_printer_driver_v4-1.4') (Join-Path $Dest 'drivers\RustDeskPrinterDriver')
        Move-Item (Join-Path $tmp 'printer_driver_adapter.dll') $Dest
        Remove-Item $tmp -Recurse -Force
    } catch {
        Remove-Item $driverZip, $adapterZip, $sums -ErrorAction SilentlyContinue
        Write-Warning "Skipping the printer driver: $_"
    }
}

$started = Get-Date
$origLocation = Get-Location
try {
    Use-BuildEnv
    foreach ($tool in @((Join-Path $FlutterRoot 'bin\flutter.bat'), (Join-Path $VcpkgRoot 'vcpkg.exe'))) {
        if (-not (Test-Path $tool)) { throw "$tool not found. Run setup.ps1 first." }
    }
    if (-not (Test-Path $EngineMarker)) {
        Write-Warning "The RustDesk custom engine is missing from $FlutterRoot (Flutter may have re-downloaded its cache). Re-run setup.ps1."
    }
    Set-Location $RepoRoot

    if (-not $SkipVcpkg) {
        Write-Step 'vcpkg dependencies (slow the first time, cached afterwards)'
        $env:VCPKG_DEFAULT_HOST_TRIPLET = $VcpkgTriplet
        & (Join-Path $VcpkgRoot 'vcpkg.exe') install --triplet $VcpkgTriplet "--x-install-root=$VcpkgRoot\installed"
        Assert-LastExit 'vcpkg install'
    }

    # Fetch up front with visible progress; the bridge codegen hides cargo's output.
    Write-Step 'Fetching Rust dependencies'
    cargo fetch --locked --target x86_64-pc-windows-msvc
    Assert-LastExit 'cargo fetch'

    $missing = @($BridgeFiles | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
    $stale = (-not (Test-Path $BridgeStamp)) -or ((Get-Content $BridgeStamp -Raw) -ne (Get-FfiHash))
    if ($ForceBridge -or $missing.Count -gt 0 -or $stale) {
        Write-Step 'Generating flutter_rust_bridge files'
        & (Join-Path $PSScriptRoot 'gen-bridge.ps1')
    }

    $profileVars = @('CARGO_PROFILE_RELEASE_LTO', 'CARGO_PROFILE_RELEASE_CODEGEN_UNITS', 'CARGO_INCREMENTAL')
    if ($Fast) {
        $env:CARGO_PROFILE_RELEASE_LTO = 'false'
        $env:CARGO_PROFILE_RELEASE_CODEGEN_UNITS = '16'
        $env:CARGO_INCREMENTAL = '1'
    } else {
        foreach ($var in $profileVars) { Remove-Item "Env:$var" -ErrorAction SilentlyContinue }
    }

    Write-Step "Building ($(if ($Fast) { 'fast' } else { 'release' }))"
    $python = Get-PythonExe
    if (-not $python) { throw 'Python not found. Run setup.ps1 first.' }
    & $python build.py --portable --flutter --skip-portable-pack --hwcodec --vram
    Assert-LastExit 'build.py'

    Write-Step "Collecting output in $OutDir"
    $release = Join-Path $RepoRoot 'flutter\build\windows\x64\runner\Release'
    if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
    New-Item -ItemType Directory -Force $OutDir | Out-Null
    Copy-Item (Join-Path $release '*') $OutDir -Recurse
    if (-not $NoDrivers) { Add-Drivers $OutDir }

    if ($Zip) {
        $zipPath = "$OutDir.zip"
        Remove-Item $zipPath -ErrorAction SilentlyContinue
        Compress-Archive -Path (Join-Path $OutDir '*') -DestinationPath $zipPath
        Write-Host "  zip: $zipPath"
    }

    Write-Step ('Done in {0:hh\:mm\:ss}. Run {1}' -f ((Get-Date) - $started), (Join-Path $OutDir 'citrusremoteviewer.exe'))
} finally {
    Set-Location $origLocation
}
