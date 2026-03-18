# ============================================================
#  practica7.ps1 -- Orquestador Principal Windows
#  Pr?ctica 7 -- SSL/TLS + FTP Din?mico + Integridad
# ============================================================

# Verificar que se ejecuta como Administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Ejecute este script como Administrador." -ForegroundColor Red
    exit 1
}

# Cargar funciones
$ScriptDir   = $PSScriptRoot
$httpFPath   = Join-Path $ScriptDir "httpF.ps1"
$ftpPath     = Join-Path $ScriptDir "ftp2.ps1"

if (-not (Test-Path $httpFPath)) {
    Write-Host "ERROR: No se encontro httpF.ps1 en $httpFPath" -ForegroundColor Red
    exit 1
}
. $httpFPath

# -- Variables globales ---------------------------------------
$SSL_DIR  = "C:\ssl"
$DOMAIN   = "www.reprobados.com"
$LOG_FILE = "C:\Temp\practica7_resumen.log"

if (-not (Test-Path "C:\Temp")) { New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $SSL_DIR))  { New-Item -Path $SSL_DIR  -ItemType Directory -Force | Out-Null }

# -- Verificaciones previas -----------------------------------
function Verificar-DotNet {
    $release = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" `
                -ErrorAction SilentlyContinue).Release
    if ($release -lt 528040) {
        Write-Host "--- ACTUALIZACION CRITICA: .NET 4.8 requerido ---" -ForegroundColor Red
        $out = "C:\dotnet48.exe"
        Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2088631" -OutFile $out
        Start-Process $out -ArgumentList "/passive /norestart" -Wait
        Write-Host "Reinicie el servidor: Restart-Computer -Force" -ForegroundColor Yellow
        exit 0
    }
}

function Verificar-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Instalando Chocolatey..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = `
            [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(
            'https://community.chocolatey.org/install.ps1'))
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + `
                    [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "Chocolatey instalado." -ForegroundColor Green
    }
}

function Limpiar-Configuracion-Previa {
    Stop-Process -Name nginx  -Force -ErrorAction SilentlyContinue
    Stop-Service  Apache2.4         -ErrorAction SilentlyContinue
    Stop-Service  W3SVC             -ErrorAction SilentlyContinue
    Get-NetFirewallRule -DisplayName "HTTP-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
}

function Mostrar-Puertos {
    Write-Host "`n--- Puertos TCP en escucha ---" -ForegroundColor Cyan
    Get-NetTCPConnection -State Listen |
        Where-Object { $_.LocalPort -gt 79 } |
        Sort-Object LocalPort |
        Format-Table -AutoSize LocalPort,
            @{N="Proceso";E={(Get-Process -Id $_.OwningProcess -EA SilentlyContinue).Name}},
            State
    Pause
}

# -- Instalaci?n WEB ------------------------------------------
function Instalar-Via-Web {
    Clear-Host
    Write-Host "--- Seleccione el servidor a instalar ---" -ForegroundColor Yellow
    Write-Host "1) IIS"
    Write-Host "2) Apache"
    Write-Host "3) Nginx"
    Write-Host "0) Volver"
    $tipo = Read-Host "Opcion"
    $tipo = $tipo -replace '[^0-9]', ''
    if ($tipo -eq "0") { return }

    $puerto = Leer-Puerto

    switch ($tipo) {
        "1" { Instalar-IIS    -Puerto $puerto }
        "2" { Instalar-Apache -PuertoGeneral $puerto }
        "3" { Instalar-Nginx  -Puerto $puerto }
        default { Write-Host "Opcion no valida." -ForegroundColor Red; Pause }
    }

    # Preguntar SSL
    $activarSSL = Read-Host "`n?Desea activar SSL/TLS en este servicio? [S/N]"
    if ($activarSSL -eq "S" -or $activarSSL -eq "s") {
        switch ($tipo) {
            "1" { Configurar-SSL-IIS }
            "2" { Configurar-SSL-Apache }
            "3" { Configurar-SSL-Nginx }
        }
    }
}

