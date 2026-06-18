$ErrorActionPreference = "Continue"

$Urls = @(
    "https://developer.download.nvidia.com/compute/cuda/12.6.3/local_installers/cuda_12.6.3_561.17_windows.exe",
    "https://developer.download.nvidia.com/compute/cuda/12.6.3/network_installers/cuda_12.6.3_windows_network.exe",
    "https://developer.download.nvidia.com/compute/cuda/12.6.3/local_installers/cuda-repo-wsl-ubuntu-12-6-local_12.6.3-1_amd64.deb",
    "https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb"
)

foreach ($Url in $Urls) {
    Write-Host "== $Url =="
    try {
        $Response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 30
        Write-Host "Status: $($Response.StatusCode)"
        Write-Host "Length: $($Response.Headers['Content-Length'])"
        Write-Host "Type: $($Response.Headers['Content-Type'])"
    } catch {
        Write-Host "FAILED: $($_.Exception.Message)"
    }
    Write-Host ""
}
