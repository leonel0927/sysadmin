# ============================================================
#  httpF.ps1 -- Funciones HTTP + SSL para Windows Server
#  Pr?ctica 7 -- No borrar nada, solo agregar
# ============================================================

function Validar-Puerto {
    param ([int]$Puerto)
    $Reservados = @(21, 22, 23, 25, 53, 110, 143, 443, 445, 3306, 3389, 5432)

    if ($Puerto -lt 1 -or $Puerto -gt 65535) {
        Write-Host "ERROR: Puerto fuera de rango valido (1-65535)." -ForegroundColor Red
        return $false
    }
    if ($Reservados -contains $Puerto) {
        Write-Host "ALERTA: El puerto $Puerto es critico/reservado. Elija otro." -ForegroundColor Red
        return $false
    }
    if (Get-NetTCPConnection -LocalPort $Puerto -ErrorAction SilentlyContinue) {
        Write-Host "ERROR: El puerto $Puerto ya esta siendo usado." -ForegroundColor Red
        return $false
    }
    return $true
}

function Obtener-Versiones-Choco {
    param ([string]$Paquete)
    Write-Host "Consultando versiones de $Paquete en Chocolatey..." -ForegroundColor Cyan
    $resultado = & choco search $Paquete --exact 2>$null
    $lineas = @()
    foreach ($linea in $resultado) {
        $linea = $linea.Trim()
        $partes = $linea -split "\s+"
        if ($partes.Count -ge 2) {
            $nombre = $partes[0]; $ver = $partes[1]
            if ($nombre -eq $Paquete -and $ver -match "^\d+\.\d+[\d\.]*$") {
                $lineas += $ver
            }
        }
    }
    if ($lineas.Count -eq 0) {
        Write-Host "No se encontraron versiones para '$Paquete'." -ForegroundColor Red
        return $null
    }
    return $lineas
}

function Seleccionar-Version {
    param ([string]$Paquete)
    $versiones = Obtener-Versiones-Choco -Paquete $Paquete
    if (-not $versiones) { return $null }
    Write-Host ""
    Write-Host "Versiones disponibles para $Paquete`:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $versiones.Count; $i++) {
        $etiqueta = ""
        if ($i -eq 0)                      { $etiqueta = " [Latest/Development]" }
        if ($i -eq ($versiones.Count - 1)) { $etiqueta = " [LTS/Estable]" }
        Write-Host "  $($i+1). $($versiones[$i])$etiqueta"
    }
    do {
        $sel = Read-Host "Seleccione numero de version"
        $sel = $sel -replace '[^0-9]', ''
    } while ([string]::IsNullOrWhiteSpace($sel) -or [int]$sel -lt 1 -or [int]$sel -gt $versiones.Count)
    $versionElegida = $versiones[[int]$sel - 1]
    Write-Host ">>> Version seleccionada: $versionElegida <<<" -ForegroundColor Green
    return $versionElegida
}

