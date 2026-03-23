. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
Import-Module ActiveDirectory

$dominio = "DC=practica,DC=local"
$dominioFQDN = "practica.local"
$csvPath = "Z:\windows\usuarios.csv"

function Crear-UOsYGrupos {
    foreach ($uo in @("Cuates", "NoCuates")) {
        $ouPath = "OU=$uo,$dominio"
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouPath'" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $uo -Path $dominio -ProtectedFromAccidentalDeletion $false
            Write-Host "UO creada: $uo"
        }
        if (-not (Get-ADGroup -Filter "Name -eq '$uo'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $uo -GroupScope Global -GroupCategory Security -Path $ouPath
            Write-Host "Grupo creado: $uo"
        }
    }
}

function Crear-Usuario {
    param (
        [string]$Nombre,
        [string]$Usuario,
        [string]$Departamento,
        [string]$Contrasena
    )

    if ($Departamento -notin @("Cuates", "NoCuates")) {
        Write-Host "Departamento invalido. Debe ser Cuates o NoCuates."
        return
    }

    if ([string]::IsNullOrWhiteSpace($Contrasena)) {
        Write-Host "Contrasena vacia para $Usuario. Se omite."
        return
    }

    if (Get-ADUser -Filter "SamAccountName -eq '$Usuario'" -ErrorAction SilentlyContinue) {
        Write-Host "El usuario '$Usuario' ya existe. Se omite."
        return
    }

    $ouDest = "OU=$Departamento,$dominio"
    $pass = ConvertTo-SecureString $Contrasena -AsPlainText -Force

    try {
        New-ADUser `
            -Name $Nombre `
            -GivenName ($Nombre.Split(" ")[0]) `
            -Surname ($Nombre.Split(" ")[1]) `
            -SamAccountName $Usuario `
            -UserPrincipalName "$Usuario@$dominioFQDN" `
            -AccountPassword $pass `
            -Enabled $true `
            -Path $ouDest `
            -Department $Departamento `
            -PasswordNeverExpires $true

        Add-ADGroupMember -Identity $Departamento -Members $Usuario
        Write-Host "Usuario creado: $Usuario -> $Departamento"
    } catch {
        Write-Host "Error al crear $Usuario : $_"
    }
}

function Importar-Desde-CSV {
    if (-not (Test-Path $csvPath)) {
        Write-Host "No se encontro el CSV en $csvPath"
        return
    }

    $usuarios = Import-Csv -Path $csvPath -Encoding UTF8
    foreach ($u in $usuarios) {
        Crear-Usuario -Nombre $u.Nombre -Usuario $u.Usuario -Departamento $u.Departamento -Contrasena $u.Contrasena
    }
    Write-Host "Importacion desde CSV completada."
}

function Agregar-Usuario-Manual {
    Write-Host ""
    Write-Host "--- Agregar usuario manualmente ---"
    $nombre = Read-Host "Nombre completo"
    $usuario = Read-Host "Nombre de usuario (ej: user11)"
    Write-Host "Departamento: [1] Cuates  [2] NoCuates"
    $opDepto = Read-Host "Selecciona"
    $depto = if ($opDepto -eq "1") { "Cuates" } else { "NoCuates" }
    $contrasena = Read-Host "Contrasena"

    Crear-Usuario -Nombre $nombre -Usuario $usuario -Departamento $depto -Contrasena $contrasena
}

function Show-Menu-Usuarios {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        GESTION DE USUARIOS"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  [1]  Importar usuarios desde CSV"
    Write-Host "  [2]  Agregar usuario manualmente"
    Write-Host "  [3]  Listar usuarios existentes"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

Crear-UOsYGrupos

do {
    Show-Menu-Usuarios
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Importar-Desde-CSV }
        "2" { Agregar-Usuario-Manual }
        "3" {
            Write-Host ""
            Get-ADUser -Filter * -Properties Department |
                Where-Object { $_.Department -in @("Cuates", "NoCuates") } |
                Select-Object SamAccountName, Name, Department |
                Format-Table -AutoSize
        }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")