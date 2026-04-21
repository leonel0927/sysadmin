. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
Import-Module ActiveDirectory

$dominio = "DC=practica,DC=local"

function Crear-FGPP {
    # FGPP para admins: minimo 12 caracteres
    if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO-Admins'" -ErrorAction SilentlyContinue)) {
        New-ADFineGrainedPasswordPolicy `
            -Name "PSO-Admins" `
            -Precedence 10 `
            -MinPasswordLength 12 `
            -PasswordHistoryCount 10 `
            -ComplexityEnabled $true `
            -ReversibleEncryptionEnabled $false `
            -LockoutThreshold 5 `
            -LockoutDuration "00:30:00" `
            -LockoutObservationWindow "00:30:00" `
            -MinPasswordAge "1.00:00:00" `
            -MaxPasswordAge "60.00:00:00"
        Write-Host "PSO-Admins creada: minimo 12 caracteres"
    } else {
        Write-Host "PSO-Admins ya existe"
    }

    # FGPP para usuarios estandar: minimo 8 caracteres
    if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO-Usuarios'" -ErrorAction SilentlyContinue)) {
        New-ADFineGrainedPasswordPolicy `
            -Name "PSO-Usuarios" `
            -Precedence 20 `
            -MinPasswordLength 8 `
            -PasswordHistoryCount 5 `
            -ComplexityEnabled $true `
            -ReversibleEncryptionEnabled $false `
            -LockoutThreshold 5 `
            -LockoutDuration "00:30:00" `
            -LockoutObservationWindow "00:30:00" `
            -MinPasswordAge "1.00:00:00" `
            -MaxPasswordAge "90.00:00:00"
        Write-Host "PSO-Usuarios creada: minimo 8 caracteres"
    } else {
        Write-Host "PSO-Usuarios ya existe"
    }

    # Aplicar PSO-Admins a los 4 usuarios admin
    foreach ($admin in @("admin_identidad","admin_storage","admin_politicas","admin_auditoria")) {
        try {
            Add-ADFineGrainedPasswordPolicySubject -Identity "PSO-Admins" -Subjects $admin
            Write-Host "PSO-Admins aplicada a: $admin"
        } catch {
            Write-Host "PSO-Admins ya aplicada a: $admin"
        }
    }

    # Aplicar PSO-Usuarios a grupos Cuates y NoCuates
    foreach ($grupo in @("Cuates","NoCuates")) {
        try {
            Add-ADFineGrainedPasswordPolicySubject -Identity "PSO-Usuarios" -Subjects $grupo
            Write-Host "PSO-Usuarios aplicada a grupo: $grupo"
        } catch {
            Write-Host "PSO-Usuarios ya aplicada a: $grupo"
        }
    }

    Write-Host "FGPP configurada correctamente."
}

function Ver-FGPP {
    Write-Host ""
    Write-Host "Politicas de contrasena ajustadas:"
    Get-ADFineGrainedPasswordPolicy -Filter * | Select-Object Name, Precedence, MinPasswordLength, LockoutThreshold, LockoutDuration | Format-Table -AutoSize

    Write-Host "Sujetos aplicados:"
    foreach ($pso in @("PSO-Admins","PSO-Usuarios")) {
        Write-Host "  $pso :"
        Get-ADFineGrainedPasswordPolicySubject -Identity $pso | Select-Object -ExpandProperty SamAccountName | ForEach-Object { Write-Host "    $_" }
    }
}

function Probar-FGPP {
    $usuario = Read-Host "Usuario a probar (ej: admin_identidad)"
    $resultado = Get-ADUserResultantPasswordPolicy -Identity $usuario
    if ($resultado) {
        Write-Host "Politica aplicada a $usuario :"
        Write-Host "  Nombre           : $($resultado.Name)"
        Write-Host "  Min caracteres   : $($resultado.MinPasswordLength)"
        Write-Host "  Complejidad      : $($resultado.ComplexityEnabled)"
        Write-Host "  Umbral bloqueo   : $($resultado.LockoutThreshold)"
    } else {
        Write-Host "No tiene FGPP aplicada. Usa la politica de dominio por defecto."
    }
}

function Show-Menu-FGPP {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        FINE-GRAINED PASSWORD POLICY (FGPP)"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  PSO-Admins   : minimo 12 caracteres (admin_*)"
    Write-Host "  PSO-Usuarios : minimo 8 caracteres  (Cuates, NoCuates)"
    Write-Host ""
    Write-Host "  [1]  Crear y aplicar politicas FGPP"
    Write-Host "  [2]  Ver politicas existentes"
    Write-Host "  [3]  Probar politica aplicada a un usuario"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-FGPP
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Crear-FGPP }
        "2" { Ver-FGPP }
        "3" { Probar-FGPP }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")