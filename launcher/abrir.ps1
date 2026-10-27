# Abre Records Request Desk: enciende el servidor si hace falta y abre la app en su propia ventana.
# Lo usa el acceso directo del escritorio. Con -SoloServidor solo enciende el servidor (inicio automático).
param([switch]$SoloServidor)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$port = if ($env:RECORDS_PORT) { $env:RECORDS_PORT } else { 8501 }
$url = "http://localhost:$port/"
$appData = Join-Path $env:LOCALAPPDATA 'RecordsRequestDesk'

function Test-Server {
    # Conexión directa al puerto: instantánea y sin pasar por la configuración de proxy de Windows.
    $client = New-Object System.Net.Sockets.TcpClient
    try { $client.ConnectAsync('127.0.0.1', [int]$port).Wait(1500) -and $client.Connected }
    catch { $false }
    finally { $client.Dispose() }
}

function Open-AppWindow([string]$target) {
    # Edge en "modo app": ventana propia, sin pestañas ni barra de direcciones.
    try { Start-Process msedge -ArgumentList "--app=$target", '--window-size=1360,880' }
    catch { Start-Process $target }
}

function Show-Error([string]$message) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($message, 'Records Request Desk', 'OK', 'Warning') | Out-Null
}

if (Test-Server) {
    if (-not $SoloServidor) { Open-AppWindow $url }
    exit 0
}

$uv = (Get-Command uv -ErrorAction SilentlyContinue).Source
if (-not $uv) { $uv = Join-Path $env:USERPROFILE '.local\bin\uv.exe' }
if (-not (Test-Path $uv)) {
    Show-Error "Falta instalar 'uv' en esta PC (se hace una sola vez).`n`nLos pasos están en README.md, sección 'Instalar en la PC principal'."
    exit 1
}

# El entorno de Python vive en esta PC, fuera de Dropbox, para no sincronizar miles de archivos.
New-Item -ItemType Directory -Force $appData | Out-Null
$env:UV_PROJECT_ENVIRONMENT = Join-Path $appData 'venv'
$env:PYTHONDONTWRITEBYTECODE = '1'
$env:PYTHONUNBUFFERED = '1'  # que server.log muestre los mensajes al momento
Start-Process -FilePath $uv -ArgumentList 'run', '--quiet', 'python', 'server.py' `
    -WorkingDirectory $root -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $appData 'server.log') `
    -RedirectStandardError (Join-Path $appData 'server-errores.log')

if ($SoloServidor) { exit 0 }

# Pantalla de carga mientras arranca (la primera vez instala lo necesario y tarda un poco más).
$loading = (Join-Path $PSScriptRoot 'cargando.html') -replace '\\', '/'
Open-AppWindow "file:///$($loading)?port=$port"
