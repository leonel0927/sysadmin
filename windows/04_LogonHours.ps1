. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
Import-Module ActiveDirectory

function Get-LogonHoursBytes {
    param([int[]]$horasPermitidas)
    $bytes = New-Object byte[] 21
    foreach ($hora in $horasPermitidas) {
        for ($dia = 0; $dia -lt 7; $dia++) {
            $bitPos  = $dia * 24 + $hora
            $byteIdx = [math]::Floor($bitPos / 8)
            $bitIdx  = $bitPos % 8
            $bytes[$byteIdx] = $bytes[$byteIdx] -bor (1 -shl $bitIdx)
        }
    }
    return $bytes
}

function Set-LogonHoursADSI {
    param(
        [string]$SamAccountName,
        [byte[]]$Bytes
    )
    $user = Get-ADUser -Identity $SamAccountName
    $adsiUser = [ADSI]"LDAP://$($user.DistinguishedName)"
    $adsiUser.Put("logonHours", $Bytes)
    $adsiUser.SetInfo()
}

function Aplicar-LogonHours {
    $bytesCuates   = Get-LogonHoursBytes -horasPermitidas (8..14)
    $bytesNoCuates = Get-LogonHoursBytes -horasPermitidas @(15,16,17,18,19,20,21,22,23,0,1)

    $usuariosCuates = Get-ADGroupMember -Identity "Cuates" | Where-Object { $_.objectClass -eq "user" }
    foreach ($u in $usuariosCuates) {
        Set-LogonHoursADSI -SamAccountName $u.SamAccountName -Bytes $bytesCuates
        Write-Host "LogonHours Cuates (8AM-3PM) aplicado a: $($u.SamAccountName)"
    }

    $usuariosNoCuates = Get-ADGroupMember -Identity "NoCuates" | Where-Object { $_.objectClass -eq "user" }
    foreach ($u in $usuariosNoCuates) {
        Set-LogonHoursADSI -SamAccountName $u.SamAccountName -Bytes $bytesNoCuates
        Write-Host "LogonHours NoCuates (3PM-2AM) aplicado a: $($u.SamAccountName)"
    }

    Write-Host "LogonHours configurados correctamente."
}

function Ver-LogonHours {
    Write-Host ""
    Write-Host "Grupo Cuates (8:00 AM - 3:00 PM):"
    Get-ADGroupMember -Identity "Cuates" | Where-Object { $_.objectClass -eq "user" } |
        ForEach-Object {
            $u = Get-ADUser -Identity $_.SamAccountName -Properties logonHours
            $tiene = if ($u.logonHours) { "Configurado" } else { "Sin configurar" }
            Write-Host "  $($u.SamAccountName) -> $tiene"
        }

    Write-Host ""
    Write-Host "Grupo NoCuates (3:00 PM - 2:00 AM):"
    Get-ADGroupMember -Identity "NoCuates" | Where-Object { $_.objectClass -eq "user" } |
        ForEach-Object {
            $u = Get-ADUser -Identity $_.SamAccountName -Properties logonHours
            $tiene = if ($u.logonHours) { "Configurado" } else { "Sin configurar" }
            Write-Host "  $($u.SamAccountName) -> $tiene"
        }
}

function Show-Menu-LogonHours {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        CONFIGURACION DE HORARIOS DE SESION"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  Cuates   : 8:00 AM - 3:00 PM"
    Write-Host "  NoCuates : 3:00 PM - 2:00 AM"
    Write-Host ""
    Write-Host "  [1]  Aplicar LogonHours a todos los usuarios"
    Write-Host "  [2]  Ver estado de LogonHours"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-LogonHours
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Aplicar-LogonHours }
        "2" { Ver-LogonHours }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")