# ============================================================
# CREACIÓN DE USUARIO INTEGRAL: AD + ACL + MFA (P8/P9)
# ============================================================

# --- VARIABLES GLOBALES (Ajusta según tu servidor) ---
$dominioFQDN = "practica.local"
$dominioNETBIOS = "PRACTICA"
$servidor = "SERVER2019" # Nombre de tu Windows Server
$shareName = "Usuarios$"   # Nombre del recurso compartido
$rutaBase = "C:\Shares\Usuarios" # Ruta física en el disco
$multiOTPExe = "C:\Program Files\multiOTP\windows\multiotp.exe"
$mfaCheckScript = "C:\mfa_ssh_check.ps1"
$ouBase = "DC=practica,DC=local"

function Crear-Usuario-Completo {
    param (
        [string]$Nombre,
        [string]$Usuario,
        [string]$Departamento,
        [string]$Contrasena
    )

    # 1. Validaciones Iniciales
    if ($Departamento -notin @("Cuates", "NoCuates")) {
        Write-Host "[-] Departamento invalido ($Departamento). Debe ser Cuates o NoCuates." -ForegroundColor Red
        return
    }

    if (Get-ADUser -Filter "SamAccountName -eq '$Usuario'" -ErrorAction SilentlyContinue) {
        Write-Host "[!] El usuario '$Usuario' ya existe en AD. Se omite creacion de cuenta." -ForegroundColor Yellow
    } else {
        # 2. Creación en Active Directory (Lógica P8)
        $ouDest = "OU=$Departamento,$ouBase"
        $pass = ConvertTo-SecureString $Contrasena -AsPlainText -Force
        $rutaRed = "\\$servidor\$shareName\$Usuario"
        $rutaFisica = "$rutaBase\$Usuario"

        try {
            New-ADUser `
                -Name $Nombre `
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
            Write-Host "[+] Usuario $Usuario creado en AD y unido a grupo $Departamento." -ForegroundColor Green

            # 3. Creación de Carpeta y ACLs (Lógica P8)
            if (-not (Test-Path $rutaFisica)) {
                New-Item -ItemType Directory -Path $rutaFisica | Out-Null
            }
            $acl = Get-Acl $rutaFisica
            $regla = New-Object System.Security.AccessControl.FileSystemAccessRule("$dominioNETBIOS\$Usuario", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
            $acl.SetAccessRule($regla)
            Set-Acl $rutaFisica $acl
            Write-Host "[+] Carpeta Home creada y permisos ACL aplicados." -ForegroundColor Green

        } catch {
            Write-Host "[-] Error en proceso AD/ACL: $_" -ForegroundColor Red
            return
        }
    }

    Write-Host "[*] Configurando MFA para $Usuario..." -ForegroundColor Cyan
    $caracteres = "KRUGS4ZANVQW24TA"
    $seed = -join (1..16 | foreach { $caracteres[(Get-Random -Maximum $caracteres.Length)] })

    # Limpiar si existe y crear nuevo
    Remove-Item "C:\Program Files\multiOTP\windows\users\$Usuario.db" -Force -ErrorAction SilentlyContinue
    & $multiOTPExe -create $Usuario TOTP $seed 6
    & $multiOTPExe -set $Usuario time-interval=30
    & $multiOTPExe -set $Usuario request-prefix-pin=0

    # Ajuste de delta_time=3630 para sincronizacion de tiempo
    $dbPath = "C:\Program Files\multiOTP\windows\users\$Usuario.db"
    if (Test-Path $dbPath) {
        (Get-Content $dbPath) -replace "delta_time=0", "delta_time=3630" | Set-Content $dbPath
        Write-Host "[+] multiOTP configurado. Semilla: $seed" -ForegroundColor Green
    }

    # 5. Actualización de mfa_ssh_check.ps1 (Lógica P9)
    if (Test-Path $mfaCheckScript) {
        $content = Get-Content $mfaCheckScript -Raw
        # Insertar el usuario en la lista de permitidos para SSH
        if ($content -match '@\((.+)\)') {
            $listaActual = $matches[1]
            if ($listaActual -notlike "*`"$Usuario`"*") {
                $nuevaLista = $listaActual + ",`"$Usuario`""
                $content = $content -replace [regex]::Escape($listaActual), $nuevaLista
                $content | Set-Content $mfaCheckScript
                Write-Host "[+] Script de SSH actualizado con $Usuario." -ForegroundColor Green
            }
        }
    }
}