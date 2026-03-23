. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "FS-Resource-Manager"

$csvPath = "Z:\windows\usuarios.csv"
$rutaBase = "C:\Perfiles"
$grupoArchivos = "Archivos-Bloqueados"
$plantillaScreen = "Bloqueo-Multimedia-Ejecutables"
$extensiones = @("*.mp3","*.mp4","*.exe","*.msi")

function Crear-GrupoArchivos {
    if (-not (Get-FsrmFileGroup -Name $grupoArchivos -ErrorAction SilentlyContinue)) {
        New-FsrmFileGroup -Name $grupoArchivos -IncludePattern $extensiones
        Write-Host "Grupo de archivos creado: $grupoArchivos"
    } else {
        Set-FsrmFileGroup -Name $grupoArchivos -IncludePattern $extensiones
        Write-Host "Grupo de archivos actualizado: $grupoArchivos"
    }
}

function Crear-PlantillaScreening {
    if (-not (Get-FsrmFileScreenTemplate -Name $plantillaScreen -ErrorAction SilentlyContinue)) {
        New-FsrmFileScreenTemplate -Name $plantillaScreen -IncludeGroup $grupoArchivos
        Write-Host "Plantilla de screening creada: $plantillaScreen"
    } else {
        Write-Host "Plantilla ya existe: $plantillaScreen"
    }
}

function Aplicar-Screening {
    if (-not (Test-Path $csvPath)) {
        Write-Host "No se encontro el CSV en $csvPath"
        return
    }

    $usuarios = Import-Csv -Path $csvPath -Encoding UTF8
    foreach ($u in $usuarios) {
        $rutaUsuario = "$rutaBase\$($u.Usuario)"

        if (-not (Test-Path $rutaUsuario)) {
            Write-Host "Carpeta no existe para: $($u.Usuario) - Ejecuta primero la opcion 6"
            continue
        }

        if (-not (Get-FsrmFileScreen -Path $rutaUsuario -ErrorAction SilentlyContinue)) {
            New-FsrmFileScreen -Path $rutaUsuario -Template $plantillaScreen
            Write-Host "Screening aplicado a: $($u.Usuario)"
        } else {
            Write-Host "Screening ya existe en: $($u.Usuario)"
        }
    }

    Write-Host "Apantallamiento configurado correctamente."
}

function Ver-Screening {
    Write-Host ""
    Get-FsrmFileScreen | Select-Object Path, Template, Active | Format-Table -AutoSize
}

function Show-Menu-Screening {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        FSRM - APANTALLAMIENTO DE ARCHIVOS"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  Extensiones bloqueadas: .mp3 .mp4 .exe .msi"
    Write-Host "  Tipo: Active Screening (bloqueo real)"
    Write-Host ""
    Write-Host "  [1]  Crear grupo de archivos bloqueados"
    Write-Host "  [2]  Crear plantilla de apantallamiento"
    Write-Host "  [3]  Aplicar screening a carpetas de usuarios"
    Write-Host "  [4]  Ver screening existente"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-Screening
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Crear-GrupoArchivos }
        "2" { Crear-PlantillaScreening }
        "3" { Aplicar-Screening }
        "4" { Ver-Screening }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")