function Crear-Pagina-Prueba {
    param ([string]$Ruta, [string]$Servicio, [string]$Version, [int]$Puerto)
    $Contenido = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>$Servicio</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 80px; background: #f0f4f8; }
        .card { display: inline-block; padding: 40px 60px; background: white;
                border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; } span.ok { color: #27ae60; font-weight: bold; }
        .ssl { background:#27ae60; color:white; padding:4px 12px; border-radius:5px; font-weight:bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Control de Despliegue HTTP</h1>
        <h2>Servidor: <span class="ok">$Servicio</span></h2>
        <h3>Version: $Version</h3>
        <h3>Puerto: $Puerto</h3>
    </div>
</body>
</html>
"@
    if (!(Test-Path $Ruta)) { New-Item -ItemType Directory -Path $Ruta -Force | Out-Null }
    $Contenido | Set-Content -Path "$Ruta\index.html" -Encoding UTF8
    Write-Host "Pagina index.html creada en: $Ruta" -ForegroundColor Green
}

function Aplicar-Seguridad-IIS {
    param ([string]$SitioNombre = "Default Web Site")
    Write-Host "Aplicando seguridad en IIS..." -ForegroundColor Cyan
    try {
        Remove-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" `
            -Filter "system.webServer/httpProtocol/customHeaders" `
            -Name "." -AtElement @{name="X-Powered-By"} -ErrorAction SilentlyContinue
    } catch {}
    $headers = @(
        @{ name = "X-Frame-Options";        value = "SAMEORIGIN" },
        @{ name = "X-Content-Type-Options"; value = "nosniff" }
    )
    foreach ($h in $headers) {
        try {
            Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" `
                -Filter "system.webServer/httpProtocol/customHeaders" `
                -Name "." -Value $h -ErrorAction SilentlyContinue
        } catch {}
    }
    Write-Host "Seguridad IIS aplicada." -ForegroundColor Green
}

function Configurar-Firewall {
    param ([int]$Puerto, [string]$Servicio)
    Write-Host "Configurando firewall para puerto $Puerto..." -ForegroundColor Cyan
    Get-NetFirewallRule -DisplayName "HTTP-$Servicio-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName "HTTP-$Servicio-$Puerto" `
        -Direction Inbound -LocalPort $Puerto -Protocol TCP `
        -Action Allow -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Firewall: puerto $Puerto abierto." -ForegroundColor Green
}

function Crear-Usuario-Dedicado {
    param ([string]$NombreUsuario, [string]$Directorio)
    if (-not (Get-LocalUser -Name $NombreUsuario -ErrorAction SilentlyContinue)) {
        $Password = ConvertTo-SecureString "Srv!2024$NombreUsuario" -AsPlainText -Force
        New-LocalUser -Name $NombreUsuario -Password $Password `
            -FullName "Dedicated $NombreUsuario Service Account" `
            -Description "Usuario dedicado para servicio web" `
            -PasswordNeverExpires -UserMayNotChangePassword | Out-Null
    }
    if (Test-Path $Directorio) {
        $acl = Get-Acl $Directorio
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $NombreUsuario, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl.AddAccessRule($rule)
        Set-Acl -Path $Directorio -AclObject $acl
    }
}

function Instalar-IIS {
    param ([int]$Puerto)
    $Version = "10.0 (Windows Server 2019)"
    Write-Host "`n[IIS] Verificando instalacion..." -ForegroundColor Cyan
    $feature = Get-WindowsFeature Web-Server -ErrorAction SilentlyContinue
    if (-not $feature.Installed) {
        Install-WindowsFeature -Name Web-Server -IncludeManagementTools | Out-Null
        Install-WindowsFeature -Name Web-Security | Out-Null
    } else {
        Write-Host "IIS ya instalado." -ForegroundColor Green
    }
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    Stop-Service W3SVC -ErrorAction SilentlyContinue
    Get-WebBinding -Name "Default Web Site" -ErrorAction SilentlyContinue | Remove-WebBinding
    New-WebBinding -Name "Default Web Site" -Protocol "http" -Port $Puerto -IPAddress "*"
    Crear-Pagina-Prueba -Ruta "C:\inetpub\wwwroot" -Servicio "IIS" -Version $Version -Puerto $Puerto
    Aplicar-Seguridad-IIS
    Configurar-Firewall -Puerto $Puerto -Servicio "IIS"
    Start-Service W3SVC -ErrorAction SilentlyContinue
    Write-Host "[IIS] Desplegado en puerto $Puerto." -ForegroundColor Green
    Pause
}

function Instalar-Apache {
    param ([int]$PuertoGeneral)
    $Version = Seleccionar-Version -Paquete "apache-httpd"
    if (-not $Version) { Write-Host "No se pudo obtener version de Apache." -ForegroundColor Red; Pause; return }

    $apacheRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -match "(?i)^apache" -and (Test-Path "$($_.FullName)\bin\httpd.exe") } |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

    if (-not $apacheRoot) {
        choco install apache-httpd -y --force
        Start-Sleep -Seconds 3
        $zipAlt = Get-ChildItem "C:\ProgramData\chocolatey\lib\apache-httpd\tools" -Filter "*x64*.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($zipAlt) { Expand-Archive -Path $zipAlt.FullName -DestinationPath "C:\tools" -Force; Start-Sleep -Seconds 3 }
        $apacheRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name -match "(?i)^apache" -and (Test-Path "$($_.FullName)\bin\httpd.exe") } |
                      Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
        if (-not $apacheRoot) { Write-Host "ERROR: No se encontro Apache." -ForegroundColor Red; Pause; return }
    }

    $apacheRootEscaped = $apacheRoot -replace '\\', '/'
    Stop-Service Apache2.4 -ErrorAction SilentlyContinue
    Stop-Process -Name httpd -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Generar certificado SSL
    $binPath = "$apacheRoot\bin"
    if (Test-Path "$binPath\openssl.exe") {
        $subject = "/C=MX/ST=Sinaloa/L=Mochis/O=Practica7/CN=www.reprobados.com"
        Start-Process "$binPath\openssl.exe" -ArgumentList "req -config ..\conf\openssl.cnf -new -x509 -days 365 -nodes -subj `"$subject`" -keyout ..\conf\server.key -out ..\conf\server.crt" -WorkingDirectory $binPath -Wait -WindowStyle Hidden
    }

    $confPath = "$apacheRoot\conf\httpd.conf"
    if (Test-Path $confPath) {
        $conf = Get-Content $confPath
        $conf = $conf -replace '#LoadModule ssl_module', 'LoadModule ssl_module'
        $conf = $conf -replace '#LoadModule socache_shmcb_module', 'LoadModule socache_shmcb_module'
        $conf = $conf -replace '#Include conf/extra/httpd-ssl.conf', 'Include conf/extra/httpd-ssl.conf'
        $conf = $conf -replace '^ServerRoot.*', "ServerRoot `"$apacheRootEscaped`""
        $conf = $conf -replace 'Listen\s+\d+', "Listen 80"
        $conf = $conf -replace '^ServerName.*', "ServerName localhost:80"
        $conf | Set-Content $confPath
    }

    $sslConfPath = "$apacheRoot\conf\extra\httpd-ssl.conf"
    if (Test-Path $sslConfPath) {
        $sslConf = Get-Content $sslConfPath
        $sslConf = $sslConf -replace 'Listen\s+\d+', "Listen $PuertoGeneral"
        $sslConf = $sslConf -replace '<VirtualHost _default_:\d+>', "<VirtualHost _default_:$PuertoGeneral>"
        $sslConf = $sslConf -replace 'ServerName.*', "ServerName localhost:$PuertoGeneral"
        $sslConf = $sslConf -replace 'SSLCertificateFile.*', "SSLCertificateFile `"$apacheRootEscaped/conf/server.crt`""
        $sslConf = $sslConf -replace 'SSLCertificateKeyFile.*', "SSLCertificateKeyFile `"$apacheRootEscaped/conf/server.key`""
        $sslConf = $sslConf -replace 'DocumentRoot.*', "DocumentRoot `"$apacheRootEscaped/htdocs`""
        $sslConf | Set-Content $sslConfPath
    }

    Crear-Pagina-Prueba -Ruta "$apacheRoot\htdocs" -Servicio "Apache HTTP Server" -Version $Version -Puerto $PuertoGeneral
    Configurar-Firewall -Puerto $PuertoGeneral -Servicio "Apache"
    Configurar-Firewall -Puerto 80 -Servicio "Apache-HTTP"

    $apacheSvc = Get-Service Apache2.4 -ErrorAction SilentlyContinue
    if ($apacheSvc) { Start-Service Apache2.4 -ErrorAction SilentlyContinue }
    elseif (Test-Path "$apacheRoot\bin\httpd.exe") {
        Start-Process "$apacheRoot\bin\httpd.exe" -WorkingDirectory "$apacheRoot\bin"
    }
    Write-Host "[Apache] Desplegado con SSL en puerto $PuertoGeneral." -ForegroundColor Green
    Pause
}

function Instalar-Nginx {
    param ([int]$Puerto)
    $Version = Seleccionar-Version -Paquete "nginx"
    if (-not $Version) { Write-Host "No se pudo obtener version de Nginx." -ForegroundColor Red; Pause; return }

    Stop-Process -Name nginx -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $nginxYaInstalado = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match "^nginx" -and (Test-Path "$($_.FullName)\nginx.exe") } |
                        Select-Object -First 1

    if (-not $nginxYaInstalado) { choco install nginx -y }

    $nginxRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match "^nginx" -and (Test-Path "$($_.FullName)\nginx.exe") } |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

    if (-not $nginxRoot) { $nginxRoot = "C:\tools\nginx" }

    $confPath = "$nginxRoot\conf\nginx.conf"
    if (Test-Path $confPath) {
        (Get-Content $confPath) -replace 'listen\s+\d+;', "listen $Puerto;" | Set-Content $confPath
    }

    Crear-Pagina-Prueba -Ruta "$nginxRoot\html" -Servicio "Nginx" -Version $Version -Puerto $Puerto
    Crear-Usuario-Dedicado -NombreUsuario "svc_nginx" -Directorio "$nginxRoot\html"
    Configurar-Firewall -Puerto $Puerto -Servicio "Nginx"

    if (Test-Path "$nginxRoot\nginx.exe") {
        Start-Process "$nginxRoot\nginx.exe" -WorkingDirectory $nginxRoot
    }
    Write-Host "[Nginx] Desplegado en puerto $Puerto." -ForegroundColor Green
    Pause
}

# ============================================================
#  NUEVO (Pr?ctica 7) -- Funciones SSL
# ============================================================

function Generar-Certificado {
    param ([string]$CertPath, [string]$KeyPath)
    $domain = "www.reprobados.com"

    # Intentar con makecert o New-SelfSignedCertificate
    Write-Host "Generando certificado autofirmado para $domain..." -ForegroundColor Yellow

    $cert = New-SelfSignedCertificate `
        -DnsName $domain `
        -CertStoreLocation "Cert:\LocalMachine\My" `
        -NotAfter (Get-Date).AddDays(365) `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256

    # Exportar .pfx
    $pfxPath = "C:\ssl\reprobados.pfx"
    if (-not (Test-Path "C:\ssl")) { New-Item -ItemType Directory -Path "C:\ssl" -Force | Out-Null }
    $pwd = ConvertTo-SecureString "practica7" -AsPlainText -Force
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pwd | Out-Null

    Write-Host "Certificado generado: Thumbprint=$($cert.Thumbprint)" -ForegroundColor Green
    return $cert
}

function Configurar-SSL-IIS {
    param ([int]$Puerto = 443)
    Write-Host "`n[SSL-IIS] Configurando HTTPS en puerto $Puerto..." -ForegroundColor Cyan
    Import-Module WebAdministration -ErrorAction SilentlyContinue

    $cert = Generar-Certificado -CertPath "C:\ssl\iis.crt" -KeyPath "C:\ssl\iis.key"
    if (-not $cert) { Write-Host "ERROR: No se pudo generar certificado." -ForegroundColor Red; return }

    # Agregar binding HTTPS
    $sitio = "Default Web Site"
    $bindingExiste = Get-WebBinding -Name $sitio -Protocol "https" -Port $Puerto -ErrorAction SilentlyContinue
    if (-not $bindingExiste) {
        New-WebBinding -Name $sitio -Protocol "https" -Port $Puerto -IPAddress "*"
    }

    # Asignar certificado al binding
    $binding = Get-WebBinding -Name $sitio -Protocol "https" -Port $Puerto
    $binding.AddSslCertificate($cert.Thumbprint, "My")

    # Redirecci?n HTTP -> HTTPS en web.config
    $webConfig = "C:\inetpub\wwwroot\web.config"
    @"
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <system.webServer>
        <rewrite>
            <rules>
                <rule name="HTTP to HTTPS" stopProcessing="true">
                    <match url="(.*)" />
                    <conditions>
                        <add input="{HTTPS}" pattern="^OFF$" />
                    </conditions>
                    <action type="Redirect" url="https://{HTTP_HOST}/{R:1}" redirectType="Permanent" />
                </rule>
            </rules>
        </rewrite>
        <httpProtocol>
            <customHeaders>
                <add name="Strict-Transport-Security" value="max-age=31536000; includeSubDomains" />
            </customHeaders>
        </httpProtocol>
    </system.webServer>
</configuration>
"@ | Set-Content $webConfig -Encoding UTF8

    Configurar-Firewall -Puerto $Puerto -Servicio "IIS-HTTPS"
    Restart-Service W3SVC -ErrorAction SilentlyContinue
    Write-Host "[SSL-IIS] HTTPS activo en puerto $Puerto." -ForegroundColor Green
}

function Configurar-SSL-Apache {
    param ([int]$Puerto = 443)
    Write-Host "`n[SSL-Apache] Configurando HTTPS en puerto $Puerto..." -ForegroundColor Cyan

    $apacheRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -match "(?i)^apache" -and (Test-Path "$($_.FullName)\bin\httpd.exe") } |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

    if (-not $apacheRoot) { Write-Host "Apache no instalado." -ForegroundColor Red; return }

    $apacheRootEscaped = $apacheRoot -replace '\\', '/'
    $binPath = "$apacheRoot\bin"

    # Generar certificado con openssl de Apache
    if (Test-Path "$binPath\openssl.exe") {
        $subject = "/C=MX/ST=Sinaloa/L=Mochis/O=Practica7/CN=www.reprobados.com"
        Start-Process "$binPath\openssl.exe" `
            -ArgumentList "req -config ..\conf\openssl.cnf -new -x509 -days 365 -nodes -subj `"$subject`" -keyout ..\conf\server.key -out ..\conf\server.crt" `
            -WorkingDirectory $binPath -Wait -WindowStyle Hidden
    }

    # Configurar SSL en httpd-ssl.conf
    $sslConfPath = "$apacheRoot\conf\extra\httpd-ssl.conf"
    if (Test-Path $sslConfPath) {
        $sslConf = Get-Content $sslConfPath
        $sslConf = $sslConf -replace 'Listen\s+\d+', "Listen $Puerto"
        $sslConf = $sslConf -replace '<VirtualHost _default_:\d+>', "<VirtualHost _default_:$Puerto>"
        $sslConf = $sslConf -replace 'SSLCertificateFile.*', "SSLCertificateFile `"$apacheRootEscaped/conf/server.crt`""
        $sslConf = $sslConf -replace 'SSLCertificateKeyFile.*', "SSLCertificateKeyFile `"$apacheRootEscaped/conf/server.key`""
        $sslConf | Set-Content $sslConfPath
    }

    Configurar-Firewall -Puerto $Puerto -Servicio "Apache-HTTPS"
    Stop-Service Apache2.4 -ErrorAction SilentlyContinue
    Stop-Process -Name httpd -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process "$apacheRoot\bin\httpd.exe" -WorkingDirectory "$apacheRoot\bin"
    Write-Host "[SSL-Apache] HTTPS activo en puerto $Puerto." -ForegroundColor Green
}

