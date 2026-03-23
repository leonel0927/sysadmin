. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
verificar_instalacion -pak "GPMC"
Import-Module ActiveDirectory
Import-Module GroupPolicy

$dominio = "DC=practica,DC=local"
$dominioFQDN = "practica.local"
$gpoName = "Forzar-Cierre-Sesion"

function Crear-GPO-Logoff {
    if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
        New-GPO -Name $gpoName | Out-Null
        Write-Host "GPO creada: $gpoName"
    } else {
        Write-Host "GPO ya existe: $gpoName"
    }

    Set-GPRegistryValue -Name $gpoName `
        -Key "HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" `
        -ValueName "EnableForcedLogOff" `
        -Type DWord `
        -Value 1

    Write-Host "Configuracion de cierre forzado aplicada."

    foreach ($uo in @("Cuates", "NoCuates")) {
        try {
            New-GPLink -Name $gpoName -Target "OU=$uo,$dominio" -ErrorAction Stop | Out-Null
            Write-Host "GPO vinculada a OU: $uo"
        } catch {
            Write-Host "GPO ya estaba vinculada a: $uo"
        }
    }

    Write-Host "GPO configurada correctamente."
}

function Ver-GPO {
    Write-Host ""
    $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
    if ($gpo) {
        Write-Host "Nombre    : $($gpo.DisplayName)"
        Write-Host "Estado    : $($gpo.GpoStatus)"
        Write-Host "Creada    : $($gpo.CreationTime)"
        Write-Host "Modificada: $($gpo.ModificationTime)"
        Write-Host ""
        Write-Host "Links:"
        foreach ($uo in @("Cuates", "NoCuates")) {
            $link = Get-GPInheritance -Target "OU=$uo,$dominio" | 
                Select-Object -ExpandProperty GpoLinks | 
                Where-Object { $_.DisplayName -eq $gpoName }
            if ($link) {
                Write-Host "  OU=$uo -> Vinculada"
            } else {
                Write-Host "  OU=$uo -> No vinculada"
            }
        }
    } else {
        Write-Host "La GPO '$gpoName' no existe todavia."
    }
}

function Forzar-Actualizacion {
    Invoke-GPUpdate -Force
    Write-Host "GPUpdate forzado correctamente."
}

function Show-Menu-GPO {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        GPO - CIERRE DE SESION FORZADO"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  [1]  Crear y vincular GPO de cierre forzado"
    Write-Host "  [2]  Ver estado de la GPO"
    Write-Host "  [3]  Forzar actualizacion de politicas (gpupdate)"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-GPO
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Crear-GPO-Logoff }
        "2" { Ver-GPO }
        "3" { Forzar-Actualizacion }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")