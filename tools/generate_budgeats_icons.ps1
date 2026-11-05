Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Get-Color([string] $hex) {
    return [System.Drawing.ColorTranslator]::FromHtml($hex)
}

function New-RoundRectPath([float] $x, [float] $y, [float] $width, [float] $height, [float] $radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $radius * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
    $path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-LogoBitmap([int] $pixels, [bool] $maskable = $false) {
    $bitmap = [System.Drawing.Bitmap]::new($pixels, $pixels, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.ScaleTransform($pixels / 100.0, $pixels / 100.0)

    $outline = [System.Drawing.Pen]::new((Get-Color '#59422F'), 1.8)
    $outline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $outline.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $outline.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $background = [System.Drawing.SolidBrush]::new((Get-Color '#F8E1DF'))
    $graphics.FillRectangle($background, 0, 0, 100, 100)
    if ($maskable) {
        $graphics.TranslateTransform(10, 10)
        $graphics.ScaleTransform(0.8, 0.8)
    }

    foreach ($sparkle in @(@(33, 19, 5.4), @(89, 32, 4.4), @(11, 59, 4.3))) {
        $cx = [float]$sparkle[0]; $cy = [float]$sparkle[1]; $r = [float]$sparkle[2]
        $points = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new($cx, $cy - $r),
            [System.Drawing.PointF]::new($cx + 1.1, $cy - 1.1),
            [System.Drawing.PointF]::new($cx + $r, $cy),
            [System.Drawing.PointF]::new($cx + 1.1, $cy + 1.1),
            [System.Drawing.PointF]::new($cx, $cy + $r),
            [System.Drawing.PointF]::new($cx - 1.1, $cy + 1.1),
            [System.Drawing.PointF]::new($cx - $r, $cy),
            [System.Drawing.PointF]::new($cx - 1.1, $cy - 1.1)
        )
        $graphics.FillPolygon([System.Drawing.SolidBrush]::new((Get-Color '#FFC940')), $points)
        $graphics.DrawPolygon($outline, $points)
    }

    foreach ($coin in @(@(13, 39, 8.4), @(53, 15, 8.0), @(88, 45, 8.2))) {
        $cx = [float]$coin[0]; $cy = [float]$coin[1]; $r = [float]$coin[2]
        $rect = [System.Drawing.RectangleF]::new($cx - $r, $cy - $r, $r * 2, $r * 2)
        $graphics.FillEllipse([System.Drawing.SolidBrush]::new((Get-Color '#FFC940')), $rect)
        $graphics.DrawEllipse($outline, $rect)
        $inner = [System.Drawing.RectangleF]::new($cx - $r + 2.3, $cy - $r + 2.3, ($r - 2.3) * 2, ($r - 2.3) * 2)
        $graphics.DrawEllipse([System.Drawing.Pen]::new((Get-Color '#FFF0A6'), 1.2), $inner)
    }

    $leftNote = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(25, 53), [System.Drawing.PointF]::new(27, 39),
        [System.Drawing.PointF]::new(51, 27), [System.Drawing.PointF]::new(65, 42),
        [System.Drawing.PointF]::new(62, 54)
    )
    $graphics.FillPolygon([System.Drawing.SolidBrush]::new((Get-Color '#9BCB70')), $leftNote)
    $graphics.DrawPolygon($outline, $leftNote)
    $rightNote = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(38, 53), [System.Drawing.PointF]::new(57, 31),
        [System.Drawing.PointF]::new(76, 39), [System.Drawing.PointF]::new(79, 54)
    )
    $graphics.FillPolygon([System.Drawing.SolidBrush]::new((Get-Color '#77B95B')), $rightNote)
    $graphics.DrawPolygon($outline, $rightNote)
    $graphics.DrawLines($outline, [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(31, 48), [System.Drawing.PointF]::new(53, 37), [System.Drawing.PointF]::new(66, 43)
    ))
    $graphics.DrawLines($outline, [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(47, 49), [System.Drawing.PointF]::new(63, 39), [System.Drawing.PointF]::new(75, 46)
    ))

    $wallet = New-RoundRectPath 15 45 69 42 11
    $graphics.FillPath([System.Drawing.SolidBrush]::new((Get-Color '#C99B79')), $wallet)
    $graphics.DrawPath($outline, $wallet)
    $graphics.DrawCurve($outline, [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(17, 54), [System.Drawing.PointF]::new(36, 57),
        [System.Drawing.PointF]::new(61, 56), [System.Drawing.PointF]::new(82, 53)
    ))
    $stitchPen = [System.Drawing.Pen]::new((Get-Color '#E8C6A6'), 1.2)
    $stitchPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dot
    $graphics.DrawLine($stitchPen, 23, 77, 64, 77)

    $clasp = New-RoundRectPath 74 62 16 15 5
    $graphics.FillPath([System.Drawing.SolidBrush]::new((Get-Color '#D9AF8D')), $clasp)
    $graphics.DrawPath($outline, $clasp)
    $graphics.FillEllipse([System.Drawing.SolidBrush]::new((Get-Color '#FFC940')), 78.6, 66.1, 6.8, 6.8)
    $graphics.DrawEllipse([System.Drawing.Pen]::new((Get-Color '#59422F'), 1.7), 78.6, 66.1, 6.8, 6.8)

    $face = [System.Drawing.SolidBrush]::new((Get-Color '#59422F'))
    $graphics.FillEllipse($face, 39.5, 62.5, 3, 3)
    $graphics.FillEllipse($face, 55.5, 62.5, 3, 3)
    $graphics.FillEllipse($face, 46, 67.9, 6, 4.2)
    $blush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(220, (Get-Color '#E99A9C').R, (Get-Color '#E99A9C').G, (Get-Color '#E99A9C').B))
    $graphics.FillEllipse($blush, 31.5, 68.9, 5, 2.2)
    $graphics.FillEllipse($blush, 61.5, 68.9, 5, 2.2)

    $graphics.Dispose()
    return $bitmap
}

