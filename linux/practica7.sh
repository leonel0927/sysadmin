#!/bin/bash

SCRIPT_DIR="/home/srv-linux-server/SCRIPS2"
source "$SCRIPT_DIR/FUNCIONES/instalacion.sh" 2>/dev/null
source "$SCRIPT_DIR/FUNCIONES/status.sh"      2>/dev/null
source "$SCRIPT_DIR/linux/httpF.sh"           2>/dev/null
_cargar_funciones_ftp() {
    local ftp_script="$SCRIPT_DIR/linux/ftp.sh"
    if [ ! -f "$ftp_script" ]; then
        echo -e "${R}[WARN] No se encontró $ftp_script — funciones FTP no disponibles${W}"
        return 1
    fi
    SOLO_FUNCIONES=1 source "$ftp_script"
}
_cargar_funciones_ftp

FTP_IP="192.168.117.10"
FTP_REPO_BASE="/srv/ftp/http/Linux"
SSL_DIR="/etc/ssl/practica7"
DOMAIN="reprobados.com"
LOG_RESUMEN="/tmp/practica7_resumen.log"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[0m'
titulo() {
    echo -e "\n${B}══════════════════════════════════════${W}"
    echo -e "${C}  $1${W}"
    echo -e "${B}══════════════════════════════════════${W}"
}
pausa()   { echo -e "\nPresione ${Y}ENTER${W} para continuar..."; read -r; }
log_ok()  { echo -e "${G}[OK]${W}  $1"; echo "[OK]  $1" >> "$LOG_RESUMEN"; }
log_err() { echo -e "${R}[ERR]${W} $1"; echo "[ERR] $1" >> "$LOG_RESUMEN"; }
log_inf() { echo -e "${Y}[INF]${W} $1"; echo "[INF] $1" >> "$LOG_RESUMEN"; }

gestionar_usuarios_ftp() {
    titulo "GESTIÓN DE USUARIOS FTP"
    echo "1) Agregar usuario(s)"
    echo "2) Reubicar usuario de grupo"
    echo "3) Volver"
    read -rp "Opción: " opc
    case $opc in
        1) agg_users   ;;   
        2) reubicar    ;;   
        3) return      ;;
        *) echo "Opción inválida"; sleep 1 ;;
    esac
}
orquestar_instalacion() {
    titulo "ORQUESTADOR DE INSTALACIÓN"

    echo "¿Desde dónde desea instalar?"
    echo "  1) WEB  (gestor de paquetes apt)"
    echo "  2) FTP  (repositorio privado)"
    read -rp "Opción: " fuente

    if [[ "$fuente" == "2" ]]; then
        echo -e "\n${Y}Redirigiendo al módulo FTP...${W}"
        source "$SCRIPT_DIR/linux/ftp.sh"
        instalar_desde_ftp
        return
    fi

    echo ""
    echo "¿Qué servicio desea instalar?"
    echo "  1) Apache2"
    echo "  2) Nginx"
    echo "  3) Tomcat"
    echo "  4) vsftpd (FTP)"
    read -rp "Servicio: " sel_svc

    local servicio
    case $sel_svc in
        1) servicio="apache2" ;;
        2) servicio="nginx"   ;;
        3) servicio="tomcat9" ;;
        4) servicio="vsftpd"  ;;
        *) echo "Inválido"; sleep 1; return ;;
    esac

    # Verificar si ya está instalado
    if dpkg -l "$servicio" 2>/dev/null | grep -q '^ii'; then
        echo -e "${G}$servicio ya está instalado.${W}"
        read -rp "¿Desea reconfigurar el puerto/DocumentRoot? [S/N]: " reconf
        [[ "${reconf^^}" == "S" ]] && _configurar_servicio "$servicio" "$sel_svc"
    else
        _instalar_desde_web "$servicio" "$sel_svc"
    fi

    # Preguntar SSL al terminar
    echo ""
    read -rp "¿Desea activar SSL/TLS en $servicio? [S/N]: " activar_ssl
    [[ "${activar_ssl^^}" == "S" ]] && configurar_ssl "$servicio"
}

