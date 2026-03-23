. "Z:\FUNCIONES\instalacion.ps1"
verificar_instalacion -pak "FS-Resource-Manager"
Import-Module ActiveDirectory

$csvPath = "Z:\windows\usuarios.csv"
$rutaBase = "C:\Perfiles"

function Crear-Plantillas {
    if (-not (Get-FsrmQuotaTemplate -Name "Cuota-10MB" -ErrorAction SilentlyContinue)) {
        New-FsrmQuotaTemplate -Name "Cuota-10MB" -Size 10MB
        Write-Host "Plantilla creada: Cuota-10MB"
    } else {
        Write-Host "Plantilla ya existe: Cuota-10MB"
    }

    if (-not (Get-FsrmQuotaTemplate -Name "Cuota-5MB" -ErrorAction SilentlyContinue)) {
        New-FsrmQuotaTemplate -Name "Cuota-5MB" -Size 5MB
        Write-Host "Plantilla creada: Cuota-5MB"
    } else {
        Write-Host "Plantilla ya existe: Cuota-5MB"
    }
}

function Crear-Cuotas {
    if (-not (Test-Path $rutaBase)) {
        New-Item -ItemType Directory -Path $rutaBase | Out-Null
        Write-Host "Carpeta base creada: $rutaBase"
    }

    if (-not (Test-Path $csvPath)) {
        Write-Host "No se encontro el CSV en $csvPath"
        return
    }

    $usuarios = Import-Csv -Path $csvPath -Encoding UTF8
    foreach ($u in $usuarios) {
        $rutaUsuario = "$rutaBase\$($u.Usuario)"

        if (-not (Test-Path $rutaUsuario)) {
            New-Item -ItemType Directory -Path $rutaUsuario | Out-Null
        }

        $plantilla = if ($u.Departamento -eq "Cuates") { "Cuota-10MB" } else { "Cuota-5MB" }

        if (-not (Get-FsrmQuota -Path $rutaUsuario -ErrorAction SilentlyContinue)) {
            New-FsrmQuota -Path $rutaUsuario -Template $plantilla
            Write-Host "Cuota $plantilla aplicada a: $($u.Usuario)"
        } else {
            Write-Host "Cuota ya existe para: $($u.Usuario)"
        }
    }

    Write-Host "Cuotas configuradas correctamente."
}

function Ver-Cuotas {
    Write-Host ""
    Get-FsrmQuota | Select-Object Path,
        @{N="Limite(MB)";E={[math]::Round($_.Size/1MB,0)}},
        @{N="Usado(MB)";E={[math]::Round($_.Usage/1MB,2)}},
        @{N="Tipo";E={if($_.SoftLimit){"Soft"}else{"Hard"}}} |
        Format-Table -AutoSize
}

function Show-Menu-FSRM {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        FSRM - CUOTAS DE DISCO"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  Cuates   : 10 MB (Hard Quota)"
    Write-Host "  NoCuates : 5 MB  (Hard Quota)"
    Write-Host "  Ruta base: C:\Perfiles\"
    Write-Host ""
    Write-Host "  [1]  Crear plantillas de cuota"
    Write-Host "  [2]  Crear carpetas y aplicar cuotas a usuarios"
    Write-Host "  [3]  Ver cuotas existentes"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-FSRM
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Crear-Plantillas }
        "2" { Crear-Cuotas }
        "3" { Ver-Cuotas }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")