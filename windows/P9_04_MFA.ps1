$multiOTPPath = "C:\Program Files\multiOTP"
$multiOTPExe  = "$multiOTPPath\windows\multiotp.exe"
$servidorIP   = "192.168.117.11"
$secretKey    = "PracticaMFA2024!"

$usuariosOTP = @(
    @{ Usuario="admin_identidad"; Clave="MFRA2YLNOB4GK3TF" }
    @{ Usuario="admin_storage";   Clave="NBSWY3DPEBLWK4TF" }
    @{ Usuario="admin_politicas"; Clave="ORSXG5BRGEZDCNTF" }
    @{ Usuario="admin_auditoria"; Clave="KRUGS4ZANVQW24TF" }
)

function Descargar-MultiOTP {
    if (-not (Test-Path $multiOTPPath)) {
        New-Item -ItemType Directory -Path $multiOTPPath | Out-Null
    }

    Write-Host "Descargando multiOTP 5.10.2.2..."
    $url = "https://download.multiotp.net/oss/update/multiotp_5.10.2.2.zip"
    $zipPath = "C:\multiOTP_download.zip"
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    Write-Host "Descomprimiendo..."
    Expand-Archive -Path $zipPath -DestinationPath $multiOTPPath -Force
    Remove-Item $zipPath
    Write-Host "multiOTP descargado en: $multiOTPPath"
}

function Instalar-Servidor {
    if (-not (Test-Path $multiOTPExe)) {
        Write-Host "multiotp.exe no encontrado en $multiOTPExe"
        Write-Host "Ejecuta primero la opcion 1 y verifica la estructura del zip."
        return
    }

    Write-Host "Configurando servidor multiOTP..."
    & "$multiOTPPath\windows\webservice_install.cmd" | Out-Null
    & $multiOTPExe -config server-secret=$secretKey | Out-Null
    & $multiOTPExe -config default-request-prefix-pin=0 | Out-Null
    & $multiOTPExe -config default-request-ldap-pwd=0 | Out-Null
    & $multiOTPExe -config ldap-server-type=1 | Out-Null
    & $multiOTPExe -config ldap-cn-identifier="sAMAccountName" | Out-Null
    & $multiOTPExe -config ldap-group-cn-identifier="sAMAccountName" | Out-Null
    & $multiOTPExe -config ldap-ssl=0 | Out-Null
    & $multiOTPExe -config ldap-port=389 | Out-Null
    & $multiOTPExe -config ldap-domain-controllers=$servidorIP | Out-Null
    & $multiOTPExe -config ldap-base-dn="DC=practica,DC=local" | Out-Null
    & $multiOTPExe -config ldap-bind-dn="CN=Administrador,CN=Users,DC=practica,DC=local" | Out-Null
    & $multiOTPExe -config ldap-server-password="Leonel90!" | Out-Null

    New-NetFirewallRule -DisplayName "AllowMultiOTP" -Direction Inbound -Protocol TCP -LocalPort 8112 -Action Allow -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Servidor multiOTP configurado correctamente."
}

function Registrar-Todos {
    if (-not (Test-Path $multiOTPExe)) {
        Write-Host "multiotp.exe no encontrado. Ejecuta primero la opcion 1."
        return
    }

    foreach ($u in $usuariosOTP) {
        & $multiOTPExe -create-no-prefix $u.Usuario TOTP $u.Clave 6 30 | Out-Null
        Write-Host ""
        Write-Host "====================================================="
        Write-Host " Usuario : $($u.Usuario)"
        Write-Host " Cuenta  : $($u.Usuario)@practica.local"
        Write-Host " Clave   : $($u.Clave)"
        Write-Host " Tipo    : Basada en tiempo (TOTP)"
        Write-Host "====================================================="
        Write-Host " Google Authenticator: + -> Ingresar clave"
        Write-Host "====================================================="
    }
    Write-Host ""
    Write-Host "Todos los usuarios registrados en MFA."
}

