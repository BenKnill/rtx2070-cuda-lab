param(
    [Parameter(Mandatory = $true)]
    [string]$RunDir,
    [string]$Title = "Outbox render",
    [string]$Description = "Render output published from the Windows-visible outbox."
)

$ErrorActionPreference = "Stop"

$repo = "C:\Users\18572\blender-wsl-render\rtx2070-cuda-lab"
$mediaDir = Join-Path $repo "docs\media"
Set-Location $repo

if (-not (Test-Path -LiteralPath $RunDir -PathType Container)) {
    throw "Outbox directory not found: $RunDir"
}

New-Item -ItemType Directory -Force -Path $mediaDir | Out-Null

$slug = (Split-Path -Leaf $RunDir).ToLowerInvariant() -replace '[^a-z0-9]+','-'
$slug = $slug.Trim('-')
$stamp = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, "Eastern Standard Time").ToString("yyyy-MM-dd HH:mm:ss") + " ET"

$posterSrc = Join-Path $RunDir "poster.png"
if (-not (Test-Path -LiteralPath $posterSrc)) {
    $posterSrc = Join-Path $RunDir "preview.png"
}
if (-not (Test-Path -LiteralPath $posterSrc)) {
    throw "No poster.png or preview.png found in $RunDir"
}

$poster = "media/${slug}_poster.png"
Copy-Item -LiteralPath $posterSrc -Destination (Join-Path $repo "docs\$poster") -Force

$mp4 = ""
$gif = ""
$sun = ""
$mask = ""
$extra = ""

$mp4Src = Join-Path $RunDir "clip.mp4"
if (-not (Test-Path -LiteralPath $mp4Src)) { $mp4Src = Join-Path $RunDir "starship_imagegen_texture_scene.mp4" }
if (Test-Path -LiteralPath $mp4Src) {
    $mp4 = "media/${slug}.mp4"
    Copy-Item -LiteralPath $mp4Src -Destination (Join-Path $repo "docs\$mp4") -Force
}

$gifSrc = Join-Path $RunDir "clip.gif"
if (-not (Test-Path -LiteralPath $gifSrc)) { $gifSrc = Join-Path $RunDir "starship_imagegen_texture_scene.gif" }
if (Test-Path -LiteralPath $gifSrc) {
    $gif = "media/${slug}.gif"
    Copy-Item -LiteralPath $gifSrc -Destination (Join-Path $repo "docs\$gif") -Force
}

foreach ($candidate in @("stellar_surface_preview.png", "sun.png")) {
    $path = Join-Path $RunDir $candidate
    if (Test-Path -LiteralPath $path) {
        $sun = "media/${slug}_sun.png"
        Copy-Item -LiteralPath $path -Destination (Join-Path $repo "docs\$sun") -Force
        break
    }
}

foreach ($candidate in @("mask.png", "star_occluder_optical_alpha.png", "star_window_mask_deepfield_imagegen.png")) {
    $path = Join-Path $RunDir $candidate
    if (Test-Path -LiteralPath $path) {
        $mask = "media/${slug}_mask.png"
        Copy-Item -LiteralPath $path -Destination (Join-Path $repo "docs\$mask") -Force
        break
    }
}

$downloads = @("<a class=""button"" href=""$poster"">PNG</a>")
if ($gif) { $downloads += "<a class=""button"" href=""$gif"">GIF</a>" }
if ($mp4) { $downloads += "<a class=""button"" href=""$mp4"">MP4</a>" }
if ($sun) { $downloads += "<a class=""button"" href=""$sun"">SUN</a>" }
if ($mask) { $downloads += "<a class=""button"" href=""$mask"">MASK</a>" }

if ($mp4) {
    $mediaHtml = @"
<video autoplay loop muted playsinline poster="$poster" aria-label="$Title">
              <source src="$mp4" type="video/mp4">
            </video>
"@
} else {
    $mediaHtml = "<img src=""$poster"" alt=""$Title"">"
}

$post = @"
        <div class="feature" id="post-$slug">
          <figure>
            $mediaHtml
            <figcaption>
              <strong>$Title</strong>
              $Description
              <div class="downloads">
                $($downloads -join ' ')
              </div>
            </figcaption>
          </figure>
          <div class="notes">
            <h2>$stamp</h2>
            <p>
              Published from render outbox <code>$slug</code>. New posts are inserted at the top of this gallery.
            </p>
          </div>
        </div>

"@

$indexPath = Join-Path $repo "docs\index.html"
$text = Get-Content -LiteralPath $indexPath -Raw
$needle = "      <section class=""gallery"" aria-label=""CUDA sample outputs"">`n"
if (-not $text.Contains($needle)) {
    throw "Gallery insertion point not found"
}
$text = $text.Replace($needle, $needle + $post)
Set-Content -LiteralPath $indexPath -Value $text -NoNewline

git add docs/index.html "docs/$poster"
if ($mp4) { git add "docs/$mp4" }
if ($gif) { git add "docs/$gif" }
if ($sun) { git add "docs/$sun" }
if ($mask) { git add "docs/$mask" }
git commit -m "Publish outbox post $slug"
git push origin main
git log --oneline --decorate -1