_configurar_servicio() {
    local servicio=$1 sel=$2
    titulo "RECONFIGURANDO — $servicio"
    local puerto
    case $sel in
        1)
            while true; do read -rp "Nuevo puerto para Apache2: " puerto; validar_puerto "$puerto" && break; done
            sudo sed -i '/^Listen/d' /etc/apache2/ports.conf
            echo "Listen $puerto" | sudo tee -a /etc/apache2/ports.conf > /dev/null
            sudo sed -i "s|<VirtualHost \*:[0-9]*>|<VirtualHost *:$puerto>|g" \
                /etc/apache2/sites-available/000-default.conf
            configurar_firewall_linux "$puerto"
            sudo systemctl restart apache2
            log_ok "Apache2 reconfigurado en puerto $puerto"
            ;;
        2)
            while true; do read -rp "Nuevo puerto para Nginx: " puerto; validar_puerto "$puerto" && break; done
            sudo sed -i "s/listen [0-9]\+ default_server;/listen $puerto default_server;/g" \
                /etc/nginx/sites-available/default
            sudo sed -i "s/listen \[::\]:[0-9]\+ default_server;/listen [::]:$puerto default_server;/g" \
                /etc/nginx/sites-available/default
            configurar_firewall_linux "$puerto"
            sudo systemctl restart nginx
            log_ok "Nginx reconfigurado en puerto $puerto"
            ;;
        3)
            while true; do read -rp "Nuevo puerto para Tomcat: " puerto; validar_puerto "$puerto" && break; done
            sudo sed -i "s/Connector port=\"[0-9]*\"/Connector port=\"$puerto\"/g" \
                /etc/tomcat9/server.xml
            configurar_firewall_linux "$puerto"
            sudo systemctl restart tomcat9
            log_ok "Tomcat reconfigurado en puerto $puerto"
            ;;
        4)
            echo -e "${Y}Reaplicando configuración vsftpd...${W}"
            servicios
            log_ok "vsftpd reconfigurado"
            ;;
    esac
}

_instalar_desde_web() {
    local servicio=$1 sel=$2
    titulo "INSTALACIÓN VÍA WEB — $servicio"
    case $sel in
        1)
            local ver; ver=$(seleccionar_version "apache2")
            local puerto
            while true; do read -rp "Puerto para Apache2: " puerto; validar_puerto "$puerto" && break; done
            instalar_apache "$ver" "$puerto"
            ;;
        2)
            local ver; ver=$(seleccionar_version "nginx")
            local puerto
            while true; do read -rp "Puerto para Nginx: " puerto; validar_puerto "$puerto" && break; done
            instalar_nginx "$ver" "$puerto"
            ;;
        3)
            local ver; ver=$(seleccionar_version_tomcat)
            local puerto
            while true; do read -rp "Puerto para Tomcat: " puerto; validar_puerto "$puerto" && break; done
            instalar_tomcat "$ver" "$puerto"
            ;;
        4)
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y vsftpd > /dev/null
            servicios
            echo -e "${G}vsftpd instalado y configurado.${W}"
            ;;
    esac
}
configurar_ssl() {
    local servicio=$1
    titulo "CONFIGURANDO SSL/TLS — $servicio"

    sudo mkdir -p "$SSL_DIR"
    local cert="$SSL_DIR/${servicio}.crt"
    local key="$SSL_DIR/${servicio}.key"

    echo -e "${Y}Generando certificado autofirmado para $DOMAIN...${W}"
    sudo openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$key" \
        -out "$cert" \
        -subj "/C=MX/ST=Sinaloa/L=LosMochis/O=Practica7/CN=www.$DOMAIN" \
        2>/dev/null

    if [ $? -eq 0 ]; then
        log_ok "Certificado generado: $cert"
    else
        log_err "Falló la generación del certificado para $servicio"; return 1
    fi

    case $servicio in
        apache2)  _ssl_apache  "$cert" "$key" ;;
        nginx)    _ssl_nginx   "$cert" "$key" ;;
        tomcat9)  _ssl_tomcat  "$cert" "$key" ;;
        vsftpd)   _ssl_vsftpd  "$cert" "$key" ;;
        *)        echo -e "${R}Servicio no reconocido para SSL.${W}" ;;
    esac
}

