$dominioFQDN = "practica.local"
$dominio = "DC=practica,DC=local"
$servidorIP = "192.168.117.11"
$scriptsPath = "Z:\windows"

. "Z:\FUNCIONES\instalacion.ps1"

$paquetes = @(
    "RSAT-AD-PowerShell",
    "RSAT-AD-AdminCenter",
    "RSAT-ADDS-Tools",
    "GPMC"
)

Write-Host "Verificando dependencias..."
foreach ($pak in $paquetes) {
    verificar_instalacion -pak $pak
}

Import-Module ActiveDirectory
Import-Module GroupPolicy

function Show-Menu {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        PRACTICA 9 - HARDENING AD + MFA"
    Write-Host "        Dominio: practica.local | IP: 192.168.117.11"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  [1]  Crear usuarios admin delegados y configurar RBAC"
    Write-Host "  [2]  Configurar Fine-Grained Password Policy (FGPP)"
    Write-Host "  [3]  Hardening de auditoria y script de monitoreo"
    Write-Host "  [4]  Configurar MFA (Google Authenticator / TOTP)"
    Write-Host "  [5]  Configurar bloqueo por intentos fallidos de MFA"
    Write-Host "  [6]  Verificar estado general"
    Write-Host "  [0]  Salir"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu
    $opcion = Read-Host "Selecciona una opcion"

    switch ($opcion) {
        "1" { & "$scriptsPath\P9_01_RBAC.ps1" }
        "2" { & "$scriptsPath\P9_02_FGPP.ps1" }
        "3" { & "$scriptsPath\P9_03_Auditoria.ps1" }
        "4" { & "$scriptsPath\P9_04_MFA.ps1" }
        "5" { & "$scriptsPath\P9_05_Bloqueo_MFA.ps1" }
        "6" { & "$scriptsPath\P9_06_Verificar.ps1" }
        "0" { Write-Host "Saliendo..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($opcion -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para volver al menu"
    }

} while ($opcion -ne "0")