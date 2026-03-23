$dominioFQDN = "practica.local"
$dominio = "DC=practica,DC=local"
$servidorIP = "192.168.117.11"
$csvPath = "Z:\windows\usuarios.csv"
$scriptsPath = "Z:\windows"

. "Z:\FUNCIONES\instalacion.ps1"

function Promover-DC {
    $adds = Get-WindowsFeature -Name AD-Domain-Services -ErrorAction SilentlyContinue
    if (-not $adds.Installed) {
        Write-Host "Instalando AD-Domain-Services..."
        Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    }

    $ntds = Get-Service -Name NTDS -ErrorAction SilentlyContinue
    if (-not $ntds) {
        Write-Host "El servidor no es Controlador de Dominio. Promoviendo..."
        Import-Module ADDSDeployment
        Install-ADDSForest `
            -DomainName "practica.local" `
            -DomainNetbiosName "PRACTICA" `
            -ForestMode "WinThreshold" `
            -DomainMode "WinThreshold" `
            -InstallDns:$true `
            -Force:$true
    }
}

$paquetes = @(
    "RSAT-AD-PowerShell",
    "RSAT-AD-AdminCenter",
    "RSAT-ADDS-Tools",
    "FS-Resource-Manager"
)

Write-Host "Verificando dependencias..."
Promover-DC
foreach ($pak in $paquetes) {
    verificar_instalacion -pak $pak
}

Import-Module ActiveDirectory

function Show-Menu {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        PRACTICA SYSADMIN - MENU PRINCIPAL"
    Write-Host "        Dominio: practica.local | IP: 192.168.117.11"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  [1]  Crear UOs, Grupos y Usuarios desde CSV"
    Write-Host "  [2]  Generar script para unir Windows 10 al dominio"
    Write-Host "  [3]  Generar script Bash para unir Linux Mint al dominio"
    Write-Host "  [4]  Configurar Horarios de Inicio de Sesion (LogonHours)"
    Write-Host "  [5]  Configurar GPO - Cierre de sesion forzado"
    Write-Host "  [6]  Instalar FSRM y configurar Cuotas de Disco"
    Write-Host "  [7]  Configurar Apantallamiento de Archivos (File Screening)"
    Write-Host "  [8]  Configurar AppLocker"
    Write-Host "  [9]  Verificar estado general"
    Write-Host "  [0]  Salir"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu
    $opcion = Read-Host "Selecciona una opcion"

    switch ($opcion) {
        "1" { & "$scriptsPath\01_Crear_Usuarios.ps1" }
        "2" { & "$scriptsPath\02_Unir_Windows.ps1" }
        "3" { & "$scriptsPath\03_Generar_Script_Linux.ps1" }
        "4" { & "$scriptsPath\04_LogonHours.ps1" }
        "5" { & "$scriptsPath\05_GPO_Logoff.ps1" }
        "6" { & "$scriptsPath\06_FSRM_Cuotas.ps1" }
        "7" { & "$scriptsPath\07_FileScreening.ps1" }
        "8" { & "$scriptsPath\08_AppLocker.ps1" }
        "9" { & "$scriptsPath\09_Verificar.ps1" }
        "0" { Write-Host "Saliendo..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($opcion -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para volver al menu"
    }

} while ($opcion -ne "0")