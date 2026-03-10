
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Ejecute este script como Administrador." -ForegroundColor Red
    exit 1
}

$FuncionesPath = Join-Path $PSScriptRoot "httpF.ps1"
if (-not (Test-Path $FuncionesPath)) {
    Write-Host "ERROR: No se encontro httpF.ps1 en: $FuncionesPath" -ForegroundColor Red
    exit 1
}
. $FuncionesPath
function Verificar-DotNet {
    $release = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" `
                -ErrorAction SilentlyContinue).Release
    if ($release -lt 528040) {
        Write-Host "--- ACTUALIZACION CRITICA: .NET 4.8 requerido ---" -ForegroundColor Red
        Write-Host "Descargando e instalando .NET 4.8... Por favor espere."
        $out = "C:\dotnet48.exe"
        Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2088631" -OutFile $out
        Start-Process $out -ArgumentList "/passive /norestart" -Wait
        Write-Host "Instalacion completada." -ForegroundColor Green
        Write-Host "REINICIE EL SERVIDOR y vuelva a ejecutar: Restart-Computer -Force" -ForegroundColor Yellow
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
        Write-Host "Chocolatey instalado correctamente." -ForegroundColor Green
    }
}
function Limpiar-Configuracion-Previa {
    Write-Host "`nVerificando y limpiando residuos de configuraciones previas..." -ForegroundColor Cyan

    Stop-Process -Name nginx   -Force -ErrorAction SilentlyContinue
    Stop-Service  Apache2.4          -ErrorAction SilentlyContinue
    Stop-Service  W3SVC              -ErrorAction SilentlyContinue

    Get-NetFirewallRule -DisplayName "HTTP-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule

    $rutasHTML = @(
        "C:\tools\nginx\html\index.html",
        "C:\tools\apache24\htdocs\index.html",
        "C:\inetpub\wwwroot\index.html"
    )
    foreach ($ruta in $rutasHTML) {
        if (Test-Path $ruta) {
            Remove-Item $ruta -Force
            Write-Host "  Eliminado: $ruta" -ForegroundColor Yellow
        }
    }
    Write-Host "Limpieza completada.`n" -ForegroundColor Green
}

function Leer-Puerto {
    do {
        $input = Read-Host "Ingrese el puerto de escucha (ej. 8080, 8888, 9000)"
        $input = $input -replace '[^0-9]', ''

        if ([string]::IsNullOrWhiteSpace($input)) {
            Write-Host "ERROR: Ingrese un numero de puerto valido." -ForegroundColor Red
            continue
        }

        $puerto = [int]$input
        $valido = Validar-Puerto -Puerto $puerto

    } while (-not $valido)

    return $puerto
}

function Mostrar-Puertos {
    Write-Host "`n--- Puertos TCP en escucha (>79) ---" -ForegroundColor Cyan
    Get-NetTCPConnection -State Listen |
        Where-Object { $_.LocalPort -gt 79 } |
        Sort-Object LocalPort |
        Format-Table -AutoSize LocalPort,
            @{N="Proceso";E={(Get-Process -Id $_.OwningProcess -EA SilentlyContinue).Name}},
            State
    Pause
}
Verificar-DotNet
Verificar-Chocolatey
Limpiar-Configuracion-Previa

while ($true) {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "    SISTEMA DE APROVISIONAMIENTO WEB      " -ForegroundColor White
    Write-Host "    Windows Server 2019 - Practica 6      " -ForegroundColor Gray
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host " 1. Instalar / Configurar Servidor HTTP"
    Write-Host " 2. Ver Puertos Activos"
    Write-Host " 3. Salir"
    Write-Host "------------------------------------------"

    $opc = Read-Host "Seleccione una opcion"
    $opc = $opc -replace '[^0-9]', ''  

    switch ($opc) {

        "1" {
            Clear-Host
            Write-Host "--- Seleccione el servidor a instalar ---" -ForegroundColor Yellow
            Write-Host " 1. IIS (Internet Information Services)  [Instalacion obligatoria]"
            Write-Host " 2. Apache HTTP Server (Win64 via Choco)"
            Write-Host " 3. Nginx para Windows (via Choco)"
            Write-Host " 0. Volver"

            $tipo = Read-Host "Opcion"
            $tipo = $tipo -replace '[^0-9]', ''

            if ($tipo -eq "0") { continue }

            $puerto = Leer-Puerto

            switch ($tipo) {
                "1" { Instalar-IIS    -Puerto $puerto }
                "2" { Instalar-Apache -Puerto $puerto }
                "3" { Instalar-Nginx  -Puerto $puerto }
                default { Write-Host "Opcion no valida." -ForegroundColor Red; Pause }
            }
        }

        "2" { Mostrar-Puertos }

        "3" {
            Write-Host "Saliendo del sistema de aprovisionamiento. Hasta luego." -ForegroundColor Cyan
            exit 0
        }

        default {
            Write-Host "Opcion no reconocida. Intente de nuevo." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}