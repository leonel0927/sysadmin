#!/bin/bash
source /home/srv-linux-server/SCRIPS2/FUNCIONES/instalacion.sh
source /home/srv-linux-server/SCRIPS2/FUNCIONES/status.sh
source /home/srv-linux-server/SCRIPS2/linux/httpF.sh

FTP_IP="192.168.117.10"
FTP_REPO_HTTP="/servidores"
SSL_DIR="/etc/ssl/practica7"
DOMAIN="reprobados.com"
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[0m'

instalar(){
    verificacion_instalacion "vsftpd"
}

verificar(){
    verificador_status "vsftpd"
}

archivos(){
    Entrada="/srv/ftp"
    Genera="$Entrada/general"
    gruposC="$Entrada/grupos"
    GRUPOS=("reprobados" "recursadores")
    sudo groupadd -f reprobados
    sudo groupadd -f recursadores
    [ ! -d "$Entrada" ] && sudo mkdir -p "$Entrada"
    [ ! -d "$Genera" ] && sudo mkdir -p "$Genera"
    [ ! -d "$gruposC" ] && sudo mkdir -p "$gruposC"
    sudo chown root:root "$Entrada"
    sudo chmod 755 "$Entrada"
    sudo chown ftp:nogroup "$Genera"
    sudo chmod 777 "$Genera"
    sudo chown root:root "$gruposC"
    sudo chmod 711 "$gruposC"
    for grupo in "${GRUPOS[@]}"; do
        [ ! -d "$gruposC/$grupo" ] && sudo mkdir -p "$gruposC/$grupo"
        sudo chown ftp:$grupo "$gruposC/$grupo"
        sudo chmod 775 "$gruposC/$grupo"
    done

    for repo_dir in "$Entrada/servidores/Linux/Apache" \
                    "$Entrada/servidores/Linux/Nginx"   \
                    "$Entrada/servidores/Linux/Tomcat"  \
                    "$Entrada/servidores/Linux/vsftpd"; do
        [ ! -d "$repo_dir" ] && sudo mkdir -p "$repo_dir" && echo "  Creada: $repo_dir"
    done
    sudo groupadd -f ftphttp
    [ -d "$Entrada/servidores" ] && sudo chown -R root:ftphttp "$Entrada/servidores" \
                                 && sudo chmod -R 775 "$Entrada/servidores"
}

agg_users(){
    read -p "Cuántos usuarios desea agregar?: " users
    for ((i=1; i<=$users; i++))
    do
        echo -e "\n-----------------------------------"
        read -p "Ingrese el nombre del usuario: " nomU
        read -s -p "Ingrese la contraseña: " keyU
        echo ""
        while true; do
            echo "1) Reprobados | 2) Recursadores"
            read -p "Opción: " opc
            [[ "$opc" == "1" ]] && { gpp="reprobados"; break; }
            [[ "$opc" == "2" ]] && { gpp="recursadores"; break; }
        done

        read -p "¿Este usuario tendrá acceso al repositorio de servidores? [S/N]: " acc_http
        local tiene_http=false
        [[ "${acc_http^^}" == "S" ]] && tiene_http=true

        usuarioH="/home/ftpusers/$nomU"
        if ! id "$nomU" &>/dev/null; then
            sudo useradd -m -d "$usuarioH" -s /usr/sbin/nologin "$nomU"
            echo "$nomU:$keyU" | sudo chpasswd
            sudo usermod -aG "$gpp" "$nomU"
        fi
        sudo mkdir -p "$usuarioH/general" "$usuarioH/$gpp" "$usuarioH/mi_espacio"
        sudo umount -l "$usuarioH/general" 2>/dev/null
        sudo umount -l "$usuarioH/$gpp" 2>/dev/null
        sudo mount --bind /srv/ftp/general "$usuarioH/general"
        sudo mount -o remount,rw "$usuarioH/general"
        sudo mount --bind "/srv/ftp/grupos/$gpp" "$usuarioH/$gpp"
        sudo mount -o remount,rw "$usuarioH/$gpp"
        sudo sed -i "\|$usuarioH/|d" /etc/fstab
        echo "/srv/ftp/general $usuarioH/general none bind 0 0" | sudo tee -a /etc/fstab
        echo "/srv/ftp/grupos/$gpp $usuarioH/$gpp none bind 0 0" | sudo tee -a /etc/fstab

        if $tiene_http; then
            sudo mkdir -p "$usuarioH/servidores"
            if ! mountpoint -q "$usuarioH/servidores" 2>/dev/null; then
                sudo umount -l "$usuarioH/servidores" 2>/dev/null
                sudo mount --bind /srv/ftp/servidores/Linux "$usuarioH/servidores"
                sudo mount -o remount,rw "$usuarioH/servidores"
            fi
            if ! grep -q "$usuarioH/servidores" /etc/fstab; then
                echo "/srv/ftp/servidores/Linux $usuarioH/servidores none bind 0 0" | sudo tee -a /etc/fstab
            fi
            sudo usermod -aG ftphttp "$nomU"
            echo -e "  ${G}→ Acceso al repositorio de servidores habilitado para $nomU${W}"
        fi

        sudo chown -R "$nomU:$gpp" "$usuarioH"
        sudo chmod 755 "$usuarioH"
        sudo chmod 777 "$usuarioH/general"
        grep -qxF "$nomU" /etc/vsftpd.userlist 2>/dev/null || \
            echo "$nomU" | sudo tee -a /etc/vsftpd.userlist > /dev/null
        echo -e "  ${G}→ $nomU agregado a vsftpd.userlist${W}"
    done
    read -p "PRESIONE ENTER PARA VOLVER"
}

servicios(){
    sudo rm -f /etc/vsftpd.conf
    cat <<EOF | sudo tee /etc/vsftpd.conf > /dev/null
listen=NO
listen_ipv6=YES
local_enable=YES
write_enable=YES
local_umask=000
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd

# conf anonima
anonymous_enable=YES
no_anon_password=YES
anon_root=/srv/ftp
deny_file={grupos}
hide_file={grupos}

anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO
anon_world_readable_only=YES

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

# Lista de usuarios permitidos
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
EOF

    sudo sed -i '/pam_shells.so/d' /etc/pam.d/vsftpd
    [ ! -f /etc/vsftpd.userlist ] && sudo touch /etc/vsftpd.userlist
    sudo systemctl restart vsftpd
}

reubicar(){
    clear
    read -p "Ingrese el nombre del usuario a modificar: " nomU
    if ! id "$nomU" &>/dev/null; then
        echo "ERROR: El usuario '$nomU' no existe."
        sleep 2; return
    fi
    while true; do
        echo "1) Reprobados | 2) Recursadores"
        read -p "Nuevo grupo: " opc
        [[ "$opc" == "1" ]] && { gpp="reprobados"; break; }
        [[ "$opc" == "2" ]] && { gpp="recursadores"; break; }
    done
    usuarioH="/home/ftpusers/$nomU"
    sudo umount -l "$usuarioH/reprobados"   2>/dev/null
    sudo umount -l "$usuarioH/recursadores" 2>/dev/null
    sudo umount -l "$usuarioH/general"      2>/dev/null
    sudo sed -i "\|$usuarioH/|d" /etc/fstab
    sudo rm -rf "$usuarioH/reprobados" "$usuarioH/recursadores"
    sudo usermod -g "$gpp" "$nomU"
    sudo mkdir -p "$usuarioH/general" "$usuarioH/$gpp"
    sudo mount --bind /srv/ftp/general "$usuarioH/general"
    sudo mount -o remount,rw "$usuarioH/general"
    sudo mount --bind "/srv/ftp/grupos/$gpp" "$usuarioH/$gpp"
    sudo mount -o remount,rw "$usuarioH/$gpp"
    echo "/srv/ftp/general $usuarioH/general none bind 0 0" | sudo tee -a /etc/fstab
    echo "/srv/ftp/grupos/$gpp $usuarioH/$gpp none bind 0 0" | sudo tee -a /etc/fstab
    sudo chown -R "$nomU:$gpp" "$usuarioH"
    sudo chmod 777 "$usuarioH/general"
    echo -e "Usuario $nomU reubicado"
    read -p "ENTER PARA VOLVER"
}
preparar_repositorio(){
    echo -e "\n${B}══════════════════════════════════════${W}"
    echo -e "${C}  PREPARANDO REPOSITORIO DE SERVIDORES${W}"
    echo -e "${B}══════════════════════════════════════${W}"

    declare -A PKGS=(
        ["Apache"]="apache2"
        ["Nginx"]="nginx"
        ["Tomcat"]="tomcat9"
        ["vsftpd"]="vsftpd"
    )

    for svc in "${!PKGS[@]}"; do
        local pkg="${PKGS[$svc]}"
        local DIR="/srv/ftp/servidores/Linux/$svc"
        local DEST="$DIR/${pkg}_latest.deb"
        sudo mkdir -p "$DIR"

        if [ -f "$DEST" ] && [ -f "${DEST}.sha256" ]; then
            echo -e "${Y}  ⚠ $svc ya existe, se omite.${W}"
            continue
        fi

        echo -e "${Y}  Descargando $svc...${W}"
        cd /tmp || return
        sudo apt-get download "$pkg" 2>/dev/null
        local deb
        deb=$(ls -1t /tmp/${pkg}_*.deb 2>/dev/null | head -1)

        if [ -z "$deb" ]; then
            echo -e "${R}  No se pudo descargar $pkg${W}"
            continue
        fi

        sudo mv "$deb" "$DEST"
        sha256sum "$DEST" | sudo tee "${DEST}.sha256" > /dev/null
        echo -e "${G}  ✓ $svc → $(basename $DEST)${W}"
    done

    sudo chown -R root:ftphttp /srv/ftp/servidores
    sudo chmod -R 775 /srv/ftp/servidores
    echo -e "${G}Repositorio listo.${W}"
    read -p "PRESIONE ENTER PARA VOLVER"
}
instalar_desde_ftp(){
    echo -e "\n${B}══════════════════════════════════════${W}"
    echo -e "${C}  INSTALAR SERVIDOR DESDE FTP${W}"
    echo -e "${B}══════════════════════════════════════${W}"

    read -rp "Usuario FTP: " ftp_user
    read -rsp "Contraseña FTP: " ftp_pass; echo ""

    echo -e "\n${Y}Servidores disponibles en el repositorio:${W}"
    mapfile -t CARPETAS < <(
        curl -s --list-only \
             -u "$ftp_user:$ftp_pass" \
             "ftp://$FTP_IP$FTP_REPO_HTTP/" 2>/dev/null \
        | grep -v '^\.' | tr -d '\r'
    )

    if [ ${#CARPETAS[@]} -eq 0 ]; then
        echo -e "${R}No se encontraron servidores en el repositorio.${W}"
        read -rp "¿Desea preparar el repositorio ahora? [S/N]: " prep
        [[ "${prep^^}" == "S" ]] && preparar_repositorio
        read -p "PRESIONE ENTER PARA VOLVER"; return
    fi

    for i in "${!CARPETAS[@]}"; do
        echo "  $((i+1))) ${CARPETAS[$i]}"
    done

    local sel_svc
    while true; do
        read -rp "Seleccione el servidor [1-${#CARPETAS[@]}]: " sel_svc
        [[ "$sel_svc" =~ ^[0-9]+$ ]] && \
        [ "$sel_svc" -ge 1 ] && \
        [ "$sel_svc" -le "${#CARPETAS[@]}" ] && break
        echo "Opción inválida."
    done

    local svc_dir="${CARPETAS[$((sel_svc-1))]}"
    local ruta_svc="$FTP_REPO_HTTP/$svc_dir"

    # Listar archivos .deb
    echo -e "\n${Y}Archivos disponibles en $svc_dir:${W}"
    mapfile -t ARCHIVOS < <(
        curl -s --list-only \
             -u "$ftp_user:$ftp_pass" \
             "ftp://$FTP_IP$ruta_svc/" 2>/dev/null \
        | grep -E '\.(deb|tar\.gz|tgz)$' | tr -d '\r'
    )

    if [ ${#ARCHIVOS[@]} -eq 0 ]; then
        echo -e "${R}No hay instaladores en $ruta_svc${W}"
        read -p "PRESIONE ENTER PARA VOLVER"; return
    fi

    for i in "${!ARCHIVOS[@]}"; do
        echo "  $((i+1))) ${ARCHIVOS[$i]}"
    done

    local sel_arch
    while true; do
        read -rp "Seleccione el archivo [1-${#ARCHIVOS[@]}]: " sel_arch
        [[ "$sel_arch" =~ ^[0-9]+$ ]] && \
        [ "$sel_arch" -ge 1 ] && \
        [ "$sel_arch" -le "${#ARCHIVOS[@]}" ] && break
        echo "Opción inválida."
    done

    local archivo="${ARCHIVOS[$((sel_arch-1))]}"
    local destino_local="/tmp/$archivo"
    local destino_hash="/tmp/${archivo}.sha256"

    # Descargar binario
    echo -e "\n${Y}Descargando $archivo...${W}"
    curl -s -u "$ftp_user:$ftp_pass" \
         "ftp://$FTP_IP$ruta_svc/$archivo" -o "$destino_local"
    if [ $? -ne 0 ] || [ ! -f "$destino_local" ]; then
        echo -e "${R}Error al descargar $archivo${W}"
        read -p "PRESIONE ENTER PARA VOLVER"; return
    fi

    echo -e "${Y}Verificando integridad SHA256...${W}"
    curl -s -u "$ftp_user:$ftp_pass" \
         "ftp://$FTP_IP$ruta_svc/${archivo}.sha256" -o "$destino_hash"

    if [ ! -f "$destino_hash" ]; then
        echo -e "${R}No se encontró el .sha256. Abortando.${W}"
        read -p "PRESIONE ENTER PARA VOLVER"; return
    fi

    local hash_esperado hash_real
    hash_esperado=$(awk '{print $1}' "$destino_hash")
    hash_real=$(sha256sum "$destino_local" | awk '{print $1}')

    if [ "$hash_real" != "$hash_esperado" ]; then
        echo -e "${R}⚠ INTEGRIDAD FALLIDA — Archivo CORRUPTO. Se elimina.${W}"
        rm -f "$destino_local" "$destino_hash"
        read -p "PRESIONE ENTER PARA VOLVER"; return
    fi
    echo -e "${G}✓ Hash verificado correctamente.${W}"

    local pkg
    case $svc_dir in
        Apache) pkg="apache2" ;;
        Nginx)  pkg="nginx"   ;;
        Tomcat) pkg="tomcat9" ;;
        vsftpd) pkg="vsftpd"  ;;
    esac

    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        echo -e "${G}$pkg ya está instalado.${W}"
    else
        echo -e "\n${Y}Instalando $archivo...${W}"
        sudo DEBIAN_FRONTEND=noninteractive dpkg -i "$destino_local" 2>/dev/null
        sudo apt-get install -f -y > /dev/null
        echo -e "${G}✓ $svc_dir instalado correctamente.${W}"
    fi

    local puerto
    case $svc_dir in
        Apache)
            while true; do read -rp "Puerto para Apache2: " puerto; validar_puerto "$puerto" && break; done
            sudo sed -i '/^Listen/d' /etc/apache2/ports.conf
            echo "Listen $puerto" | sudo tee -a /etc/apache2/ports.conf > /dev/null
            sudo sed -i "s|<VirtualHost \*:[0-9]*>|<VirtualHost *:$puerto>|g" \
                /etc/apache2/sites-available/000-default.conf
            aplicar_hardening_linux "apache2"
            generar_index_personalizado "Apache2" "desde-FTP" "$puerto" "/var/www/apache"
            configurar_permisos_usuario "www-data" "/var/www/apache"
            configurar_firewall_linux "$puerto"
            configurar_firewall_ssl "apache2"
            sudo systemctl restart apache2
            echo -e "${G}Apache2 listo en puerto $puerto${W}"
            ;;
        Nginx)
            while true; do read -rp "Puerto para Nginx: " puerto; validar_puerto "$puerto" && break; done
            sudo sed -i "s/listen [0-9]\+ default_server;/listen $puerto default_server;/g" \
                /etc/nginx/sites-available/default
            sudo sed -i "s/listen \[::\]:[0-9]\+ default_server;/listen [::]:$puerto default_server;/g" \
                /etc/nginx/sites-available/default
            sudo sed -i "s|root /var/www/html;|root /var/www/nginx;|g" \
                /etc/nginx/sites-available/default
            aplicar_hardening_linux "nginx"
            generar_index_personalizado "Nginx" "desde-FTP" "$puerto" "/var/www/nginx"
            configurar_permisos_usuario "www-data" "/var/www/nginx"
            configurar_firewall_linux "$puerto"
            configurar_firewall_ssl "nginx"
            sudo rm -f /etc/nginx/sites-enabled/default
            sudo systemctl restart nginx
            echo -e "${G}Nginx listo en puerto $puerto${W}"
            ;;
        Tomcat)
            while true; do read -rp "Puerto para Tomcat: " puerto; validar_puerto "$puerto" && break; done
            sudo sed -i "s/Connector port=\"8080\"/Connector port=\"$puerto\"/g" \
                /etc/tomcat9/server.xml
            generar_index_personalizado "Tomcat" "desde-FTP" "$puerto" \
                "/var/lib/tomcat9/webapps/ROOT"
            sudo chown -R tomcat:tomcat /var/lib/tomcat9/webapps/ROOT
            configurar_firewall_linux "$puerto"
            configurar_firewall_ssl "tomcat9"
            sudo systemctl restart tomcat9
            echo -e "${G}Tomcat listo en puerto $puerto${W}"
            ;;
        vsftpd)
            servicios
            echo -e "${G}vsftpd instalado y configurado.${W}"
            ;;
    esac

    echo ""
    read -rp "¿Desea activar SSL/TLS en $svc_dir? [S/N]: " activar_ssl
    [[ "${activar_ssl^^}" == "S" ]] && _configurar_ssl_servicio "$svc_dir"

    read -p "PRESIONE ENTER PARA VOLVER"
}