# -- SSL masivo -----------------------------------------------
function SSL-Masivo {
    Write-Host "`n============================================" -ForegroundColor Blue
    Write-Host "   SSL/TLS MASIVO -- todos los servicios" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Blue

    # IIS
    $iis = Get-WindowsFeature Web-Server -ErrorAction SilentlyContinue
    if ($iis.Installed) {
        $resp = Read-Host "?Activar SSL en IIS? [S/N]"
        if ($resp -eq "S" -or $resp -eq "s") { Configurar-SSL-IIS }
    } else { Write-Host "[OMITIDO] IIS no instalado." -ForegroundColor Yellow }

    # Apache
    $apacheRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -match "(?i)^apache" -and (Test-Path "$($_.FullName)\bin\httpd.exe") } |
                  Select-Object -First 1
    if ($apacheRoot) {
        $resp = Read-Host "?Activar SSL en Apache? [S/N]"
        if ($resp -eq "S" -or $resp -eq "s") { Configurar-SSL-Apache }
    } else { Write-Host "[OMITIDO] Apache no instalado." -ForegroundColor Yellow }

    # Nginx
    $nginxRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match "^nginx" -and (Test-Path "$($_.FullName)\nginx.exe") } |
                 Select-Object -First 1
    if ($nginxRoot) {
        $resp = Read-Host "?Activar SSL en Nginx? [S/N]"
        if ($resp -eq "S" -or $resp -eq "s") { Configurar-SSL-Nginx }
    } else { Write-Host "[OMITIDO] Nginx no instalado." -ForegroundColor Yellow }

    # IIS-FTP
    $ftpSite = Get-WebSite -Name "FTP" -ErrorAction SilentlyContinue
    if ($ftpSite) {
        $resp = Read-Host "?Activar FTPS en IIS-FTP? [S/N]"
        if ($resp -eq "S" -or $resp -eq "s") { Configurar-FTPS-IIS }
    } else { Write-Host "[OMITIDO] IIS-FTP no instalado." -ForegroundColor Yellow }

    Pause
}

# -- SSL espec?fico -------------------------------------------
function SSL-Especifico {
    Write-Host "`n--- SSL Servicio Especifico ---" -ForegroundColor Cyan
    Write-Host "1) IIS"
    Write-Host "2) Apache"
    Write-Host "3) Nginx"
    Write-Host "4) IIS-FTP (FTPS)"
    $s = Read-Host "Servicio"
    switch ($s) {
        "1" { Configurar-SSL-IIS }
        "2" { Configurar-SSL-Apache }
        "3" { Configurar-SSL-Nginx }
        "4" { Configurar-FTPS-IIS }
        default { Write-Host "Invalido." -ForegroundColor Red }
    }
    Pause
}

# -- Inicializaci?n -------------------------------------------
Verificar-DotNet
Verificar-Chocolatey
Limpiar-Configuracion-Previa

# -- Men? principal -------------------------------------------
while ($true) {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "   PRACTICA 7 -- Orquestador Windows       " -ForegroundColor White
    Write-Host "   SSL/TLS + FTP Dinamico + Integridad    " -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "1) Instalar servicio via WEB"
    Write-Host "2) Instalar servicio via FTP  (repositorio privado)"
    Write-Host "3) Activar SSL/TLS en todos los servicios"
    Write-Host "4) Activar SSL/TLS en un servicio especifico"
    Write-Host "5) Ver puertos activos"
    Write-Host "6) Resumen y verificacion automatica"
    Write-Host "7) Salir"
    Write-Host "------------------------------------------"

    $opc = Read-Host "Seleccione una opcion"
    $opc = $opc -replace '[^0-9]', ''

    switch ($opc) {
        "1" { Instalar-Via-Web }
        "2" {
            # FTP -> llama directamente al ftp.ps1
            if (Test-Path $ftpPath) {
                & powershell.exe -ExecutionPolicy Bypass -File $ftpPath
            } else {
                Write-Host "ERROR: No se encontro ftp.ps1 en $ftpPath" -ForegroundColor Red
                Pause
            }
        }
        "3" { SSL-Masivo }
        "4" { SSL-Especifico }
        "5" { Mostrar-Puertos }
        "6" { Mostrar-Resumen-SSL }
        "7" {
            Write-Host "Saliendo..." -ForegroundColor Cyan
            exit 0
        }
        default {
            Write-Host "Opcion no reconocida." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}