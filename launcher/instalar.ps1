# Crea el acceso directo "Records Request Desk" en el escritorio.
#   Principal: esta PC tiene la app (enciende el servidor y abre la ventana).
#   Equipo:    esta PC se conecta a la app de la PC principal (no instala nada).
param(
    [ValidateSet('Principal', 'Equipo')][string]$Modo,
    [string]$Direccion,
    [switch]$Autoinicio,
    [string]$Destino = [Environment]::GetFolderPath('Desktop')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$icon = Join-Path $PSScriptRoot 'icon.ico'
$name = 'Records Request Desk'
$shell = New-Object -ComObject WScript.Shell

function Find-Edge {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe'
    $path = (Get-ItemProperty $key -ErrorAction SilentlyContinue).'(default)'
    if (-not $path) { $path = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe" }
    if (Test-Path $path) { return $path }
    return $null
}

function New-Shortcut([string]$path, [string]$target, [string]$arguments) {
    $lnk = $shell.CreateShortcut($path)
    $lnk.TargetPath = $target
    $lnk.Arguments = $arguments
    $lnk.WorkingDirectory = $root
    $lnk.IconLocation = "$icon,0"
    $lnk.Description = 'Solicitudes de utility records paso a paso'
    $lnk.WindowStyle = 7  # minimizada: evita que se vea la consola
    $lnk.Save()
}

Write-Host ''
Write-Host "  $name - crear acceso directo" -ForegroundColor DarkYellow
Write-Host ''

if (-not $Modo) {
    Write-Host '  1) Esta PC tiene la app (la PC principal de la oficina, o tu PC para probar)'
    Write-Host '  2) Me conecto a la app que corre en la PC de la oficina'
    Write-Host ''
    $Modo = if ((Read-Host '  Elige 1 o 2') -eq '2') { 'Equipo' } else { 'Principal' }
}

$lnkPath = Join-Path $Destino "$name.lnk"
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$launcher = Join-Path $PSScriptRoot 'abrir.ps1'

if ($Modo -eq 'Principal') {
    New-Shortcut $lnkPath $powershell "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$launcher`""

    if (-not $PSBoundParameters.ContainsKey('Autoinicio')) {
        $Autoinicio = (Read-Host '  ¿Encender la app sola cada vez que se prende esta PC? (S/N)') -match '^[sS]'
    }
    if ($Autoinicio) {
        $startup = [Environment]::GetFolderPath('Startup')
        New-Shortcut (Join-Path $startup "$name (servidor).lnk") $powershell `
            "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$launcher`" -SoloServidor"
        Write-Host '  Listo: la app se encenderá sola al iniciar Windows.' -ForegroundColor Green
    }
}
else {
    if (-not $Direccion) {
        $saved = Join-Path $root 'data\servidor.txt'
        $default = if (Test-Path $saved) { (Get-Content $saved -TotalCount 1).Trim() } else { '' }
        $answer = Read-Host "  Dirección de la app [$default]"
        $Direccion = if ($answer) { $answer } else { $default }
    }
    if (-not $Direccion) {
        Write-Host '  Necesito la dirección, por ejemplo http://PC-OFICINA:8501' -ForegroundColor Red
        exit 1
    }
    if ($Direccion -notmatch '^https?://') { $Direccion = "http://$Direccion" }

    $edge = Find-Edge
    if ($edge) {
        New-Shortcut $lnkPath $edge "--app=$Direccion --window-size=1360,880"
    }
    else {
        # Sin Edge: acceso directo de internet que abre el navegador predeterminado.
        $lnkPath = Join-Path $Destino "$name.url"
        Set-Content -Path $lnkPath -Encoding ASCII -Value "[InternetShortcut]`r`nURL=$Direccion`r`nIconFile=$icon`r`nIconIndex=0"
    }
}

Write-Host ''
Write-Host "  Listo: '$name' quedó en tu escritorio. Ábrelo con doble clic." -ForegroundColor Green
Write-Host ''
