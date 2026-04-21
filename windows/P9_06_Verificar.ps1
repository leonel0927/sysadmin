. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
Import-Module ActiveDirectory

$dominio = "DC=practica,DC=local"

function Ver-UsuariosAdmin {
    Write-Host ""
    Write-Host "--- Usuarios Admin Delegados ---"
    Get-ADUser -Filter * -SearchBase "OU=Admins,$dominio" -Properties Enabled, PasswordLastSet |
        Select-Object SamAccountName, Name, Enabled, PasswordLastSet |
        Format-Table -AutoSize
}

function Ver-RBAC {
    Write-Host ""
    Write-Host "--- ACLs en OU Cuates ---"
    $acl = Get-Acl "AD:OU=Cuates,$dominio"
    $acl.Access | Where-Object { $_.IdentityReference -like "*admin*" } |
        Select-Object IdentityReference, ActiveDirectoryRights, AccessControlType |
        Format-Table -AutoSize

    Write-Host "--- ACLs en OU NoCuates ---"
    $acl = Get-Acl "AD:OU=NoCuates,$dominio"
    $acl.Access | Where-Object { $_.IdentityReference -like "*admin*" } |
        Select-Object IdentityReference, ActiveDirectoryRights, AccessControlType |
        Format-Table -AutoSize
}

function Ver-FGPP {
    Write-Host ""
    Write-Host "--- Fine-Grained Password Policies ---"
    Get-ADFineGrainedPasswordPolicy -Filter * |
        Select-Object Name, Precedence, MinPasswordLength, LockoutThreshold, LockoutDuration |
        Format-Table -AutoSize

    Write-Host "--- Sujetos por PSO ---"
    foreach ($pso in @("PSO-Admins","PSO-Usuarios")) {
        $sujetos = Get-ADFineGrainedPasswordPolicySubject -Identity $pso -ErrorAction SilentlyContinue
        $nombres = ($sujetos | Select-Object -ExpandProperty SamAccountName) -join ", "
        Write-Host "  $pso -> $nombres"
    }
}

function Ver-Auditoria {
    Write-Host ""
    Write-Host "--- Estado de Auditoria ---"
    auditpol /get /category:*
}

function Ver-CuentasBloqueadas {
    Write-Host ""
    Write-Host "--- Cuentas Bloqueadas ---"
    $bloqueadas = Search-ADAccount -LockedOut
    if ($bloqueadas) {
        $bloqueadas | Select-Object SamAccountName, Name, LockedOut | Format-Table -AutoSize
    } else {
        Write-Host "No hay cuentas bloqueadas."
    }
}

function Ver-GPOs {
    Write-Host ""
    Write-Host "--- GPOs del dominio ---"
    Get-GPO -All | Select-Object DisplayName, GpoStatus | Format-Table -AutoSize
}

function Show-Menu-Verificar {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        VERIFICACION GENERAL - PRACTICA 9"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  [1]  Ver usuarios admin delegados"
    Write-Host "  [2]  Ver ACLs RBAC"
    Write-Host "  [3]  Ver politicas FGPP"
    Write-Host "  [4]  Ver estado de auditoria"
    Write-Host "  [5]  Ver cuentas bloqueadas"
    Write-Host "  [6]  Ver GPOs del dominio"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-Verificar
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Ver-UsuariosAdmin }
        "2" { Ver-RBAC }
        "3" { Ver-FGPP }
        "4" { Ver-Auditoria }
        "5" { Ver-CuentasBloqueadas }
        "6" { Ver-GPOs }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")