function Save-LogoPng([int] $pixels, [string] $path, [bool] $maskable = $false) {
    $bitmap = New-LogoBitmap $pixels $maskable
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

Save-LogoPng 32 (Join-Path $root 'web/favicon.png')
Save-LogoPng 192 (Join-Path $root 'web/icons/Icon-192.png')
Save-LogoPng 512 (Join-Path $root 'web/icons/Icon-512.png')
Save-LogoPng 192 (Join-Path $root 'web/icons/Icon-maskable-192.png') $true
Save-LogoPng 512 (Join-Path $root 'web/icons/Icon-maskable-512.png') $true

$androidSizes = @{ 'mipmap-mdpi' = 48; 'mipmap-hdpi' = 72; 'mipmap-xhdpi' = 96; 'mipmap-xxhdpi' = 144; 'mipmap-xxxhdpi' = 192 }
foreach ($entry in $androidSizes.GetEnumerator()) {
    Save-LogoPng $entry.Value (Join-Path $root "android/app/src/main/res/$($entry.Key)/ic_launcher.png")
}

$appIconSet = Join-Path $root 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
$contents = Get-Content -Raw (Join-Path $appIconSet 'Contents.json') | ConvertFrom-Json
foreach ($image in $contents.images) {
    $side = [double]($image.size -replace 'x.*$', '')
    $scale = [double]($image.scale -replace 'x$', '')
    $pixels = [int][math]::Round($side * $scale)
    Save-LogoPng $pixels (Join-Path $appIconSet $image.filename)
}

$iconBitmap = New-LogoBitmap 256
$pngStream = [System.IO.MemoryStream]::new()
$iconBitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
$iconBitmap.Dispose()
$pngBytes = $pngStream.ToArray()
$iconPath = Join-Path $root 'windows/runner/resources/app_icon.ico'
$iconStream = [System.IO.File]::Open($iconPath, [System.IO.FileMode]::Create)
$writer = [System.IO.BinaryWriter]::new($iconStream)
$writer.Write([UInt16]0)
$writer.Write([UInt16]1)
$writer.Write([UInt16]1)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([byte]0)
$writer.Write([UInt16]1)
$writer.Write([UInt16]32)
$writer.Write([UInt32]$pngBytes.Length)
$writer.Write([UInt32]22)
$writer.Write($pngBytes)
$writer.Dispose()
$iconStream.Dispose()
$pngStream.Dispose()

Write-Output 'Generated Budgeats icons for web, Android, iOS, and Windows.'
