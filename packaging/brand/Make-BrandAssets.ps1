<#
  Generate ORIGINAL branded installer artwork for UPES-ECS (no real UPES logo asset exists;
  the only image in the repo is Flutter's default placeholder icon, which we must NOT use).
  Theme: emergency, built around "111" (the number staff dial). Professional navy + red.

  Produces (in this folder):
    brand.ico          multi-res PNG icon (256/48/32/16) - SetupIconFile
    wizard-large.bmp   164x314 sidebar (Welcome/Finish pages) - WizardImageFile
    wizard-small.bmp   55x58 header mark - WizardSmallImageFile

  ASCII-only (Windows PowerShell 5.1). Requires System.Drawing (present on Windows).
#>
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$Here = $PSScriptRoot

$navyTop = [System.Drawing.Color]::FromArgb(0xFF,0x14,0x2C,0x4E)
$navyBot = [System.Drawing.Color]::FromArgb(0xFF,0x0A,0x1A,0x30)
$red     = [System.Drawing.Color]::FromArgb(0xFF,0xE4,0x00,0x2B)
$white   = [System.Drawing.Color]::White
$grey    = [System.Drawing.Color]::FromArgb(0xFF,0xB8,0xC4,0xD4)

function New-Gfx($bmp){
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g
}
function RF($x,$y,$w,$h){ New-Object System.Drawing.RectangleF ([single]$x,[single]$y,[single]$w,[single]$h) }
function Centered { $sf = New-Object System.Drawing.StringFormat; $sf.Alignment=[System.Drawing.StringAlignment]::Center; $sf.LineAlignment=[System.Drawing.StringAlignment]::Center; $sf.FormatFlags=[System.Drawing.StringFormatFlags]::NoWrap; $sf }

# ---- emblem: draw a red disc with white bold "111" onto a graphics at (cx,cy,r) ----
function Draw-Emblem($g,$cx,$cy,$r){
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $red), ($cx-$r), ($cy-$r), (2*$r), (2*$r))
  $ring = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(0x55,0xFF,0xFF,0xFF)), ([single]([math]::Max(2,$r*0.06)))
  $g.DrawEllipse($ring, ($cx-$r*0.82), ($cy-$r*0.82), (1.64*$r), (1.64*$r))
  $fs = [single]($r*0.78)
  $font = New-Object System.Drawing.Font('Segoe UI',$fs,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
  $rect = New-Object System.Drawing.RectangleF (($cx-$r*1.3), ($cy-$r), (2.6*$r), (2*$r))
  $g.DrawString('111',$font,(New-Object System.Drawing.SolidBrush $white),$rect,(Centered))
}

# ---------- 1) sidebar: 164x314 (1x) + 328x628 (2x) for crisp high-DPI ----------
function Make-Sidebar($s,$file){
  $W=[int](164*$s); $H=[int](314*$s)
  $bmp = New-Object System.Drawing.Bitmap $W,$H
  $g = New-Gfx $bmp
  $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0,0), (New-Object System.Drawing.Point 0,$H), $navyTop, $navyBot
  $g.FillRectangle($grad,0,0,$W,$H)
  Draw-Emblem $g ([int]($W/2)) ([int](96*$s)) ([int](46*$s))
  $fTitle = New-Object System.Drawing.Font('Segoe UI',[single](20*$s),[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
  $fSub   = New-Object System.Drawing.Font('Segoe UI',[single](11*$s),[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
  $fFoot  = New-Object System.Drawing.Font('Segoe UI',[single](9*$s),[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString('UPES-ECS',$fTitle,(New-Object System.Drawing.SolidBrush $white),(RF 0 (182*$s) $W (28*$s)),(Centered))
  $g.DrawString('EMERGENCY PBX',$fSub,(New-Object System.Drawing.SolidBrush $grey),(RF 0 (208*$s) $W (20*$s)),(Centered))
  $g.DrawString('Offline Installer',$fFoot,(New-Object System.Drawing.SolidBrush $grey),(RF 0 (286*$s) $W (16*$s)),(Centered))
  $g.Dispose()
  $bmp.Save((Join-Path $Here $file),[System.Drawing.Imaging.ImageFormat]::Bmp)
  $bmp.Dispose()
}
Make-Sidebar 1 'wizard-large.bmp'
Make-Sidebar 2 'wizard-large-2x.bmp'

# ---------- 2) small header mark: 55x58 (1x) + 110x116 (2x) ----------
function Make-Small($s,$file){
  $W=[int](55*$s); $H=[int](58*$s)
  $bmp = New-Object System.Drawing.Bitmap $W,$H
  $g = New-Gfx $bmp
  $g.FillRectangle((New-Object System.Drawing.SolidBrush $navyTop),0,0,$W,$H)
  Draw-Emblem $g ([int](27*$s)) ([int](29*$s)) ([int](21*$s))
  $g.Dispose()
  $bmp.Save((Join-Path $Here $file),[System.Drawing.Imaging.ImageFormat]::Bmp)
  $bmp.Dispose()
}
Make-Small 1 'wizard-small.bmp'
Make-Small 2 'wizard-small-2x.bmp'

# ---------- 3) icon: 256 master, rounded-red bg + white 111, exported as multi-res PNG ico ----
$master = New-Object System.Drawing.Bitmap 256,256
$g = New-Gfx $master
$g.Clear([System.Drawing.Color]::Transparent)
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$d=48; $x=8; $y=8; $w=240; $h=240
$path.AddArc($x,$y,$d,$d,180,90); $path.AddArc(($x+$w-$d),$y,$d,$d,270,90)
$path.AddArc(($x+$w-$d),($y+$h-$d),$d,$d,0,90); $path.AddArc($x,($y+$h-$d),$d,$d,90,90); $path.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush $red),$path)
$fIco = New-Object System.Drawing.Font('Segoe UI',118,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString('111',$fIco,(New-Object System.Drawing.SolidBrush $white),(New-Object System.Drawing.RectangleF 0,-4,256,256),(Centered))
$g.Dispose()

function Save-MultiIco($masterBmp,$outPath){
  $sizes = 256,48,32,16
  $pngs = @()
  foreach($s in $sizes){
    $b = New-Object System.Drawing.Bitmap $s,$s
    $gg = New-Gfx $b
    $gg.Clear([System.Drawing.Color]::Transparent)
    $gg.DrawImage($masterBmp,0,0,$s,$s)
    $gg.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $b.Save($ms,[System.Drawing.Imaging.ImageFormat]::Png)
    $pngs += ,(@{ size=$s; data=$ms.ToArray() })
    $b.Dispose(); $ms.Dispose()
  }
  $fs = [System.IO.File]::Create($outPath)
  $bw = New-Object System.IO.BinaryWriter($fs)
  $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$pngs.Count)
  $offset = 6 + 16*$pngs.Count
  foreach($p in $pngs){
    $s=$p.size; $len=$p.data.Length
    $dim = if($s -ge 256){0}else{$s}
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$len); $bw.Write([uint32]$offset)
    $offset += $len
  }
  foreach($p in $pngs){ $bw.Write($p.data) }
  $bw.Flush(); $fs.Close()
}
Save-MultiIco $master (Join-Path $Here 'brand.ico')
$master.Dispose()

Write-Host "brand assets written to $Here :" -ForegroundColor Green
Get-ChildItem $Here -Include brand.ico,wizard-large.bmp,wizard-small.bmp -Recurse | ForEach-Object { Write-Host ("  {0}  ({1} bytes)" -f $_.Name,$_.Length) }
