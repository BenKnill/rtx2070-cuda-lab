param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$MessageParts
)

$ErrorActionPreference = "Stop"

$repo = "C:\Users\18572\blender-wsl-render\rtx2070-cuda-lab"
Set-Location $repo

$message = ($MessageParts -join " ").Trim()
if ([string]::IsNullOrWhiteSpace($message)) {
    $message = "alive"
}

$stamp = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, "Eastern Standard Time").ToString("yyyy-MM-dd HH:mm:ss")
$line = "          <p class=""codex-status"" id=""codex-status"">Codex live status: $stamp ET - $message</p>"

$path = Join-Path $repo "docs\index.html"
$text = Get-Content -LiteralPath $path -Raw

if ($text -match 'id="codex-status"') {
    $text = [regex]::Replace($text, '<p class="codex-status" id="codex-status">.*?</p>', $line, 1)
} else {
    $needle = @"
          <p class="lede">
            Small visual exports from resurrected NVIDIA CUDA sample demos on the RTX 2070 Windows/WSL render box.
          </p>
"@
    $replacement = $needle + "`n" + $line
    $text = $text.Replace($needle, $replacement)
}

Set-Content -LiteralPath $path -Value $text -NoNewline

git add docs/index.html
git commit -m "Update Codex live status"
git push origin main
git log --oneline --decorate -1
