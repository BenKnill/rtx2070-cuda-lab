$ErrorActionPreference = "Continue"

$Root = "C:\Users\18572\blender-wsl-render"
$LogDir = Join-Path $Root "cuda_care_logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogPath = Join-Path $LogDir "windows-inventory-$Stamp.txt"

function Write-Section($Name) {
    "`n== $Name ==" | Tee-Object -FilePath $LogPath -Append
}

"CUDA care Windows inventory $Stamp" | Tee-Object -FilePath $LogPath

Write-Section "nvidia-smi"
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    nvidia-smi 2>&1 | Tee-Object -FilePath $LogPath -Append
} else {
    "nvidia-smi not found on PATH" | Tee-Object -FilePath $LogPath -Append
}

Write-Section "nvcc"
where.exe nvcc 2>&1 | Tee-Object -FilePath $LogPath -Append
Get-ChildItem "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA" -Directory -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName |
    Tee-Object -FilePath $LogPath -Append

Write-Section "CUDA folders"
Get-ChildItem "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA" -Recurse -Filter nvcc.exe -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName |
    Tee-Object -FilePath $LogPath -Append

Write-Section "Visual Studio"
$VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $VsWhere) {
    & $VsWhere -all -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>&1 |
        Tee-Object -FilePath $LogPath -Append
} else {
    "vswhere not found" | Tee-Object -FilePath $LogPath -Append
}

Write-Section "Windows version"
cmd /c ver 2>&1 | Tee-Object -FilePath $LogPath -Append

Write-Section "PowerShell"
$PSVersionTable | Out-String | Tee-Object -FilePath $LogPath -Append

"`nLog: $LogPath" | Tee-Object -FilePath $LogPath -Append
