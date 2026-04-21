. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
verificar_instalacion -pak "GPMC"
Import-Module ActiveDirectory
Import-Module GroupPolicy

$dominio = "DC=practica,DC=local"
$gpoName = "Politica-Bloqueo-Cuenta"

function Configurar-Bloqueo {
    if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
        New-GPO -Name $gpoName | Out-Null
        Write-Host "GPO creada: $gpoName"
    } else {
        Write-Host "GPO ya existe: $gpoName"
    }

    # Umbral de bloqueo: 3 intentos fallidos
    Set-GPRegistryValue -Name $gpoName `
        -Key "HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" `
        -ValueName "MaximumPasswordAge" `
        -Type DWord -Value 3 | Out-Null

    # Configurar via Fine-Grained Password Policy (mas confiable)
    foreach ($pso in @("PSO-Admins", "PSO-Usuarios")) {
        if (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq '$pso'" -ErrorAction SilentlyContinue) {
            Set-ADFineGrainedPasswordPolicy -Identity $pso `
                -LockoutThreshold 3 `
                -LockoutDuration "00:30:00" `
                -LockoutObservationWindow "00:30:00"
            Write-Host "Bloqueo actualizado en $pso : 3 intentos / 30 minutos"
        }
    }

    # Vincular GPO al dominio
    try {
        New-GPLink -Name $gpoName -Target $dominio -ErrorAction Stop | Out-Null
        Write-Host "GPO vinculada al dominio"
    } catch {
        Write-Host "GPO ya vinculada al dominio"
    }

    Write-Host "Bloqueo de cuenta configurado correctamente."
}

function Ver-Bloqueo {
    Write-Host ""
    Write-Host "Politicas FGPP de bloqueo:"
    Get-ADFineGrainedPasswordPolicy -Filter * |
        Select-Object Name, LockoutThreshold, LockoutDuration, LockoutObservationWindow |
        Format-Table -AutoSize
}

function Ver-CuentasBloqueadas {
    Write-Host ""
    $bloqueadas = Search-ADAccount -LockedOut
    if ($bloqueadas) {
        $bloqueadas | Select-Object SamAccountName, Name, LockedOut, LastLogonDate | Format-Table -AutoSize
    } else {
        Write-Host "No hay cuentas bloqueadas actualmente."
    }
}

function Desbloquear-Cuenta {
    $usuario = Read-Host "Usuario a desbloquear"
    try {
        Unlock-ADAccount -Identity $usuario
        Write-Host "Cuenta desbloqueada: $usuario"
    } catch {
        Write-Host "Error al desbloquear: $_"
    }
}

function Show-Menu-Bloqueo {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        BLOQUEO DE CUENTA POR INTENTOS FALLIDOS"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  Umbral  : 3 intentos fallidos"
    Write-Host "  Bloqueo : 30 minutos"
    Write-Host ""
    Write-Host "  [1]  Configurar bloqueo automatico"
    Write-Host "  [2]  Ver politicas de bloqueo"
    Write-Host "  [3]  Ver cuentas bloqueadas"
    Write-Host "  [4]  Desbloquear cuenta"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-Bloqueo
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Configurar-Bloqueo }
        "2" { Ver-Bloqueo }
        "3" { Ver-CuentasBloqueadas }
        "4" { Desbloquear-Cuenta }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")