_ssl_apache() {
    local cert=$1 key=$2
    echo -e "${Y}Configurando SSL en Apache2...${W}"

    sudo a2enmod ssl headers rewrite > /dev/null 2>&1

    if ! grep -q "Listen 443" /etc/apache2/ports.conf; then
        echo "Listen 443" | sudo tee -a /etc/apache2/ports.conf > /dev/null
    fi

    sudo bash -c "cat > /etc/apache2/sites-available/ssl-practica7.conf" <<EOF
<VirtualHost *:443>
    ServerName www.$DOMAIN
    DocumentRoot /var/www/apache

    SSLEngine on
    SSLCertificateFile    $cert
    SSLCertificateKeyFile $key

    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
</VirtualHost>
EOF
    if ! grep -q "RewriteRule.*https" /etc/apache2/sites-available/000-default.conf 2>/dev/null; then
        sudo bash -c "cat >> /etc/apache2/sites-available/000-default.conf" <<'EOF'

<VirtualHost *:80>
    ServerName www.reprobados.com
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>
EOF
    fi

    sudo a2ensite ssl-practica7 > /dev/null 2>&1
    sudo systemctl restart apache2

    if sudo systemctl is-active --quiet apache2; then
        log_ok "Apache2 SSL activo en puerto 443"
    else
        log_err "Apache2 no pudo reiniciar con SSL"
        sudo apache2ctl -t 2>&1 | tail -5
    fi
}

