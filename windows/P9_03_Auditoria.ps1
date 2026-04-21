. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
Import-Module ActiveDirectory

$reportePath = "Z:\windows\reporte_auditoria.txt"

function Habilitar-Auditoria {
    # Usar /category:* para habilitar todo de una vez
    auditpol /set /category:* /success:enable /failure:enable | Out-Null
    Write-Host "Auditoria habilitada para todas las categorias."

    # Verificar inicio de sesion especificamente
    auditpol /set /subcategory:"{0CCE9215-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable | Out-Null
    auditpol /set /subcategory:"{0CCE9216-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable | Out-Null
    auditpol /set /subcategory:"{0CCE9217-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable | Out-Null
    Write-Host "Auditoria de inicio/cierre de sesion habilitada."
    Write-Host "Auditoria configurada correctamente."
}

function Ver-Auditoria {
    Write-Host ""
    auditpol /get /category:*
}

function Generar-Reporte {
    Write-Host "Extrayendo ultimos 10 eventos de acceso denegado (ID 4625)..."

    $eventos = Get-WinEvent -FilterHashtable @{
        LogName   = "Security"
        Id        = 4625
    } -MaxEvents 10 -ErrorAction SilentlyContinue

    if (-not $eventos) {
        Write-Host "No se encontraron eventos de acceso denegado."
        return
    }

    $lineas = @()
    $lineas += "REPORTE DE ACCESOS DENEGADOS"
    $lineas += "Generado: $(Get-Date)"
    $lineas += "Total eventos: $($eventos.Count)"
    $lineas += "=" * 60

    foreach ($e in $eventos) {
        $xml = [xml]$e.ToXml()
        $data = $xml.Event.EventData.Data

        $usuario = ($data | Where-Object { $_.Name -eq "TargetUserName" })."#text"
        $dominio = ($data | Where-Object { $_.Name -eq "TargetDomainName" })."#text"
        $ip      = ($data | Where-Object { $_.Name -eq "IpAddress" })."#text"
        $razon   = ($data | Where-Object { $_.Name -eq "FailureReason" })."#text"
        $estado  = ($data | Where-Object { $_.Name -eq "Status" })."#text"

        $lineas += ""
        $lineas += "Fecha     : $($e.TimeCreated)"
        $lineas += "Usuario   : $usuario@$dominio"
        $lineas += "IP origen : $ip"
        $lineas += "Razon     : $razon"
        $lineas += "Estado    : $estado"
        $lineas += "-" * 40
    }

    $lineas | Out-File -FilePath $reportePath -Encoding UTF8
    Write-Host "Reporte generado en: $reportePath"
}

function Ver-Reporte {
    if (Test-Path $reportePath) {
        Get-Content $reportePath
    } else {
        Write-Host "No existe reporte. Ejecuta la opcion 3 primero."
    }
}

function Show-Menu-Auditoria {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        AUDITORIA DE EVENTOS Y HARDENING"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  [1]  Habilitar auditoria de exito y fallo"
    Write-Host "  [2]  Ver estado actual de auditoria"
    Write-Host "  [3]  Generar reporte de accesos denegados (ID 4625)"
    Write-Host "  [4]  Ver ultimo reporte generado"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-Auditoria
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Habilitar-Auditoria }
        "2" { Ver-Auditoria }
        "3" { Generar-Reporte }
        "4" { Ver-Reporte }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")