function Configurar-SSL-Nginx {
    param ([int]$Puerto = 8443)
    Write-Host "`n[SSL-Nginx] Configurando HTTPS en puerto $Puerto..." -ForegroundColor Cyan

    $nginxRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match "^nginx" -and (Test-Path "$($_.FullName)\nginx.exe") } |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

    if (-not $nginxRoot) { Write-Host "Nginx no instalado." -ForegroundColor Red; return }

    # Generar certificado con PowerShell
    if (-not (Test-Path "$nginxRoot\conf\ssl")) {
        New-Item -ItemType Directory -Path "$nginxRoot\conf\ssl" -Force | Out-Null
    }

    $cert = New-SelfSignedCertificate `
        -DnsName "www.reprobados.com" `
        -CertStoreLocation "Cert:\LocalMachine\My" `
        -NotAfter (Get-Date).AddDays(365)

    $pwd = ConvertTo-SecureString "practica7" -AsPlainText -Force
    $pfxPath = "$nginxRoot\conf\ssl\nginx.pfx"
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pwd | Out-Null

    # Exportar como PEM para nginx
    $crtPath = "$nginxRoot\conf\ssl\nginx.crt"
    $keyPath = "$nginxRoot\conf\ssl\nginx.key"

    # Usar openssl de Apache si est? disponible
    $apacheRoot = Get-ChildItem "C:\tools" -Directory -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -match "(?i)^apache" -and (Test-Path "$($_.FullName)\bin\openssl.exe") } |
                  Select-Object -First 1 -ExpandProperty FullName

    if ($apacheRoot) {
        $opensslExe = "$apacheRoot\bin\openssl.exe"
        Start-Process $opensslExe -ArgumentList "pkcs12 -in `"$pfxPath`" -clcerts -nokeys -out `"$crtPath`" -passin pass:practica7" -Wait -WindowStyle Hidden
        Start-Process $opensslExe -ArgumentList "pkcs12 -in `"$pfxPath`" -nocerts -nodes -out `"$keyPath`" -passin pass:practica7" -Wait -WindowStyle Hidden
    }

    # Configurar nginx.conf con SSL
    $confPath = "$nginxRoot\conf\nginx.conf"
    $nginxRootEscaped = $nginxRoot -replace '\\', '/'
    $crtEscaped = $crtPath -replace '\\', '/'
    $keyEscaped = $keyPath -replace '\\', '/'

    $confContent = @"
