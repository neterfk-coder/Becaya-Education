# ============================================================
# generar_iconos.ps1 — el icono de becaya, en todos los tamaños
# ------------------------------------------------------------
# La marca NO se inventa aquí: es la misma del favicon del sitio
# (index.html), un cuadrado morado con una "b" blanca. Este script
# solo la reproduce en las medidas que piden Android e iOS.
#
# Los PNG son generados: no se editan a mano. Si hay que cambiar
# algo de la marca, se cambia acá arriba y se vuelve a correr:
#
#   powershell -ExecutionPolicy Bypass -File tool/generar_iconos.ps1
#
# Usa GDI+ y la fuente Arial Black, así que hoy solo corre en
# Windows. El SVG que deja en tool/becaya-marca.svg lleva la letra
# ya convertida a curvas, sin depender de ninguna fuente: ese es el
# maestro portable si algún día hay que regenerar esto en otra
# máquina o con otra herramienta.
# ============================================================

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$raiz = Split-Path -Parent $PSScriptRoot

# ---------- La marca ----------

# Morado de marca (--morado-500) a --morado-600. A 48 px se ve plano;
# el degradado solo se nota en el icono grande de la tienda.
$moradoArriba = [System.Drawing.Color]::FromArgb(0x7C, 0x3A, 0xED)
$moradoAbajo  = [System.Drawing.Color]::FromArgb(0x6D, 0x28, 0xD9)

$letra = 'b'
$fuente = 'Arial Black'

# Radio de esquina: 24/100, igual que el rx del favicon del sitio.
$radioFrac = 0.24

# Alto de la letra respecto del lado visible del icono. El favicon usa
# ~0.44; se sube un pelo porque un icono de lanzador se ve de lejos.
$letraFrac = 0.46

# ---------- Dibujo ----------

function Get-TrazoLetra {
    param([double]$Lado, [double]$FraccionVisible)

    $trazo = New-Object System.Drawing.Drawing2D.GraphicsPath
    $familia = New-Object System.Drawing.FontFamily($fuente)
    $trazo.AddString(
        $letra, $familia, [int][System.Drawing.FontStyle]::Regular, 100.0,
        (New-Object System.Drawing.PointF(0, 0)),
        [System.Drawing.StringFormat]::GenericTypographic)
    $familia.Dispose()

    # El alto se mide sobre la TINTA real de la letra, no sobre la caja
    # de la fuente: así la "b" queda ópticamente centrada y del mismo
    # tamaño aunque se cambie de tipografía.
    $caja = $trazo.GetBounds()
    $altoDestino = $Lado * $FraccionVisible * $letraFrac
    $escala = $altoDestino / $caja.Height

    $centro = $Lado / 2.0
    $m = New-Object System.Drawing.Drawing2D.Matrix
    $m.Scale($escala, $escala, [System.Drawing.Drawing2D.MatrixOrder]::Append)
    $m.Translate(
        $centro - ($caja.X + $caja.Width / 2.0) * $escala,
        $centro - ($caja.Y + $caja.Height / 2.0) * $escala,
        [System.Drawing.Drawing2D.MatrixOrder]::Append)
    $trazo.Transform($m)
    $m.Dispose()

    return $trazo
}