_configurar_ssl_servicio(){
    local svc=$1
    sudo mkdir -p "$SSL_DIR"
    local servicio
    case $svc in
        Apache) servicio="apache2" ;;
        Nginx)  servicio="nginx"   ;;
        Tomcat) servicio="tomcat9" ;;
        vsftpd) servicio="vsftpd"  ;;
        *)      servicio="$svc"    ;;
    esac

    local cert="$SSL_DIR/${servicio}.crt"
    local key="$SSL_DIR/${servicio}.key"

    echo -e "${Y}Generando certificado autofirmado para $DOMAIN...${W}"
    sudo openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$key" -out "$cert" \
        -subj "/C=MX/ST=Sinaloa/L=LosMochis/O=Practica7/CN=www.$DOMAIN" \
        2>/dev/null && echo -e "${G}✓ Certificado generado${W}" \
                    || { echo -e "${R}Error generando certificado${W}"; return 1; }

    case $servicio in
        apache2) _ssl_apache  "$cert" "$key" ;;
        nginx)   _ssl_nginx   "$cert" "$key" ;;
        tomcat9) _ssl_tomcat  "$cert" "$key" ;;
        vsftpd)  _ssl_vsftpd  "$cert" "$key" ;;
    esac
}

_ssl_apache(){
    local cert=$1 key=$2
    sudo a2enmod ssl headers rewrite > /dev/null 2>&1
    grep -q "Listen 443" /etc/apache2/ports.conf || \
        echo "Listen 443" | sudo tee -a /etc/apache2/ports.conf > /dev/null
    sudo tee /etc/apache2/sites-available/ssl-practica7.conf > /dev/null <<EOF
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
    sudo tee /etc/apache2/sites-available/000-default.conf > /dev/null <<'EOF'
<VirtualHost *:80>
    ServerName www.reprobados.com
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/apache
    <Directory /var/www/apache>
        AllowOverride All
        Options -Indexes +FollowSymLinks
        Require all granted
    </Directory>
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
    sudo a2ensite ssl-practica7 > /dev/null 2>&1
    sudo systemctl restart apache2
    sudo systemctl is-active --quiet apache2 \
        && echo -e "${G}✓ Apache2 SSL activo en puerto 443${W}" \
        || { echo -e "${R}✗ Error en Apache2${W}"; sudo apache2ctl -t 2>&1 | tail -5; }
}

