# Building the Windows x64 client locally

These scripts reproduce the `build-for-windows-flutter` CI job on a Windows 10/11 x64
machine, with the same pinned toolchain (see `common.ps1`).

## First time

Give the VM 8+ cores and 16 GB+ RAM, and keep the checkout on the VM's own disk
(not a shared folder).

```powershell
winget install --id Git.Git -e
# open a new terminal so git is on PATH
git clone --recurse-submodules -b citrus-rebrand https://github.com/mhxnahid/rustdesk C:\src\rustdesk
cd C:\src\rustdesk

# elevated PowerShell, signed in as the user who will build:
powershell -ExecutionPolicy Bypass -File res\win-build\setup.ps1
```

`setup.ps1` installs VS 2022 Build Tools (C++), LLVM, Python, Rust, two Flutter SDKs
(3.24.5 to build, 3.22.3 for bridge codegen), RustDesk's patched Flutter engine and
vcpkg. It also enables Developer Mode and long paths, and adds Defender exclusions for
the build directories (`-NoDefenderExclusions` to skip). Re-running it is safe.

## Build

From a normal PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File res\win-build\build.ps1          # release build
powershell -ExecutionPolicy Bypass -File res\win-build\build.ps1 -Fast    # quick test build
```

The portable client ends up in `target\dist\CitrusRemoteViewer-win64\`; run
`citrusremoteviewer.exe` from there. Add `-Zip` for a zip next to it.

The first build compiles the vcpkg dependencies (ffmpeg, aom, libvpx, ...) and takes
hours. After that, a release rebuild takes 15-25 minutes and `-Fast` a few minutes.

The flutter_rust_bridge files are gitignored; `build.ps1` regenerates them through
`gen-bridge.ps1` whenever `src\flutter_ffi.rs` changes.

## Differences from CI

- No code signing, MSI or single-file installer (`--skip-portable-pack`).
- RustDeskTempTopMostWindow (used by one privacy-mode implementation) is not built.
