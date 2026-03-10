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
    </style>
</head>
<body>
    <div class="card">
        <h1>Control de Despliegue HTTP</h1>
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
    local version=$1; local puerto=$2; local ruta_web="/var/www/apache"
    if ! validar_puerto "$puerto"; then
        echo "[ABORTADO] No se puede proceder con la instalación en el puerto $puerto."
        return 1
    fi
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
        if ! sudo systemctl restart apache2; then
        echo "Error: Apache no pudo iniciar. Verificando logs..."
        sudo apache2ctl -t
        journalctl -u apache2 --no-pager | tail -n 10
    else
        echo "Apache listo en puerto $puerto (Ruta: $ruta_web)"
    fi
}

instalar_nginx() {
    local version=$1; local puerto=$2; local ruta_web="/var/www/nginx"
    echo "Instalando/Configurando Nginx en puerto $puerto..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx="$version" > /dev/null
    sudo sed -i "s/listen [0-9]\+ default_server;/listen $puerto default_server;/g" /etc/nginx/sites-available/default
    sudo sed -i "s/listen \[::\]:[0-9]\+ default_server;/listen \[::\]:$puerto default_server;/g" /etc/nginx/sites-available/default
    sudo sed -i "s|root /var/www/html;|root $ruta_web;|g" /etc/nginx/sites-available/default

    aplicar_hardening_linux "nginx"
    generar_index_personalizado "Nginx" "$version" "$puerto" "$ruta_web"
    configurar_permisos_usuario "www-data" "$ruta_web"
    configurar_firewall_linux "$puerto"
    
    sudo systemctl restart nginx
    echo "Nginx listo en puerto $puerto"
}

instalar_tomcat() {
    local puerto=$2
    local ruta_tomcat="/opt/tomcat"
    local version_tomcat="9.0.87"
    local url_tar="https://archive.apache.org/dist/tomcat/tomcat-9/v${version_tomcat}/bin/apache-tomcat-${version_tomcat}.tar.gz"

    echo "Preparando Tomcat en puerto $puerto..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y default-jdk > /dev/null
    
    if [ ! -d "$ruta_tomcat/bin" ]; then
        sudo mkdir -p "$ruta_tomcat"
        wget -q "$url_tar" -O /tmp/tomcat.tar.gz
        sudo tar xzvf /tmp/tomcat.tar.gz -C "$ruta_tomcat" --strip-components=1 > /dev/null
    fi

    sudo sed -i "s/port=\"[0-9]\+\" protocol=\"HTTP\/1.1\"/port=\"$puerto\" protocol=\"HTTP\/1.1\"/g" "$ruta_tomcat/conf/server.xml"

    sudo rm -rf "$ruta_tomcat/webapps/ROOT"
    generar_index_personalizado "Tomcat" "$version_tomcat" "$puerto" "$ruta_tomcat/webapps/ROOT"
    configurar_permisos_usuario "tomcat" "$ruta_tomcat"
    configurar_firewall_linux "$puerto"

    sudo pkill -f tomcat 2>/dev/null
    sudo -u tomcat sh "$ruta_tomcat/bin/startup.sh" > /dev/null
    echo "Tomcat listo en puerto $puerto"
}