worker_processes  1;
events { worker_connections  1024; }
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    # HTTP -> HTTPS redirect
    server {
        listen 80;
        server_name www.reprobados.com;
        return 301 https://`$host:`$server_port`$request_uri;
    }

    server {
        listen $Puerto ssl;
        server_name www.reprobados.com;

        ssl_certificate     $crtEscaped;
        ssl_certificate_key $keyEscaped;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_ciphers         HIGH:!aNULL:!MD5;

        root   $nginxRootEscaped/html;
        index  index.html;

        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
    }
}
"@
    $confContent | Set-Content $confPath -Encoding UTF8

    Configurar-Firewall -Puerto $Puerto -Servicio "Nginx-HTTPS"
    Stop-Process -Name nginx -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process "$nginxRoot\nginx.exe" -WorkingDirectory $nginxRoot
    Write-Host "[SSL-Nginx] HTTPS activo en puerto $Puerto." -ForegroundColor Green
}

function Configurar-FTPS-IIS {
    Write-Host "`n[FTPS] Configurando SSL en IIS-FTP..." -ForegroundColor Cyan
    Import-Module WebAdministration -ErrorAction SilentlyContinue

    $cert = Generar-Certificado -CertPath "C:\ssl\ftp.crt" -KeyPath "C:\ssl\ftp.key"
    if (-not $cert) { Write-Host "ERROR: No se pudo generar certificado." -ForegroundColor Red; return }

    # Aplicar certificado al sitio FTP
    Set-ItemProperty "IIS:\Sites\FTP" `
        -Name ftpServer.security.ssl.serverCertHash `
        -Value $cert.Thumbprint

    # Requerir SSL en canal de control y datos
    Set-ItemProperty "IIS:\Sites\FTP" `
        -Name ftpServer.security.ssl.controlChannelPolicy `
        -Value 1   # SslRequire

    Set-ItemProperty "IIS:\Sites\FTP" `
        -Name ftpServer.security.ssl.dataChannelPolicy `
        -Value 1   # SslRequire

    # Abrir puerto 990 (FTPS impl?cito) en firewall
    New-NetFirewallRule -DisplayName "FTPS-990" `
        -Direction Inbound -LocalPort 990 -Protocol TCP `
        -Action Allow -ErrorAction SilentlyContinue | Out-Null

    Restart-WebItem "IIS:\Sites\FTP" -ErrorAction SilentlyContinue
    Write-Host "[FTPS] SSL activo en IIS-FTP. Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
}