function New-Icono {
    param(
        [int]$Lado,
        [string]$Ruta,
        # Sin fondo: solo la letra blanca sobre transparente. Es lo que
        # pide la capa "foreground" del icono adaptativo de Android.
        [switch]$SoloLetra,
        # iOS enmascara las esquinas por su cuenta y rechaza el canal
        # alfa, así que allí el fondo va cuadrado y opaco.
        [switch]$Cuadrado,
        [double]$FraccionVisible = 1.0
    )

    $bmp = New-Object System.Drawing.Bitmap($Lado, $Lado, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    if (-not $SoloLetra) {
        $brocha = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.PointF(0, 0)),
            (New-Object System.Drawing.PointF(0, $Lado)),
            $moradoArriba, $moradoAbajo)

        if ($Cuadrado) {
            $g.FillRectangle($brocha, 0, 0, $Lado, $Lado)
        } else {
            $r = $Lado * $radioFrac
            $d = $r * 2
            $fondo = New-Object System.Drawing.Drawing2D.GraphicsPath
            $fondo.AddArc(0, 0, $d, $d, 180, 90)
            $fondo.AddArc($Lado - $d, 0, $d, $d, 270, 90)
            $fondo.AddArc($Lado - $d, $Lado - $d, $d, $d, 0, 90)
            $fondo.AddArc(0, $Lado - $d, $d, $d, 90, 90)
            $fondo.CloseFigure()
            $g.FillPath($brocha, $fondo)
            $fondo.Dispose()
        }
        $brocha.Dispose()
    }

    $trazo = Get-TrazoLetra -Lado $Lado -FraccionVisible $FraccionVisible
    $g.FillPath([System.Drawing.Brushes]::White, $trazo)
    $trazo.Dispose()

    $destino = Join-Path $raiz $Ruta
    $carpeta = Split-Path -Parent $destino
    if (-not (Test-Path $carpeta)) { New-Item -ItemType Directory -Force $carpeta | Out-Null }

    if ($Cuadrado) {
        # Aplanado sobre opaco: un PNG con alfa hace que App Store
        # rechace el envío.
        $plano = New-Object System.Drawing.Bitmap($Lado, $Lado, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $g2 = [System.Drawing.Graphics]::FromImage($plano)
        $g2.DrawImage($bmp, 0, 0, $Lado, $Lado)
        $plano.Save($destino, [System.Drawing.Imaging.ImageFormat]::Png)
        $g2.Dispose(); $plano.Dispose()
    } else {
        $bmp.Save($destino, [System.Drawing.Imaging.ImageFormat]::Png)
    }

    $g.Dispose(); $bmp.Dispose()
    Write-Host ("  {0,-62} {1}x{1}" -f $Ruta, $Lado)
}

# ---------- Android ----------

# Densidades: 1 dp = 1, 1.5, 2, 3 y 4 px.
$densidades = @(
    @{ carpeta = 'mdpi';    factor = 1.0 },
    @{ carpeta = 'hdpi';    factor = 1.5 },
    @{ carpeta = 'xhdpi';   factor = 2.0 },
    @{ carpeta = 'xxhdpi';  factor = 3.0 },
    @{ carpeta = 'xxxhdpi'; factor = 4.0 }
)

