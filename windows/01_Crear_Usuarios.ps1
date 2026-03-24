. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
Import-Module ActiveDirectory

$dominio = "DC=practica,DC=local"
$dominioFQDN = "practica.local"
$csvPath = "Z:\windows\usuarios.csv"
$rutaBase = "C:\Perfiles"
$servidor = "192.168.117.11"
$shareName = "Perfiles"

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

function Configurar-Compartido {
    if (-not (Test-Path $rutaBase)) {
        New-Item -ItemType Directory -Path $rutaBase | Out-Null
        Write-Host "Carpeta base creada: $rutaBase"
    }

    if (-not (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $shareName -Path $rutaBase -FullAccess "PRACTICA\Administrador" -ChangeAccess "PRACTICA\Usuarios del dominio"
        Write-Host "Carpeta compartida creada: \\$servidor\$shareName"
    } else {
        Write-Host "Carpeta compartida ya existe: \\$servidor\$shareName"
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
    $rutaUsuario = "$rutaBase\$Usuario"
    $rutaRed = "\\$servidor\$shareName\$Usuario"

    if (-not (Test-Path $rutaUsuario)) {
        New-Item -ItemType Directory -Path $rutaUsuario | Out-Null
    }

    $acl = Get-Acl $rutaUsuario
    $regla = New-Object System.Security.AccessControl.FileSystemAccessRule("PRACTICA\$Usuario", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($regla)
    Set-Acl $rutaUsuario $acl

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
            -PasswordNeverExpires $true `
            -HomeDirectory $rutaRed `
            -HomeDrive "H:"

        Add-ADGroupMember -Identity $Departamento -Members $Usuario
        Write-Host "Usuario creado: $Usuario -> $Departamento | Home: $rutaRed"
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

function Asignar-HomeFolders-Existentes {
    $usuarios = Import-Csv -Path $csvPath -Encoding UTF8
    foreach ($u in $usuarios) {
        $rutaRed = "\\$servidor\$shareName\$($u.Usuario)"
        $rutaUsuario = "$rutaBase\$($u.Usuario)"

        if (-not (Test-Path $rutaUsuario)) {
            New-Item -ItemType Directory -Path $rutaUsuario | Out-Null
        }

        $acl = Get-Acl $rutaUsuario
        $regla = New-Object System.Security.AccessControl.FileSystemAccessRule("PRACTICA\$($u.Usuario)", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRule($regla)
        Set-Acl $rutaUsuario $acl

        Set-ADUser -Identity $u.Usuario -HomeDirectory $rutaRed -HomeDrive "H:"
        Write-Host "Home folder asignado a: $($u.Usuario) -> $rutaRed"
    }
    Write-Host "Home folders asignados correctamente."
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
    Write-Host "  [4]  Configurar carpeta compartida Perfiles"
    Write-Host "  [5]  Asignar Home Folders a usuarios existentes"
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
            Get-ADUser -Filter * -Properties Department, HomeDirectory |
                Where-Object { $_.Department -in @("Cuates", "NoCuates") } |
                Select-Object SamAccountName, Name, Department, HomeDirectory |
                Format-Table -AutoSize
        }
        "4" { Configurar-Compartido }
        "5" { Asignar-HomeFolders-Existentes }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")