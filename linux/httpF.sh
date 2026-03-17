#!/bin/bash
source /home/srv-linux-server/SCRIPS2/FUNCIONES/status.sh

listar_puertos_activos() {
    echo "==============================================="
    echo "   ESTADO DE PUERTOS Y SERVIDORES HTTP"
    echo "==============================================="
    echo -e "PROTO\tPUERTO\tSERVICIO\tPROCESO"
    echo "-----------------------------------------------"
    sudo ss -tulpn | grep -E 'apache2|nginx|java' | awk '{
        split($5, a, ":"); 
        port=a[length(a)];
        split($7, b, "\"");
        proc=b[2];
        print "TCP\t" port "\t" (proc=="java" ? "Tomcat" : proc) "\t\t[" proc "]"
    }' | sort -n -k 2 | uniq

    echo "-----------------------------------------------"
    echo "Cualquier puerto NO listado aquí está disponible."
    read -p "Presione enter para salir..." x
}

validar_puerto() {
    local puerto=$1
    if ! [[ "$puerto" =~ ^[0-9]+$ ]]; then
        echo "Error: El puerto debe ser numérico."
        return 1
    fi
    case $puerto in
        21|22|23|25|53|110|143|445|3306|5432)
            echo "Error: El puerto $puerto está reservado para servicios críticos."
            return 1
            ;;
    esac
    if sudo lsof -i :"$puerto" >/dev/null 2>&1 ; then
        echo "ERROR: EL PUERTO $puerto TIENE ACTIVIDAD O ESTA BLOQUEADO"
        return 1
    fi
    return 0
}