_ssl_nginx(){
    local cert=$1 key=$2
    local puerto_http
    puerto_http=$(grep -rh "listen [0-9]" /etc/nginx/sites-available/default \
                  /etc/nginx/sites-available/ssl-practica7 2>/dev/null \
                  | grep -v ssl | grep -oP 'listen \K[0-9]+' \
                  | grep -v '^443$' | grep -v '^80$' | head -1)
    [[ -z "$puerto_http" ]] && puerto_http=8081
    local puerto_https=$(( puerto_http + 363 ))
    sudo ufw allow "$puerto_http"/tcp  > /dev/null
    sudo ufw allow "$puerto_https"/tcp > /dev/null
    sudo tee /etc/nginx/sites-available/ssl-practica7 > /dev/null <<EOF
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
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx
    sudo systemctl is-active --quiet nginx \
        && echo -e "${G}✓ Nginx SSL activo HTTP:$puerto_http HTTPS:$puerto_https${W}" \
        || { echo -e "${R}✗ Error en Nginx${W}"; sudo nginx -t 2>&1 | tail -5; }
}

_ssl_tomcat(){
    local cert=$1 key=$2
    local keystore="$SSL_DIR/tomcat.p12"
    sudo openssl pkcs12 -export \
        -in "$cert" -inkey "$key" \
        -out "$keystore" -name tomcat \
        -passout pass:practica7 2>/dev/null
    if ! grep -q "port=\"8443\"" /etc/tomcat9/server.xml 2>/dev/null; then
        sudo sed -i "/<\/Service>/i \\
    <Connector port=\"8443\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\"\\
               maxThreads=\"150\" SSLEnabled=\"true\">\\
        <SSLHostConfig>\\
            <Certificate certificateKeystoreFile=\"$keystore\"\\
                         certificateKeystorePassword=\"practica7\"\\
                         certificateKeystoreType=\"PKCS12\" />\\
        </SSLHostConfig>\\
    </Connector>" /etc/tomcat9/server.xml
    fi
    sudo systemctl restart tomcat9
    sudo systemctl is-active --quiet tomcat9 \
        && echo -e "${G}✓ Tomcat SSL activo en puerto 8443${W}" \
        || echo -e "${R}✗ Error en Tomcat${W}"
}