function Mostrar-Resumen-SSL {
    Write-Host "`n============================================" -ForegroundColor Blue
    Write-Host "   RESUMEN DE VERIFICACION SSL/TLS" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Blue

    # IIS HTTPS
    $iisBinding = Get-WebBinding -Name "Default Web Site" -Protocol "https" -ErrorAction SilentlyContinue
    if ($iisBinding) {
        Write-Host "[OK]  IIS HTTPS activo en puerto $($iisBinding.bindingInformation.Split(':')[1])" -ForegroundColor Green
    } else {
        Write-Host "[ERR] IIS HTTPS no configurado" -ForegroundColor Red
    }

    # Apache
    $apacheProc = Get-Process -Name httpd -ErrorAction SilentlyContinue
    if ($apacheProc) {
        Write-Host "[OK]  Apache activo (PID: $($apacheProc[0].Id))" -ForegroundColor Green
    } else {
        Write-Host "[ERR] Apache no esta corriendo" -ForegroundColor Red
    }

    # Nginx
    $nginxProc = Get-Process -Name nginx -ErrorAction SilentlyContinue
    if ($nginxProc) {
        Write-Host "[OK]  Nginx activo (PID: $($nginxProc[0].Id))" -ForegroundColor Green
    } else {
        Write-Host "[ERR] Nginx no esta corriendo" -ForegroundColor Red
    }

    # IIS-FTP SSL
    try {
        $ftpSSL = Get-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.controlChannelPolicy -ErrorAction SilentlyContinue
        if ($ftpSSL -eq 1) {
            Write-Host "[OK]  IIS-FTP SSL (FTPS) activo" -ForegroundColor Green
        } else {
            Write-Host "[ERR] IIS-FTP sin SSL" -ForegroundColor Red
        }
    } catch {
        Write-Host "[ERR] IIS-FTP no encontrado" -ForegroundColor Red
    }

    # Certificados en el store
    Write-Host "`n--- Certificados en LocalMachine\My ---" -ForegroundColor Yellow
    Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Subject -like "*reprobados*" } |
        ForEach-Object {
            Write-Host "[OK]  CN=$($_.Subject) | Expira: $($_.NotAfter)" -ForegroundColor Green
        }

    # Puertos activos
    Write-Host "`n--- Puertos SSL activos ---" -ForegroundColor Yellow
    Get-NetTCPConnection -State Listen |
        Where-Object { $_.LocalPort -in @(443, 8443, 990, 80, 8080, 21) } |
        Sort-Object LocalPort |
        ForEach-Object {
            $proc = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name
            Write-Host "  Puerto $($_.LocalPort) -- $proc" -ForegroundColor Cyan
        }

    Pause
}