_ssl_nginx() {
    local cert=$1 key=$2
    echo -e "${Y}Configurando SSL en Nginx...${W}"
    local puerto_http
    puerto_http=$(grep -rh "listen [0-9]" /etc/nginx/sites-available/default \
                  /etc/nginx/sites-available/ssl-practica7 2>/dev/null \
                  | grep -v ssl | grep -oP 'listen \K[0-9]+' | grep -v '^443$' | grep -v '^80$' | head -1)
    [[ -z "$puerto_http" ]] && puerto_http=8081
    local puerto_https=$(( puerto_http + 363 ))

    echo -e "${Y}  Nginx usara HTTP:$puerto_http  HTTPS:$puerto_https${W}"
    sudo sed -i "s/listen [0-9]\+ default_server;/listen $puerto_http default_server;/g" \
        /etc/nginx/sites-available/default 2>/dev/null
    sudo sed -i "s/listen \[::\]:[0-9]\+ default_server;/listen [::]:$puerto_http default_server;/g" \
        /etc/nginx/sites-available/default 2>/dev/null

    sudo ufw allow "$puerto_http"/tcp  > /dev/null
    sudo ufw allow "$puerto_https"/tcp > /dev/null

    sudo tee /etc/nginx/sites-available/ssl-practica7 > /dev/null << EOF
server {
    listen $puerto_http;
    server_name www.$DOMAIN;
    return 301 https://\$host:$puerto_https\$request_uri;
}

server {
    listen $puerto_https ssl;
    server_name www.$DOMAIN;

    ssl_certificate     $cert;
    ssl_certificate_key $key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    root /var/www/nginx;
    index index.html;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF

    sudo ln -sf /etc/nginx/sites-available/ssl-practica7 \
                /etc/nginx/sites-enabled/ssl-practica7 2>/dev/null
    sudo systemctl restart nginx

    if sudo systemctl is-active --quiet nginx; then
        log_ok "Nginx SSL activo — HTTP:$puerto_http HTTPS:$puerto_https"
    else
        log_err "Nginx no pudo reiniciar con SSL"
        sudo nginx -t 2>&1 | tail -5
    fi
}

_ssl_tomcat() {
    local cert=$1 key=$2
    echo -e "${Y}Configurando SSL en Tomcat...${W}"

    local tomcat_conf="/etc/tomcat9/server.xml"
    local keystore="$SSL_DIR/tomcat.p12"

    sudo openssl pkcs12 -export \
        -in "$cert" -inkey "$key" \
        -out "$keystore" \
        -name tomcat \
        -passout pass:practica7 2>/dev/null

    if ! grep -q "port=\"8443\"" "$tomcat_conf" 2>/dev/null; then
        sudo sed -i "/<\/Service>/i \\
    <Connector port=\"8443\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\"\\
               maxThreads=\"150\" SSLEnabled=\"true\">\\
        <SSLHostConfig>\\
            <Certificate certificateKeystoreFile=\"$keystore\"\\
                         certificateKeystorePassword=\"practica7\"\\
                         certificateKeystoreType=\"PKCS12\" />\\
        </SSLHostConfig>\\
    </Connector>" "$tomcat_conf"
    fi

    local webxml="/etc/tomcat9/web.xml"
    if ! grep -q "transport-guarantee" "$webxml" 2>/dev/null; then
        sudo sed -i "/<\/web-app>/i \\
    <security-constraint>\\
        <web-resource-collection><web-resource-name>all</web-resource-name>\\
            <url-pattern>/*</url-pattern></web-resource-collection>\\
        <user-data-constraint>\\
            <transport-guarantee>CONFIDENTIAL</transport-guarantee>\\
        </user-data-constraint>\\
    </security-constraint>" "$webxml"
    fi

    sudo systemctl restart tomcat9
    if sudo systemctl is-active --quiet tomcat9; then
        log_ok "Tomcat SSL activo en puerto 8443"
    else
        log_err "Tomcat no pudo reiniciar con SSL"
        sudo journalctl -u tomcat9 --no-pager | tail -10
    fi
}

_ssl_vsftpd() {
    local cert=$1 key=$2
    echo -e "${Y}Configurando FTPS (SSL) en vsftpd...${W}"

    sudo sed -i '/^ssl_enable/d; /^rsa_cert_file/d; /^rsa_private_key_file/d
                 /^ssl_tlsv1/d; /^ssl_sslv2/d; /^ssl_sslv3/d
                 /^force_local_data_ssl/d; /^force_local_logins_ssl/d
                 /^require_ssl_reuse/d; /^ssl_ciphers/d' /etc/vsftpd.conf

    cat <<EOF | sudo tee -a /etc/vsftpd.conf > /dev/null

# ── SSL/TLS (FTPS) ──────────────────────────────
ssl_enable=YES
rsa_cert_file=$cert
rsa_private_key_file=$key
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
require_ssl_reuse=NO
ssl_ciphers=HIGH
EOF

    sudo systemctl restart vsftpd
    if sudo systemctl is-active --quiet vsftpd; then
        log_ok "vsftpd FTPS (SSL) activo"
    else
        log_err "vsftpd no pudo reiniciar con SSL"
        sudo journalctl -u vsftpd --no-pager | tail -10
    fi
}

ssl_masivo() {
    titulo "SSL/TLS MASIVO — todos los servicios instalados"
    local SERVICIOS=("apache2" "nginx" "tomcat9" "vsftpd")
    for svc in "${SERVICIOS[@]}"; do
        if dpkg -l "$svc" 2>/dev/null | grep -q '^ii'; then
            echo -e "\n${C}--- $svc ---${W}"
            read -rp "¿Activar SSL en $svc? [S/N]: " resp
            [[ "${resp^^}" == "S" ]] && configurar_ssl "$svc"
        else
            echo -e "${Y}[OMITIDO] $svc no está instalado.${W}"
        fi
    done
    pausa
}
mostrar_resumen() {
    titulo "RESUMEN DE VERIFICACIÓN AUTOMÁTICA"
    : > "$LOG_RESUMEN"

    echo -e "${B}═══ ESTADO DE SERVICIOS ═══${W}"
    for svc in apache2 nginx tomcat9 vsftpd; do
        if sudo systemctl is-active --quiet "$svc" 2>/dev/null; then
            log_ok "$svc — ACTIVO"
        elif dpkg -l "$svc" 2>/dev/null | grep -q '^ii'; then
            log_err "$svc — INSTALADO pero INACTIVO"
        else
            log_inf "$svc — NO INSTALADO"
        fi
    done

    echo -e "\n${B}═══ VERIFICACIÓN SSL/TLS ═══${W}"
    local apache_activo=false nginx_activo=false
    sudo systemctl is-active --quiet apache2 2>/dev/null && apache_activo=true
    sudo systemctl is-active --quiet nginx   2>/dev/null && nginx_activo=true
    if $apache_activo && $nginx_activo; then
        log_err "CONFLICTO: Apache2 y Nginx están activos al mismo tiempo en puerto 443"
        echo -e "    ${Y}→ Solo uno puede escuchar en 443. Detenga uno antes de activar SSL.${W}"
    fi
    for puerto in 443; do
        local resultado
        resultado=$(echo | openssl s_client -connect "127.0.0.1:$puerto" \
                    -servername "www.$DOMAIN" 2>/dev/null \
                    | openssl x509 -noout -subject -dates 2>/dev/null)
        if [ -n "$resultado" ]; then
            log_ok "Puerto $puerto (HTTPS): Certificado SSL válido"
            echo "$resultado" | sed 's/^/    /'
        else
            log_err "Puerto $puerto (HTTPS): Sin respuesta SSL"
        fi
    done

    local resultado
    resultado=$(echo | openssl s_client -connect "127.0.0.1:8443" 2>/dev/null \
                | openssl x509 -noout -subject 2>/dev/null)
    [ -n "$resultado" ] && log_ok "Puerto 8443 (Tomcat HTTPS): Certificado SSL válido" \
                        || log_err "Puerto 8443 (Tomcat HTTPS): Sin respuesta SSL"

    if sudo systemctl is-active --quiet vsftpd 2>/dev/null; then
        local ftps
        ftps=$(echo | timeout 5 openssl s_client -connect "127.0.0.1:21" \
               -starttls ftp 2>/dev/null | grep "Cipher is")
        [ -n "$ftps" ] && log_ok "Puerto 21 FTPS (STARTTLS): $ftps" \
                       || log_err "Puerto 21 FTPS: Sin cifrado detectado"
    fi

    echo -e "\n${B}═══ CERTIFICADOS GENERADOS ═══${W}"
    if [ -d "$SSL_DIR" ]; then
        for crt in "$SSL_DIR"/*.crt; do
            [ -f "$crt" ] || continue
            local cn exp
            cn=$(openssl x509 -noout -subject -in "$crt" 2>/dev/null | sed 's/.*CN=//')
            exp=$(openssl x509 -noout -enddate -in "$crt" 2>/dev/null | sed 's/notAfter=//')
            log_ok "$(basename "$crt") → CN=$cn | Expira: $exp"
        done
    else
        log_inf "No se han generado certificados aún."
    fi

    echo -e "\n${B}═══ PUERTOS ACTIVOS ═══${W}"
    sudo ss -tulpn | grep -E ':80|:443|:21|:8443|:8080|:990' \
    | awk '{split($5,a,":"); print "  Puerto " a[length(a)] " — " $1 " — " $7}' \
    | sort -t' ' -k2 -n | uniq

    echo -e "\n${G}Resumen guardado en: $LOG_RESUMEN${W}"
    pausa
}
while true; do
    clear
    echo -e "${B}╔══════════════════════════════════════════╗${W}"
    echo -e "${B}║   PRÁCTICA 7 — Orquestador Linux         ║${W}"
    echo -e "${B}║   SSL/TLS + FTP Dinámico + Integridad     ║${W}"
    echo -e "${B}╚══════════════════════════════════════════╝${W}"
    echo ""
    echo -e "  ${C}1)${W} Instalar servicio vía WEB  (apt)"
    echo -e "  ${C}2)${W} Instalar servicio vía FTP  (repositorio privado)"
    echo -e "  ${C}3)${W} Activar SSL/TLS en todos los servicios"
    echo -e "  ${C}4)${W} Activar SSL/TLS en un servicio específico"
    echo -e "  ${C}5)${W} Resumen y verificación automática"
    echo -e "  ${C}6)${W} Salir"
    echo ""
    read -rp "  OPCIÓN: " opc

    case $opc in
        1)
            titulo "INSTALACIÓN VÍA WEB"
            echo "  1) Apache2  2) Nginx  3) Tomcat  4) vsftpd"
            read -rp "Servicio: " sel_svc
            servicio=""
            case $sel_svc in
                1) servicio="apache2" ;;
                2) servicio="nginx"   ;;
                3) servicio="tomcat9" ;;
                4) servicio="vsftpd"  ;;
                *) echo "Inválido"; sleep 1; continue ;;
            esac
            if dpkg -l "$servicio" 2>/dev/null | grep -q '^ii'; then
                echo -e "${G}$servicio ya está instalado.${W}"
                read -rp "¿Reconfigurar puerto? [S/N]: " reconf
                [[ "${reconf^^}" == "S" ]] && _configurar_servicio "$servicio" "$sel_svc"
            else
                _instalar_desde_web "$servicio" "$sel_svc"
            fi
            echo ""
            read -rp "¿Activar SSL/TLS en $servicio? [S/N]: " activar_ssl
            [[ "${activar_ssl^^}" == "S" ]] && configurar_ssl "$servicio"
            pausa
            ;;
        2)
            sudo bash "$SCRIPT_DIR/linux/ftp.sh"
            ;;
        3) ssl_masivo ;;
        4)
            titulo "SSL SERVICIO ESPECÍFICO"
            echo "1) apache2  2) nginx  3) tomcat9  4) vsftpd"
            read -rp "Servicio: " s
            case $s in
                1) configurar_ssl "apache2" ;;
                2) configurar_ssl "nginx"   ;;
                3) configurar_ssl "tomcat9" ;;
                4) configurar_ssl "vsftpd"  ;;
                *) echo "Inválido" ;;
            esac
            pausa
            ;;
        5) mostrar_resumen ;;
        6) echo -e "${G}Saliendo...${W}"; exit 0 ;;
        *) echo "Opción no válida"; sleep 1 ;;
    esac
done