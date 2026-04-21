. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
Import-Module ActiveDirectory

$dominio = "DC=practica,DC=local"
$dominioFQDN = "practica.local"
$ouCuates = "OU=Cuates,$dominio"
$ouNoCuates = "OU=NoCuates,$dominio"

$admins = @(
    @{ Usuario="admin_identidad"; Nombre="Admin Identidad"; Password="AdminIAM2024!" }
    @{ Usuario="admin_storage";   Nombre="Admin Storage";   Password="AdminSTO2024!" }
    @{ Usuario="admin_politicas"; Nombre="Admin Politicas"; Password="AdminGPO2024!" }
    @{ Usuario="admin_auditoria"; Nombre="Admin Auditoria"; Password="AdminAUD2024!" }
)

function Crear-AdminUsuarios {
    $ouAdmin = "OU=Admins,$dominio"

    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouAdmin'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name "Admins" -Path $dominio -ProtectedFromAccidentalDeletion $false
        Write-Host "OU creada: Admins"
    }

    foreach ($a in $admins) {
        if (Get-ADUser -Filter "SamAccountName -eq '$($a.Usuario)'" -ErrorAction SilentlyContinue) {
            Write-Host "Ya existe: $($a.Usuario)"
            continue
        }
        $pass = ConvertTo-SecureString $a.Password -AsPlainText -Force
        New-ADUser `
            -Name $a.Nombre `
            -SamAccountName $a.Usuario `
            -UserPrincipalName "$($a.Usuario)@$dominioFQDN" `
            -AccountPassword $pass `
            -Enabled $true `
            -Path $ouAdmin `
            -PasswordNeverExpires $true
        Write-Host "Usuario creado: $($a.Usuario)"
    }
}

function Configurar-RBAC {
    $sidIdentidad  = (Get-ADUser -Identity "admin_identidad").SID.Value
    $sidStorage    = (Get-ADUser -Identity "admin_storage").SID.Value
    $sidPoliticas  = (Get-ADUser -Identity "admin_politicas").SID.Value
    $sidAuditoria  = (Get-ADUser -Identity "admin_auditoria").SID.Value

    foreach ($ou in @($ouCuates, $ouNoCuates)) {
        $ouShort = ($ou -split ",")[0] -replace "OU=",""
        Write-Host "Configurando ACLs en OU: $ouShort"

        # admin_identidad: crear/eliminar/modificar usuarios + reset password
        dsacls $ou /G "$($env:USERDOMAIN)\admin_identidad:CCDC;user" | Out-Null
        dsacls $ou /G "$($env:USERDOMAIN)\admin_identidad:WP;pwdLastSet;user" | Out-Null
        dsacls $ou /G "$($env:USERDOMAIN)\admin_identidad:CA;Reset Password;user" | Out-Null
        dsacls $ou /G "$($env:USERDOMAIN)\admin_identidad:WP;telephoneNumber;user" | Out-Null
        dsacls $ou /G "$($env:USERDOMAIN)\admin_identidad:WP;physicalDeliveryOfficeName;user" | Out-Null
        dsacls $ou /G "$($env:USERDOMAIN)\admin_identidad:WP;mail;user" | Out-Null
        Write-Host "  admin_identidad: permisos IAM aplicados"

        # admin_storage: sin permisos sobre usuarios (solo FSRM, se gestiona localmente)
        dsacls $ou /D "$($env:USERDOMAIN)\admin_storage:CA;Reset Password;user" | Out-Null
        Write-Host "  admin_storage: denegado Reset Password"

        # admin_politicas: solo lectura en OUs
        dsacls $ou /G "$($env:USERDOMAIN)\admin_politicas:GR" | Out-Null
        Write-Host "  admin_politicas: permiso lectura aplicado"

        # admin_auditoria: solo lectura
        dsacls $ou /G "$($env:USERDOMAIN)\admin_auditoria:GR" | Out-Null
        Write-Host "  admin_auditoria: permiso lectura aplicado"
    }

    # admin_politicas: permisos sobre GPOs
    dsacls "CN=Policies,CN=System,$dominio" /G "$($env:USERDOMAIN)\admin_politicas:GWGR" | Out-Null
    Write-Host "  admin_politicas: permisos GPO aplicados"

    # admin_auditoria: acceso a logs de seguridad (grupo Event Log Readers)
    Add-ADGroupMember -Identity "Lectores del registro de eventos" -Members "admin_auditoria" -ErrorAction SilentlyContinue
    Add-ADGroupMember -Identity "Event Log Readers" -Members "admin_auditoria" -ErrorAction SilentlyContinue
    Write-Host "  admin_auditoria: agregado a Event Log Readers"

    Write-Host "RBAC configurado correctamente."
}

function Ver-Admins {
    Write-Host ""
    Get-ADUser -Filter * -SearchBase "OU=Admins,$dominio" -Properties Department |
        Select-Object SamAccountName, Name, Enabled |
        Format-Table -AutoSize
}

function Show-Menu-RBAC {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        RBAC - USUARIOS ADMIN DELEGADOS"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  Usuarios:"
    Write-Host "  admin_identidad -> Gestion ciclo de vida usuarios"
    Write-Host "  admin_storage   -> Gestion FSRM y cuotas"
    Write-Host "  admin_politicas -> Gestion GPOs"
    Write-Host "  admin_auditoria -> Lectura de logs"
    Write-Host ""
    Write-Host "  [1]  Crear usuarios admin delegados"
    Write-Host "  [2]  Configurar ACLs y permisos RBAC"
    Write-Host "  [3]  Ver usuarios admin existentes"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-RBAC
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Crear-AdminUsuarios }
        "2" { Configurar-RBAC }
        "3" { Ver-Admins }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")