Write-Host "`nAndroid — icono clásico (48 dp):"
foreach ($d in $densidades) {
    New-Icono -Lado ([int](48 * $d.factor)) `
        -Ruta "android/app/src/main/res/mipmap-$($d.carpeta)/ic_launcher.png"
}

Write-Host "`nAndroid — capa frontal del icono adaptativo (108 dp):"
foreach ($d in $densidades) {
    # El lienzo adaptativo mide 108 dp pero el sistema solo muestra los
    # 72 dp centrales: el resto se recorta según la forma que use cada
    # lanzador. Por eso la letra se dimensiona contra 72/108, para que
    # se vea del mismo tamaño que en el icono clásico.
    New-Icono -Lado ([int](108 * $d.factor)) `
        -Ruta "android/app/src/main/res/mipmap-$($d.carpeta)/ic_launcher_foreground.png" `
        -SoloLetra -FraccionVisible (72.0 / 108.0)
}

# ---------- iOS ----------

$ios = @(
    @{ archivo = 'Icon-App-20x20@1x.png';     lado = 20 },
    @{ archivo = 'Icon-App-20x20@2x.png';     lado = 40 },
    @{ archivo = 'Icon-App-20x20@3x.png';     lado = 60 },
    @{ archivo = 'Icon-App-29x29@1x.png';     lado = 29 },
    @{ archivo = 'Icon-App-29x29@2x.png';     lado = 58 },
    @{ archivo = 'Icon-App-29x29@3x.png';     lado = 87 },
    @{ archivo = 'Icon-App-40x40@1x.png';     lado = 40 },
    @{ archivo = 'Icon-App-40x40@2x.png';     lado = 80 },
    @{ archivo = 'Icon-App-40x40@3x.png';     lado = 120 },
    @{ archivo = 'Icon-App-60x60@2x.png';     lado = 120 },
    @{ archivo = 'Icon-App-60x60@3x.png';     lado = 180 },
    @{ archivo = 'Icon-App-76x76@1x.png';     lado = 76 },
    @{ archivo = 'Icon-App-76x76@2x.png';     lado = 152 },
    @{ archivo = 'Icon-App-83.5x83.5@2x.png'; lado = 167 },
    @{ archivo = 'Icon-App-1024x1024@1x.png'; lado = 1024 }
)

Write-Host "`niOS — AppIcon:"
foreach ($i in $ios) {
    New-Icono -Lado $i.lado -Cuadrado `
        -Ruta "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($i.archivo)"
}

# ---------- Maestro portable ----------

# La letra, ya convertida a curvas. Sirve para regenerar todo esto sin
# Windows y sin Arial Black instalada.
function Export-Svg {
    param([string]$Ruta)

    $lado = 512.0
    $trazo = Get-TrazoLetra -Lado $lado -FraccionVisible 1.0
    $puntos = $trazo.PathPoints
    $tipos = $trazo.PathTypes

    $d = New-Object System.Text.StringBuilder
    $i = 0
    while ($i -lt $puntos.Length) {
        $tipo = $tipos[$i] -band 0x07
        $p = $puntos[$i]
        switch ($tipo) {
            0 { [void]$d.AppendFormat([cultureinfo]::InvariantCulture, "M{0:0.##} {1:0.##} ", $p.X, $p.Y); $i++ }
            1 { [void]$d.AppendFormat([cultureinfo]::InvariantCulture, "L{0:0.##} {1:0.##} ", $p.X, $p.Y); $i++ }
            3 {
                $c1 = $puntos[$i]; $c2 = $puntos[$i + 1]; $fin = $puntos[$i + 2]
                [void]$d.AppendFormat([cultureinfo]::InvariantCulture, "C{0:0.##} {1:0.##} {2:0.##} {3:0.##} {4:0.##} {5:0.##} ",
                    $c1.X, $c1.Y, $c2.X, $c2.Y, $fin.X, $fin.Y)
                $i += 3
            }
            default { $i++ }
        }
        if ($tipos[$i - 1] -band 0x80) { [void]$d.Append("Z ") }
    }
    $trazo.Dispose()

    $r = [int]($lado * $radioFrac)
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <!-- becaya — marca de la app. Generado por tool/generar_iconos.ps1.
       La letra va como curvas, no como texto: se ve igual sin tener
       Arial Black instalada. -->
  <defs>
    <linearGradient id="morado" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#7C3AED"/>
      <stop offset="1" stop-color="#6D28D9"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="$r" fill="url(#morado)"/>
  <path fill="#FFFFFF" d="$($d.ToString().Trim())"/>
</svg>
"@

    $destino = Join-Path $raiz $Ruta
    [IO.File]::WriteAllText($destino, $svg, (New-Object Text.UTF8Encoding($false)))
    Write-Host ("  {0,-62} vector" -f $Ruta)
}

# ---------- Google Play ----------

# La ficha de la tienda pide exactamente 512x512, con esquinas cuadradas:
# Play aplica su propia máscara, igual que iOS. Ver docs/publicar.md.
Write-Host "`nGoogle Play — icono de la ficha:"
New-Icono -Lado 512 -Cuadrado -Ruta 'tool/play-icono-512.png'

Write-Host "`nMaestro vectorial:"
Export-Svg -Ruta 'tool/becaya-marca.svg'

Write-Host "`nListo.`n"
