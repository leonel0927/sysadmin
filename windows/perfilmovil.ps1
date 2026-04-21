. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "RSAT-AD-PowerShell"
Import-Module ActiveDirectory

$servidor = "192.168.117.11"
$rutaBase = "C:\Perfiles"
$shareName = "Perfiles"
$dominio = "DC=practica,DC=local"

function Configurar-Compartido {
    if (-not (Test-Path $rutaBase)) {
        New-Item -ItemType Directory -Path $rutaBase | Out-Null
        Write-Host "Carpeta base creada: $rutaBase"
    }

    if (-not (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $shareName -Path $rutaBase `
            -FullAccess "Everyone" `
            -Description "Perfiles moviles de usuarios del dominio"
        Write-Host "Carpeta compartida creada: \\$servidor\$shareName"
    } else {
        Write-Host "Carpeta compartida ya existe: \\$servidor\$shareName"
    }

    $acl = Get-Acl $rutaBase
    $regla = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "PRACTICA\Usuarios del dominio", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
    )
    $acl.SetAccessRule($regla)
    Set-Acl $rutaBase $acl
    Write-Host "Permisos de carpeta base configurados."
}

function Configurar-PerfilesMoviles {
    $csvPath = "Z:\windows\usuarios.csv"
    if (-not (Test-Path $csvPath)) {
        Write-Host "No se encontro el CSV en $csvPath"
        return
    }

    $usuarios = Import-Csv -Path $csvPath -Encoding UTF8
    foreach ($u in $usuarios) {
        $rutaPerfil = "\\$servidor\$shareName\$($u.Usuario)"
        $rutaLocal  = "$rutaBase\$($u.Usuario).V6"

        if (-not (Test-Path $rutaLocal)) {
            New-Item -ItemType Directory -Path $rutaLocal | Out-Null
            Write-Host "Carpeta V6 creada: $rutaLocal"
        }

        $acl = Get-Acl $rutaLocal
        $regla = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "PRACTICA\$($u.Usuario)", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl.SetAccessRule($regla)
        Set-Acl $rutaLocal $acl

        Set-ADUser -Identity $u.Usuario -ProfilePath $rutaPerfil
        Write-Host "Perfil movil configurado: $($u.Usuario) -> $rutaPerfil"
    }

    Write-Host "Perfiles moviles configurados correctamente."
}

function Ver-Perfiles {
    Write-Host ""
    Get-ADUser -Filter * -Properties ProfilePath, Department |
        Where-Object { $_.Department -in @("Cuates","NoCuates") } |
        Select-Object SamAccountName, Department, ProfilePath |
        Format-Table -AutoSize
}

function Configurar-GPO-Perfiles {
    $gpoName = "Perfiles-Moviles"

    if (-not (Get-GPO -Name $gpoName -ErrorAction SilentlyContinue)) {
        New-GPO -Name $gpoName | Out-Null
        Write-Host "GPO creada: $gpoName"
    } else {
        Write-Host "GPO ya existe: $gpoName"
    }

    Set-GPRegistryValue -Name $gpoName `
        -Key "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" `
        -ValueName "KeepRasConnections" `
        -Type DWord -Value 1 | Out-Null

    foreach ($ou in @("Cuates","NoCuates")) {
        try {
            New-GPLink -Name $gpoName -Target "OU=$ou,$dominio" -ErrorAction Stop | Out-Null
            Write-Host "GPO vinculada a OU: $ou"
        } catch {
            Write-Host "GPO ya vinculada a: $ou"
        }
    }

    Write-Host "GPO de perfiles moviles configurada."
}

function Show-Menu-Perfiles {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        PERFILES MOVILES (ROAMING PROFILES)"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  Ruta base  : C:\Perfiles\"
    Write-Host "  Compartido : \\$servidor\$shareName"
    Write-Host "  Extension  : .V6 (Windows 10 / Server 2019)"
    Write-Host ""
    Write-Host "  [1]  Configurar carpeta compartida"
    Write-Host "  [2]  Configurar perfiles moviles en AD"
    Write-Host "  [3]  Configurar GPO de perfiles moviles"
    Write-Host "  [4]  Ver perfiles configurados"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-Perfiles
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Configurar-Compartido }
        "2" { Configurar-PerfilesMoviles }
        "3" { Configurar-GPO-Perfiles }
        "4" { Ver-Perfiles }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")