function Ver-Claves {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host " Claves para Google Authenticator"
    Write-Host "============================================================"
    foreach ($u in $usuariosOTP) {
        Write-Host " $($u.Usuario.PadRight(20)) -> $($u.Clave)"
    }
    Write-Host "============================================================"
}

function Instalar-CredentialProvider {
    Write-Host "Descargando multiOTP Credential Provider 5.10.2.2..."
    $cpUrl  = "https://download.multiotp.net/credential-provider/multiOTPCredentialProvider-5.10.2.2.zip"
    $cpZip  = "C:\multiOTP_CP.zip"
    $cpPath = "C:\multiOTP_CP"
    Invoke-WebRequest -Uri $cpUrl -OutFile $cpZip -UseBasicParsing
    Expand-Archive -Path $cpZip -DestinationPath $cpPath -Force
    Remove-Item $cpZip

    $msi = Get-ChildItem -Path $cpPath -Filter "*.msi" -Recurse | Select-Object -First 1
    if (-not $msi) {
        Write-Host "No se encontro el MSI en el zip descargado."
        return
    }

    Write-Host "Instalando Credential Provider..."
    $installArgs = "/i `"$($msi.FullName)`" /quiet MULTIOTP_SERVER_IP=$servidorIP MULTIOTP_SERVER_SECRET=$secretKey MULTIOTP_CPUSLOGON=1 MULTIOTP_CPUSUNLOCK=1"
    Start-Process msiexec -ArgumentList $installArgs -Wait
    Remove-Item $cpPath -Recurse -Force

    Write-Host "Credential Provider instalado."
    Write-Host "IMPORTANTE: Reinicia el servidor para activar el MFA en el login."
}

function Ver-UsuariosOTP {
    if (-not (Test-Path $multiOTPExe)) {
        Write-Host "multiotp.exe no encontrado."
        return
    }
    Write-Host ""
    & $multiOTPExe -list
}

function Desinstalar-CredentialProvider {
    $confirm = Read-Host "Seguro que deseas desinstalar el Credential Provider? (s/n)"
    if ($confirm -eq "s") {
        $prod = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*multiOTP*" }
        if ($prod) {
            $prod.Uninstall() | Out-Null
            Write-Host "Credential Provider desinstalado. Reinicia el servidor."
        } else {
            Write-Host "No se encontro el Credential Provider instalado."
        }
    }
}

function Show-Menu-MFA {
    Clear-Host
    Write-Host "============================================================"
    Write-Host "        MFA - GOOGLE AUTHENTICATOR (multiOTP)"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "  Flujo: Contrasena AD + Codigo TOTP de Google Authenticator"
    Write-Host "  Bloqueo: 3 intentos fallidos / 30 minutos"
    Write-Host ""
    Write-Host "  [1]  Descargar multiOTP"
    Write-Host "  [2]  Instalar y configurar servidor multiOTP"
    Write-Host "  [3]  Registrar todos los usuarios admin en MFA"
    Write-Host "  [4]  Ver claves de configuracion"
    Write-Host "  [5]  Instalar Credential Provider (intercepta login)"
    Write-Host "  [6]  Ver usuarios OTP registrados"
    Write-Host "  [7]  Desinstalar Credential Provider"
    Write-Host "  [0]  Volver al menu principal"
    Write-Host ""
    Write-Host "============================================================"
}

do {
    Show-Menu-MFA
    $op = Read-Host "Selecciona una opcion"

    switch ($op) {
        "1" { Descargar-MultiOTP }
        "2" { Instalar-Servidor }
        "3" { Registrar-Todos }
        "4" { Ver-Claves }
        "5" { Instalar-CredentialProvider }
        "6" { Ver-UsuariosOTP }
        "7" { Desinstalar-CredentialProvider }
        "0" { Write-Host "Volviendo al menu principal..." }
        default { Write-Host "Opcion invalida." }
    }

    if ($op -ne "0") {
        Write-Host ""
        Read-Host "Presiona ENTER para continuar"
    }

} while ($op -ne "0")