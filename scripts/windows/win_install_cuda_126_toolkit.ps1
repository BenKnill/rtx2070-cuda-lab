$ErrorActionPreference = "Stop"

$Root = "C:\Users\18572\blender-wsl-render"
$DownloadDir = Join-Path $Root "downloads"
$LogDir = Join-Path $Root "cuda_care_logs"
New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$InstallerUrl = "https://developer.download.nvidia.com/compute/cuda/12.6.3/network_installers/cuda_12.6.3_windows_network.exe"
$InstallerPath = Join-Path $DownloadDir "cuda_12.6.3_windows_network.exe"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogPath = Join-Path $LogDir "windows-cuda126-install-$Stamp.txt"

function Log($Message) {
    $Message | Tee-Object -FilePath $LogPath -Append
}

Log "CUDA 12.6.3 Windows toolkit install $Stamp"
Log "Installer: $InstallerUrl"

if (!(Test-Path $InstallerPath) -or ((Get-Item $InstallerPath).Length -lt 30000000)) {
    Log "Downloading installer to $InstallerPath"
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing
} else {
    Log "Using existing installer at $InstallerPath"
}

$InstallArgs = @(
    "-s",
    "-n",
    "nvcc_12.6",
    "cudart_12.6",
    "cupti_12.6",
    "cublas_12.6",
    "cublas_dev_12.6",
    "cufft_12.6",
    "cufft_dev_12.6",
    "curand_12.6",
    "curand_dev_12.6",
    "cusolver_12.6",
    "cusolver_dev_12.6",
    "cusparse_12.6",
    "cusparse_dev_12.6",
    "npp_12.6",
    "npp_dev_12.6",
    "nvjpeg_12.6",
    "nvjpeg_dev_12.6",
    "nvrtc_12.6",
    "nvrtc_dev_12.6",
    "nvtx_12.6",
    "nvml_dev_12.6",
    "opencl_12.6",
    "visual_studio_integration_12.6",
    "demo_suite_12.6",
    "sanitizer_12.6"
)

Log "Running installer with toolkit-only component list:"
Log ($InstallArgs -join " ")

$Process = Start-Process -FilePath $InstallerPath -ArgumentList $InstallArgs -Wait -PassThru
Log "Installer exit code: $($Process.ExitCode)"

$Nvcc = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6\bin\nvcc.exe"
if (Test-Path $Nvcc) {
    Log "Found CUDA 12.6 nvcc:"
    & $Nvcc --version 2>&1 | Tee-Object -FilePath $LogPath -Append
} else {
    Log "CUDA 12.6 nvcc not found at $Nvcc"
    exit 1
}

Log "Done. Log: $LogPath"