consultar_versiones_dinamico() {
    local servicio=$1
    echo "==============================================="
    echo " ANALIZANDO REPOSITORIOS PARA: $servicio"
    echo "==============================================="
    echo "Estado actual del paquete: "
    apt-cache policy "$servicio" | grep -E "Instalados:|Candidato:"
    echo "-----------------------------------------------"
    echo " Versiones disponibles para despliegue:"

    mapfile -t VERSIONES < <(apt-cache madison "$servicio" | awk '{print $3}')

    if [ ${#VERSIONES[@]} -eq 0 ]; then
        echo "Error: No se encontraron versiones en el repositorio."
        return 1
    fi

    echo "1) Latest (Candidata): ${VERSIONES[0]}"
    if [ ${#VERSIONES[@]} -gt 1 ]; then
        echo "2) Estable (Anterior): ${VERSIONES[1]}"
    else
        echo "2) Estable: (Misma que Latest)"
    fi
    echo "-----------------------------------------------"
}

# Nueva funcion: muestra versiones y retorna la elegida
seleccionar_version() {
    local servicio=$1

    mapfile -t VERSIONES < <(apt-cache madison "$servicio" 2>/dev/null | awk '{print $3}')

    if [ ${#VERSIONES[@]} -eq 0 ]; then
        echo "Error: No se encontraron versiones para $servicio." >&2
        return 1
    fi

    echo "" >&2
    echo "Versiones disponibles para $servicio:" >&2
    echo "  1) Latest  (Desarrollo): ${VERSIONES[0]}" >&2
    if [ ${#VERSIONES[@]} -gt 1 ]; then
        echo "  2) Estable (LTS):        ${VERSIONES[1]}" >&2
    else
        echo "  2) Estable (LTS):        ${VERSIONES[0]}  (unica disponible)" >&2
    fi
    echo "" >&2

    local opcion
    while true; do
        read -rp "Seleccione version [1/2]: " opcion >&2
        opcion="${opcion//[^0-9]/}"
        case $opcion in
            1)
                echo "${VERSIONES[0]}"
                return 0
                ;;
            2)
                if [ ${#VERSIONES[@]} -gt 1 ]; then
                    echo "${VERSIONES[1]}"
                else
                    echo "${VERSIONES[0]}"
                fi
                return 0
                ;;
            *)
                echo "Opcion invalida. Ingrese 1 o 2." >&2
                ;;
        esac
    done
}
seleccionar_version_tomcat() {
    echo "Consultando versiones disponibles de Tomcat 9..." >&2

    mapfile -t VERSIONES_TOMCAT < <(
        curl -s "https://archive.apache.org/dist/tomcat/tomcat-9/" |
        grep -oP 'v9\.\d+\.\d+' | sort -V | uniq | tail -5
    )

    if [ ${#VERSIONES_TOMCAT[@]} -eq 0 ]; then
        echo "No se pudieron obtener versiones. Usando version por defecto: 9.0.87" >&2
        echo "9.0.87"
        return 0
    fi

    echo "" >&2
    echo "Versiones disponibles para Tomcat 9:" >&2
    for i in "${!VERSIONES_TOMCAT[@]}"; do
        local etiqueta=""
        [ $i -eq 0 ] && etiqueta=" [LTS/Estable]"
        [ $i -eq $((${#VERSIONES_TOMCAT[@]}-1)) ] && etiqueta=" [Latest]"
        echo "  $((i+1))) ${VERSIONES_TOMCAT[$i]}$etiqueta" >&2
    done
    echo "" >&2

    local opcion
    while true; do
        read -rp "Seleccione numero de version [1-${#VERSIONES_TOMCAT[@]}]: " opcion >&2
        opcion="${opcion//[^0-9]/}"
        if [[ "$opcion" =~ ^[0-9]+$ ]] && [ "$opcion" -ge 1 ] && [ "$opcion" -le "${#VERSIONES_TOMCAT[@]}" ]; then
            echo "${VERSIONES_TOMCAT[$((opcion-1))]}"
            return 0
        fi
        echo "Opcion invalida." >&2
    done
}

configurar_permisos_usuario() {
    local usuario=$1; local directorio=$2
    echo "Aplicando jaula de permisos para el usuario $usuario en $directorio..."

    if ! id "$usuario" &>/dev/null; then
        sudo useradd -r -s /bin/false "$usuario" 2>/dev/null
    fi
    sudo chown -R "$usuario":"$usuario" "$directorio"
    sudo chmod -R 750 "$directorio"
}

configurar_firewall_linux() {
    local puerto=$1
    echo "Configurando UFW para el puerto $puerto..."
    sudo ufw allow 22/tcp > /dev/null
    sudo ufw allow "$puerto"/tcp > /dev/null
    echo "y" | sudo ufw enable > /dev/null
}
configurar_firewall_ssl() {
    local servicio=$1
    echo "Configurando UFW para SSL/TLS ($servicio)..."
    sudo ufw allow 443/tcp  > /dev/null   # HTTPS Apache / Nginx
    sudo ufw allow 8443/tcp > /dev/null   # HTTPS Tomcat
    sudo ufw allow 990/tcp  > /dev/null   # FTPS implícito
    sudo ufw reload > /dev/null
    echo "  → Puertos 443, 8443 y 990 abiertos en UFW"
}
# ─────────────────────────────────────────────────────────────

aplicar_hardening_linux() {
    local servicio=$1
    echo "Aplicando Hardening "
    if [[ "$servicio" == "apache2" ]]; then
        sudo sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf 2>/dev/null
        sudo sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf 2>/dev/null
        sudo sed -i '/X-Frame-Options/d' /etc/apache2/conf-available/security.conf
        sudo sed -i '/X-Content-Type-Options/d' /etc/apache2/conf-available/security.conf
        echo 'Header always set X-Frame-Options "SAMEORIGIN"' | sudo tee -a /etc/apache2/conf-available/security.conf > /dev/null
        echo 'Header always set X-Content-Type-Options "nosniff"' | sudo tee -a /etc/apache2/conf-available/security.conf > /dev/null
        sudo a2enmod headers > /dev/null
        sudo a2enconf security > /dev/null
    elif [[ "$servicio" == "nginx" ]]; then
        sudo sed -i 's/# server_tokens off;/server_tokens off;/g' /etc/nginx/nginx.conf
        echo 'add_header X-Frame-Options "SAMEORIGIN" always;' | sudo tee /etc/nginx/conf.d/security_headers.conf > /dev/null
        echo 'add_header X-Content-Type-Options "nosniff" always;' | sudo tee -a /etc/nginx/conf.d/security_headers.conf > /dev/null
    fi
}

generar_index_personalizado() {
    local servicio=$1; local version=$2; local puerto=$3; local ruta_web=$4
    local ssl_badge=""
    local ssl_puerto=""
    case $servicio in
        Apache2)
            if sudo systemctl is-active --quiet apache2 2>/dev/null && \
               sudo ss -tlpn | grep -q ':443'; then
                ssl_badge='<span class="ssl">🔒 SSL/TLS ACTIVO — Puerto 443</span>'
                ssl_puerto="443"
            fi
            ;;
        Nginx)
            if sudo systemctl is-active --quiet nginx 2>/dev/null && \
               sudo ss -tlpn | grep -q ':443'; then
                ssl_badge='<span class="ssl">🔒 SSL/TLS ACTIVO — Puerto 443</span>'
                ssl_puerto="443"
            fi
            ;;
        Tomcat)
            if sudo systemctl is-active --quiet tomcat9 2>/dev/null && \
               sudo ss -tlpn | grep -q ':8443'; then
                ssl_badge='<span class="ssl">🔒 SSL/TLS ACTIVO — Puerto 8443</span>'
                ssl_puerto="8443"
            fi
            ;;
    esac
    # ─────────────────────────────────────────────────────────

    echo "Generando página en $ruta_web/index.html..."
    sudo mkdir -p "$ruta_web"
    cat <<EOF | sudo tee "$ruta_web/index.html" > /dev/null
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Aprovisionamiento: $servicio</title>
    <style>
        body { font-family: sans-serif; text-align: center; margin-top: 50px; background-color: #f4f4f9; }
        .card { border: 1px solid #ccc; padding: 30px; display: inline-block; border-radius: 10px; background-color: #fff; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; }
        .success { color: #27ae60; font-weight: bold; }
        .ssl { color: #fff; background-color: #27ae60; padding: 4px 10px; border-radius: 5px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>HTTP</h1>
        <p><strong>Servidor:</strong> <span class="success">$servicio</span></p>
        <p><strong>Versión:</strong> $version</p>
        <p><strong>Puerto:</strong> $puerto</p>
        <hr>
    </div>
</body>
</html>
EOF
    sudo chmod 644 "$ruta_web/index.html"
}

instalar_apache() {
    local version=$1
    local puerto=$2
    local ruta_web="/var/www/apache"

    if ! validar_puerto "$puerto"; then
        echo "[ABORTADO] No se puede proceder con la instalación en el puerto $puerto."
        return 1
    fi

    echo ">>> Version seleccionada: $version <<<"

    echo "Instalando/Configurando Apache2 en puerto $puerto..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apache2="$version" > /dev/null
    echo "ServerName localhost" | sudo tee /etc/apache2/conf-available/servername.conf > /dev/null
    sudo a2enconf servername > /dev/null
    sudo sed -i '/^Listen/d' /etc/apache2/ports.conf
    echo "Listen $puerto" | sudo tee -a /etc/apache2/ports.conf > /dev/null
    sudo sed -i "s|<VirtualHost \*:[0-9]*>|<VirtualHost *:$puerto>|g" /etc/apache2/sites-available/000-default.conf
    sudo sed -i "s|DocumentRoot /var/www/[^ ]*|DocumentRoot $ruta_web|g" /etc/apache2/sites-available/000-default.conf
    aplicar_hardening_linux "apache2"
    generar_index_personalizado "Apache2" "$version" "$puerto" "$ruta_web"
    configurar_permisos_usuario "www-data" "$ruta_web"
    configurar_firewall_linux "$puerto"
    configurar_firewall_ssl "apache2"
    if ! sudo systemctl restart apache2; then
        echo "Error: Apache no pudo iniciar. Verificando logs..."
        sudo apache2ctl -t
        journalctl -u apache2 --no-pager | tail -n 10
    else
        echo "Apache $version listo en puerto $puerto (Ruta: $ruta_web)"
    fi
}

instalar_nginx() {
    local version=$1
    local puerto=$2
    local ruta_web="/var/www/nginx"

    if ! validar_puerto "$puerto"; then
        echo "[ABORTADO] No se puede proceder con la instalación en el puerto $puerto."
        return 1
    fi

    echo ">>> Version seleccionada: $version <<<"

    echo "Instalando/Configurando Nginx en puerto $puerto..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx="$version" > /dev/null
    sudo sed -i "s/listen [0-9]\+ default_server;/listen $puerto default_server;/g" /etc/nginx/sites-available/default
    sudo sed -i "s/listen \[::\]:[0-9]\+ default_server;/listen \[::\]:$puerto default_server;/g" /etc/nginx/sites-available/default
    sudo sed -i "s|root /var/www/html;|root $ruta_web;|g" /etc/nginx/sites-available/default

    aplicar_hardening_linux "nginx"
    generar_index_personalizado "Nginx" "$version" "$puerto" "$ruta_web"
    configurar_permisos_usuario "www-data" "$ruta_web"
    configurar_firewall_linux "$puerto"
    configurar_firewall_ssl "nginx"

    sudo systemctl restart nginx
    echo "Nginx $version listo en puerto $puerto"
}

instalar_tomcat() {
    local version_tomcat=$1
    local puerto=$2
    local ruta_tomcat="/var/lib/tomcat9"

    if ! validar_puerto "$puerto"; then
        echo "[ABORTADO] No se puede proceder con la instalación en el puerto $puerto."
        return 1
    fi

    echo ">>> Version seleccionada: $version_tomcat <<<"
    echo "Instalando Tomcat $version_tomcat en puerto $puerto via apt..."

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y tomcat9="$version_tomcat" tomcat9-admin > /dev/null

    sudo sed -i "s/Connector port=\"8080\"/Connector port=\"$puerto\"/g" /etc/tomcat9/server.xml

    generar_index_personalizado "Tomcat" "$version_tomcat" "$puerto" "$ruta_tomcat/webapps/ROOT"
    sudo chown -R tomcat:tomcat "$ruta_tomcat/webapps/ROOT"

    configurar_firewall_linux "$puerto"
    configurar_firewall_ssl "tomcat9"

    sudo systemctl restart tomcat9
    if sudo systemctl is-active --quiet tomcat9; then
        echo "Tomcat $version_tomcat listo en puerto $puerto"
    else
        echo "Error: Tomcat no pudo iniciar. Verificando logs..."
        journalctl -u tomcat9 --no-pager | tail -n 15
    fi
}