_ssl_vsftpd(){
    local cert=$1 key=$2
    sudo sed -i '/^ssl_enable/d; /^rsa_cert_file/d; /^rsa_private_key_file/d
                 /^ssl_tlsv1/d; /^ssl_sslv2/d; /^ssl_sslv3/d
                 /^force_local_data_ssl/d; /^force_local_logins_ssl/d
                 /^require_ssl_reuse/d; /^ssl_ciphers/d' /etc/vsftpd.conf
    cat <<EOF | sudo tee -a /etc/vsftpd.conf > /dev/null

# SSL/TLS (FTPS)
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
    sudo systemctl is-active --quiet vsftpd \
        && echo -e "${G}✓ vsftpd FTPS activo${W}" \
        || echo -e "${R}✗ Error en vsftpd${W}"
}
archivos
servicios
sudo ufw allow 21/tcp
sudo ufw allow 40000:50000/tcp
sudo ufw reload

[[ "${SOLO_FUNCIONES}" == "1" ]] && return 0

while true; do
    clear
    echo -e "${B}╔══════════════════════════════════════════╗${W}"
    echo -e "${B}║         SERVIDOR FTP — PRÁCTICA 7        ║${W}"
    echo -e "${B}╚══════════════════════════════════════════╝${W}"
    echo ""
    echo -e "  ${C}1)${W} Instalar vsftpd"
    echo -e "  ${C}2)${W} Estado del servicio"
    echo -e "  ${C}3)${W} Agregar usuarios"
    echo -e "  ${C}4)${W} Reubicar usuario"
    echo -e "  ${C}5)${W} Preparar repositorio de servidores"
    echo -e "  ${C}6)${W} Instalar servidor desde FTP"
    echo -e "  ${C}7)${W} Salir"
    echo ""
    read -p "  OPCION: " opc
    case $opc in
        1) instalar ;;
        2) verificar ;;
        3) agg_users ;;
        4) reubicar ;;
        5) preparar_repositorio ;;
        6) instalar_desde_ftp ;;
        7) echo "Saliendo..."; exit 0 ;;
        *) echo "Opción inválida"; sleep 1 ;;
    esac
done