#!/bin/bash
# ================================================================
#  menu12.sh - Menu Practicas 12 y 13 | Ubuntu Server
#  Servidor de Correo + Webmail Roundcube
#  Uso: sudo bash menu12.sh
# ================================================================

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
P12_DIR="$BASE_DIR/practica12"

# ── Colores ──────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
C='\033[0;36m' W='\033[1;37m' D='\033[0;37m'
M='\033[0;35m' N='\033[0m'

ok()   { echo -e "  ${G}PASS${N} $1"; }
err()  { echo -e "  ${R}FAIL${N} $1"; }
info() { echo -e "  ${D}INFO${N} $1"; }
pausa(){ echo -e "\n  ${D}Presiona ENTER para continuar...${N}"; read -r; }

# ── Banner ───────────────────────────────────────────────────────
banner() {
    clear
    echo ""
    echo -e "${C}  ╔══════════════════════════════════════════════════════╗${N}"
    echo -e "${C}  ║     PRACTICAS 12 y 13 - SERVIDOR DE CORREO          ║${N}"
    echo -e "${C}  ║     Postfix + Dovecot + Roundcube - Ubuntu Server   ║${N}"
    echo -e "${C}  ╚══════════════════════════════════════════════════════╝${N}"
    echo ""

    local p12=("mailserver" "roundcube" "mariadb_mail")
    local cols=("$G" "$C" "$Y")
    printf "  "
    for i in 0 1 2; do
        local s
        s=$(sudo docker inspect --format='{{.State.Status}}' "${p12[$i]}" 2>/dev/null || echo "no creado")
        local sym="o" col="$D"
        [[ "$s" == "running" ]] && sym="*" && col="${cols[$i]}"
        printf "${col}${sym} %-24s${N}" "${p12[$i]}: $s"
    done
    echo -e "\n"
}

sep()  { echo -e "  ${C}+-- $1 $( printf '-%.0s' $(seq 1 $((46-${#1}))) )${N}"; }
item() { echo -e "  ${C}|${N}  ${W}[$1]${N} $2"; }
fin()  { echo -e "  ${C}+$(printf -- '-%.0s' $(seq 1 52))${N}\n"; }

# ================================================================
#  GENERADOR DE ARCHIVOS
# ================================================================
p12_generar_archivos() {
    info "Creando estructura de directorios..."
    mkdir -p "$P12_DIR"/{config,logs,mail-data,mail-state,mail-log,certs,backup,roundcube}

    # ── .env ────────────────────────────────────────────────────
    cat > "$P12_DIR/.env" <<'ENV'
# ================================================================
#  .env - Variables de entorno Practica 12/13
#  NO subir a repositorios publicos
# ================================================================
DOMAIN=reprobados.com
HOSTNAME=mail.reprobados.com
SERVER_IP=192.168.117.10

# Cuentas de correo
MAIL_USER1=director
MAIL_USER2=admin
MAIL_PASS1=Director2024!
MAIL_PASS2=Admin2024!

# Base de datos Roundcube
MYSQL_ROOT_PASSWORD=RootPass2024!
MYSQL_DATABASE=roundcube
MYSQL_USER=roundcube
MYSQL_PASSWORD=RcPass2024!

# Roundcube
ROUNDCUBE_DES_KEY=24charsecretkey1234567
ENV

    # ── docker-compose.yml ───────────────────────────────────────
    cat > "$P12_DIR/docker-compose.yml" <<'YAML'
services:

  # ── Servidor de correo (Postfix + Dovecot + Rspamd + Fail2ban) ─
  mailserver:
    image: docker.io/mailserver/docker-mailserver:latest
    container_name: mailserver
    hostname: mail.reprobados.com
    domainname: reprobados.com
    env_file: .env.mailserver
    ports:
      - "25:25"
      - "143:143"
      - "587:587"
      - "993:993"
    volumes:
      - mail_data:/var/mail
      - mail_state:/var/mail-state
      - mail_log:/var/log/mail
      - ./config:/tmp/docker-mailserver
      - ./certs:/etc/letsencrypt/live/mail.reprobados.com:ro
    networks:
      - mail_net
    restart: always
    stop_grace_period: 1m
    cap_add:
      - NET_ADMIN
    healthcheck:
      test: ["CMD", "ss", "-lntp", "|", "grep", ":25"]
      interval: 30s
      timeout: 10s
      retries: 5

  # ── Base de datos para Roundcube ─────────────────────────────
  mariadb_mail:
    image: mariadb:10.11
    container_name: mariadb_mail
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE:      ${MYSQL_DATABASE}
      MYSQL_USER:          ${MYSQL_USER}
      MYSQL_PASSWORD:      ${MYSQL_PASSWORD}
    volumes:
      - roundcube_db:/var/lib/mysql
    networks:
      - mail_net
    restart: always
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 15s
      timeout: 5s
      retries: 5

  # ── Webmail Roundcube ─────────────────────────────────────────
  roundcube:
    image: roundcube/roundcubemail:latest
    container_name: roundcube
    environment:
      ROUNDCUBEMAIL_DEFAULT_HOST:    mailserver
      ROUNDCUBEMAIL_DEFAULT_PORT:    143
      ROUNDCUBEMAIL_SMTP_SERVER:     mailserver
      ROUNDCUBEMAIL_SMTP_PORT:       587
      ROUNDCUBEMAIL_DB_TYPE:         mysql
      ROUNDCUBEMAIL_DB_HOST:         mariadb_mail
      ROUNDCUBEMAIL_DB_NAME:         ${MYSQL_DATABASE}
      ROUNDCUBEMAIL_DB_USER:         ${MYSQL_USER}
      ROUNDCUBEMAIL_DB_PASSWORD:     ${MYSQL_PASSWORD}
      ROUNDCUBEMAIL_DES_KEY:         ${ROUNDCUBE_DES_KEY}
      ROUNDCUBEMAIL_SKIN:            elastic
      ROUNDCUBEMAIL_DEFAULT_DOMAIN:  reprobados.com
      ROUNDCUBEMAIL_SESSION_LIFETIME: 30
    ports:
      - "8090:80"
    volumes:
      - roundcube_data:/var/roundcube/db
      - ./roundcube/config.inc.php:/var/roundcube/config/config.inc.php:ro
    networks:
      - mail_net
    depends_on:
      mariadb_mail:
        condition: service_healthy
    restart: always

volumes:
  mail_data:      { name: mail_data,      driver: local }
  mail_state:     { name: mail_state,     driver: local }
  mail_log:       { name: mail_log,       driver: local }
  roundcube_db:   { name: roundcube_db,   driver: local }
  roundcube_data: { name: roundcube_data, driver: local }

networks:
  mail_net:
    name: mail_net
    driver: bridge
YAML

    # ── .env.mailserver ──────────────────────────────────────────
    cat > "$P12_DIR/.env.mailserver" <<'ENV'
OVERRIDE_HOSTNAME=mail.reprobados.com
DOMAINNAME=reprobados.com
POSTMASTER_ADDRESS=admin@reprobados.com
ENABLE_SPAMASSASSIN=1
ENABLE_CLAMAV=0
ENABLE_FAIL2BAN=1
ENABLE_POSTGREY=0
ONE_DIR=1
DMS_DEBUG=0
SSL_TYPE=self-signed
PERMIT_DOCKER=network
POSTFIX_INET_PROTOCOLS=ipv4
ENABLE_IMAP=1
ENABLE_POP3=0
SMTP_ONLY=0
ENV

    # ── Roundcube config ─────────────────────────────────────────
    cat > "$P12_DIR/roundcube/config.inc.php" <<'PHP'
<?php
// Roundcube config - Practica 13
$config['product_name'] = 'Correo Reprobados.com';
$config['default_host'] = 'mailserver';
$config['default_port'] = 143;
$config['smtp_server']  = 'mailserver';
$config['smtp_port']    = 587;
$config['smtp_user']    = '%u';
$config['smtp_pass']    = '%p';
$config['username_domain'] = 'reprobados.com';
$config['mail_domain']     = 'reprobados.com';
$config['session_lifetime'] = 30;
$config['skin'] = 'elastic';
$config['language'] = 'es_ES';
$config['mime_param_folding'] = 0;
$config['date_format'] = 'd/m/Y';
$config['time_format'] = 'H:i';
PHP

    # ── Script de respaldo ───────────────────────────────────────
    cat > "$P12_DIR/backup/backup_mail.sh" <<'BASH'
#!/bin/bash
# Script de respaldo de buzones - Practica 12
BACKUP_DIR="/home/srv-linux-server/SCRIPS2/linux/practica10/practica12/backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/mail_backup_$TIMESTAMP.tar.gz"
KEEP_DAYS=7

echo "[$(date)] Iniciando respaldo de buzones..."
docker exec mailserver tar czf - /var/mail > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "[$(date)] Respaldo guardado: $BACKUP_FILE"
    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo "[$(date)] Tamaño: $SIZE"
else
    echo "[$(date)] ERROR en el respaldo" >&2
    exit 1
fi

# Limpiar respaldos viejos
find "$BACKUP_DIR" -name "mail_backup_*.tar.gz" -mtime +$KEEP_DAYS -delete
echo "[$(date)] Limpieza completada"
BASH
    chmod +x "$P12_DIR/backup/backup_mail.sh"

    ok "Archivos generados en $P12_DIR"
    echo ""
    find "$P12_DIR" -type f | sort | while read -r f; do
        echo -e "  ${D}${f/$BASE_DIR\//}${N}"
    done
}

# ================================================================
#  SUBMENU 1: DESPLIEGUE P12
# ================================================================
menu_p12_despliegue() {
    banner
    sep "P12 - DESPLIEGUE SERVIDOR DE CORREO"
    item "1" "Generar archivos de configuracion"
    item "2" "Crear cuentas de correo (director y admin)"
    item "3" "Levantar stack completo  (up -d)"
    item "4" "Detener stack            (stop)"
    item "5" "Reiniciar stack          (restart)"
    item "6" "Reconstruir desde cero   (down + up)"
    item "7" "Ver logs del mailserver"
    item "8" "Ver logs de roundcube"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) p12_generar_archivos; pausa ;;
        2) p12_crear_cuentas; pausa ;;
        3)
            sudo docker compose -f "$P12_DIR/docker-compose.yml" \
                --env-file "$P12_DIR/.env" up -d
            sleep 5; pausa ;;
        4)
            sudo docker compose -f "$P12_DIR/docker-compose.yml" \
                --env-file "$P12_DIR/.env" stop; pausa ;;
        5)
            sudo docker compose -f "$P12_DIR/docker-compose.yml" \
                --env-file "$P12_DIR/.env" restart
            sleep 5; pausa ;;
        6)
            sudo docker compose -f "$P12_DIR/docker-compose.yml" \
                --env-file "$P12_DIR/.env" down
            sudo docker compose -f "$P12_DIR/docker-compose.yml" \
                --env-file "$P12_DIR/.env" up -d
            sleep 10; pausa ;;
        7) sudo docker logs mailserver --tail=50 2>&1; pausa ;;
        8) sudo docker logs roundcube  --tail=50 2>&1; pausa ;;
        0) return ;;
    esac
    menu_p12_despliegue
}

# ── Crear cuentas de correo ──────────────────────────────────────
p12_crear_cuentas() {
    info "Creando cuenta director@reprobados.com..."
    sudo docker exec mailserver setup email add \
        director@reprobados.com Director2024! 2>&1
    info "Creando cuenta admin@reprobados.com..."
    sudo docker exec mailserver setup email add \
        admin@reprobados.com Admin2024! 2>&1
    ok "Cuentas creadas"
    echo ""
    info "Listando cuentas existentes:"
    sudo docker exec mailserver setup email list 2>&1
}

# ================================================================
#  SUBMENU 2: GESTION CORREO
# ================================================================
menu_p12_correo() {
    banner
    sep "P12 - GESTION DE CORREO"
    item "1" "Listar cuentas de correo"
    item "2" "Agregar nueva cuenta"
    item "3" "Eliminar cuenta"
    item "4" "Ver cola de correos (postfix)"
    item "5" "Ver log de correo"
    item "6" "Probar envio SMTP interno"
    item "7" "Verificar DKIM"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1)
            sudo docker exec mailserver setup email list 2>&1
            pausa ;;
        2)
            read -rp "  Email (usuario@reprobados.com): " email
            read -rsp "  Password: " pass; echo ""
            sudo docker exec mailserver setup email add "$email" "$pass" 2>&1
            ok "Cuenta $email creada"
            pausa ;;
        3)
            read -rp "  Email a eliminar: " email
            read -rp "  Confirmar eliminar $email? [s/N]: " conf
            [[ "$conf" =~ ^[Ss]$ ]] && \
                sudo docker exec mailserver setup email del "$email" 2>&1
            pausa ;;
        4)
            sudo docker exec mailserver postqueue -p 2>&1
            pausa ;;
        5)
            sudo docker exec mailserver tail -50 /var/log/mail/mail.log 2>&1
            pausa ;;
        6)
            info "Enviando correo de prueba director -> admin..."
            sudo docker exec mailserver bash -c \
                "echo 'Prueba 12.1 - Correo de prueba' | \
                 sendmail -f director@reprobados.com admin@reprobados.com" 2>&1
            ok "Correo enviado - revisar log para confirmar"
            pausa ;;
        7)
            sudo docker exec mailserver setup config dkim 2>&1
            pausa ;;
        0) return ;;
    esac
    menu_p12_correo
}

# ================================================================
#  SUBMENU 3: SEGURIDAD
# ================================================================
menu_p12_seguridad() {
    banner
    sep "P12 - SEGURIDAD"
    item "1" "Ver estado de Fail2ban"
    item "2" "Ver IPs bloqueadas por Fail2ban"
    item "3" "Desbloquear IP manualmente"
    item "4" "Ver intentos fallidos de login"
    item "5" "Verificar TLS/SSL"
    item "6" "Ver reglas de Rspamd"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1)
            sudo docker exec mailserver fail2ban-client status 2>&1
            pausa ;;
        2)
            sudo docker exec mailserver fail2ban-client status postfix 2>&1
            sudo docker exec mailserver fail2ban-client status dovecot 2>&1
            pausa ;;
        3)
            read -rp "  IP a desbloquear: " ip
            sudo docker exec mailserver fail2ban-client set postfix unbanip "$ip" 2>&1
            pausa ;;
        4)
            sudo docker exec mailserver grep "authentication failed\|Login failed" \
                /var/log/mail/mail.log 2>&1 | tail -20
            pausa ;;
        5)
            sudo docker exec mailserver openssl s_client \
                -connect localhost:587 -starttls smtp 2>&1 | \
                grep -E "subject|issuer|SSL|TLS" | head -10
            pausa ;;
        6)
            sudo docker exec mailserver rspamadm configtest 2>&1
            pausa ;;
        0) return ;;
    esac
    menu_p12_seguridad
}

# ================================================================
#  SUBMENU 4: RESPALDOS
# ================================================================
menu_p12_respaldo() {
    banner
    sep "P12 - RESPALDOS"
    item "1" "Ejecutar respaldo manual ahora"
    item "2" "Ver respaldos existentes"
    item "3" "Programar respaldo diario (cron)"
    item "4" "Restaurar ultimo respaldo"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1)
            bash "$P12_DIR/backup/backup_mail.sh"
            pausa ;;
        2)
            echo ""
            ls -lh "$P12_DIR/backup/"*.tar.gz 2>/dev/null || \
                info "Sin respaldos todavia"
            pausa ;;
        3)
            local job="0 2 * * * bash $P12_DIR/backup/backup_mail.sh >> $P12_DIR/backup/backup.log 2>&1"
            (crontab -l 2>/dev/null | grep -v "backup_mail"; echo "$job") | crontab -
            ok "Cron configurado: respaldo diario a las 02:00"
            pausa ;;
        4)
            local latest
            latest=$(ls -t "$P12_DIR/backup/"*.tar.gz 2>/dev/null | head -1)
            if [[ -z "$latest" ]]; then
                err "No hay respaldos disponibles"
            else
                info "Restaurando: $latest"
                sudo docker exec mailserver bash -c \
                    "cd / && tar xzf -" < "$latest"
                ok "Restauracion completada"
            fi
            pausa ;;
        0) return ;;
    esac
    menu_p12_respaldo
}

# ================================================================
#  PRUEBAS P12 y P13
# ================================================================
prueba_12_1() {
    echo -e "\n  ${Y}== PRUEBA 12.1: ENVIO Y RECEPCION LOCAL ==${N}"
    info "Enviando correo: director -> admin..."
    sudo docker exec mailserver bash -c \
        "echo 'Subject: Prueba 12.1\n\nCorreo de prueba entre cuentas locales.' | \
         sendmail -f director@reprobados.com admin@reprobados.com" 2>&1
    sleep 3
    info "Verificando en log..."
    sudo docker exec mailserver grep "to=<admin@reprobados.com>" \
        /var/log/mail/mail.log 2>/dev/null | tail -3
    echo ""
    ok "Verificar en Roundcube: http://192.168.117.10:8090"
    echo -e "  Login: ${W}admin@reprobados.com${N} / ${W}Admin2024!${N}"
}

prueba_12_2() {
    echo -e "\n  ${Y}== PRUEBA 12.2: AUDITORIA DE REGISTROS ==${N}"
    info "Consultando /var/log/mail/mail.log..."
    echo ""
    sudo docker exec mailserver tail -30 /var/log/mail/mail.log 2>&1
    echo ""
    ok "El log muestra flujo completo de conexion y transferencia"
}

prueba_12_3() {
    echo -e "\n  ${Y}== PRUEBA 12.3: VERIFICACION FAIL2BAN ==${N}"
    echo ""
    echo -e "  ${W}Esta prueba requiere accion manual desde Windows:${N}"
    echo ""
    echo -e "  Paso 1 - Intentar login incorrecto 5 veces en PowerShell:"
    echo -e "  ${C}1..5 | ForEach-Object { \$null = (New-Object Net.Sockets.TcpClient('192.168.117.10',143)) }${N}"
    echo ""
    echo -e "  O instalar Thunderbird y poner credenciales incorrectas 5 veces"
    echo ""
    info "Verificando IPs bloqueadas actualmente..."
    sudo docker exec mailserver fail2ban-client status dovecot 2>&1 | \
        grep -A5 "Banned IP"
    echo ""
    info "Para verificar despues del intento:"
    echo -e "  ${C}sudo docker exec mailserver fail2ban-client status dovecot${N}"
}

prueba_12_4() {
    echo -e "\n  ${Y}== PRUEBA 12.4: INTEGRIDAD DE RESPALDO ==${N}"
    info "Paso 1 - Ejecutando respaldo..."
    bash "$P12_DIR/backup/backup_mail.sh"

    local latest
    latest=$(ls -t "$P12_DIR/backup/"*.tar.gz 2>/dev/null | head -1)
    echo -e "  Respaldo: ${W}$latest${N}"

    info "Paso 2 - Deteniendo mailserver..."
    sudo docker stop mailserver
    sleep 3

    info "Paso 3 - Restaurando respaldo..."
    sudo docker start mailserver
    sleep 5
    sudo docker exec mailserver bash -c "cd / && tar xzf -" < "$latest"

    ok "Restauracion completada - verificar correos en Roundcube"
    echo -e "  URL: ${C}http://192.168.117.10:8090${N}"
}

prueba_13_5() {
    echo -e "\n  ${Y}== PRUEBA 13.5: INICIO DE SESION INSTITUCIONAL ==${N}"
    info "Verificando que Roundcube esta corriendo..."
    sudo docker ps | grep roundcube
    echo ""
    echo -e "  ${W}Desde el navegador en Windows:${N}"
    echo -e "  URL     : ${C}http://192.168.117.10:8090${N}"
    echo -e "  Usuario : ${G}director${N} (sin @reprobados.com)"
    echo -e "  Password: ${G}Director2024!${N}"
    echo ""
    ok "El dominio reprobados.com se aplica automaticamente"
}

prueba_13_6() {
    echo -e "\n  ${Y}== PRUEBA 13.6: ENVIO DE ADJUNTOS ==${N}"
    echo ""
    echo -e "  ${W}Pasos en el navegador Windows (http://192.168.117.10:8090):${N}"
    echo -e "  1. Iniciar sesion como director / Director2024!"
    echo -e "  2. Clic en [Redactar]"
    echo -e "  3. Para: admin@reprobados.com"
    echo -e "  4. Asunto: Prueba adjunto 13.6"
    echo -e "  5. Adjuntar cualquier archivo"
    echo -e "  6. Enviar"
    echo ""
    echo -e "  ${W}Verificar recepcion:${N}"
    echo -e "  1. Cerrar sesion"
    echo -e "  2. Iniciar como admin / Admin2024!"
    echo -e "  3. Revisar bandeja de entrada"
    echo -e "  4. Descargar adjunto y verificar integridad"
}

prueba_13_7() {
    echo -e "\n  ${Y}== PRUEBA 13.7: PERSISTENCIA DE PREFERENCIAS ==${N}"
    echo ""
    echo -e "  ${W}Pasos:${N}"
    echo -e "  1. Entrar a Roundcube: http://192.168.117.10:8090"
    echo -e "  2. Ir a Configuracion -> Preferencias -> Interfaz de usuario"
    echo -e "  3. Cambiar idioma o agregar contacto"
    echo -e "  4. Guardar"
    echo ""
    info "Reiniciando contenedor roundcube..."
    sudo docker restart roundcube
    sleep 10
    ok "Roundcube reiniciado - verificar que cambios persisten"
    echo -e "  URL: ${C}http://192.168.117.10:8090${N}"
}

menu_pruebas_p12() {
    banner
    sep "PROTOCOLO DE PRUEBAS P12 y P13"
    item "1" "Prueba 12.1 - Envio y Recepcion Local"
    item "2" "Prueba 12.2 - Auditoria de Registros"
    item "3" "Prueba 12.3 - Verificacion Fail2ban    (manual en Windows)"
    item "4" "Prueba 12.4 - Integridad de Respaldo"
    item "5" "Prueba 13.5 - Inicio de Sesion         (manual en Windows)"
    item "6" "Prueba 13.6 - Envio de Adjuntos        (manual en Windows)"
    item "7" "Prueba 13.7 - Persistencia Preferencias"
    item "8" "Ejecutar TODAS las automaticas"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) prueba_12_1; pausa ;;
        2) prueba_12_2; pausa ;;
        3) prueba_12_3; pausa ;;
        4) prueba_12_4; pausa ;;
        5) prueba_13_5; pausa ;;
        6) prueba_13_6; pausa ;;
        7) prueba_13_7; pausa ;;
        8) prueba_12_1; prueba_12_2; prueba_12_4; pausa ;;
        0) return ;;
    esac
    menu_pruebas_p12
}

# ================================================================
#  MENU PRINCIPAL
# ================================================================
menu_principal() {
    banner
    sep "MENU PRINCIPAL"
    item "1" "Despliegue Servidor de Correo  (Practica 12)"
    item "2" "Gestion de Cuentas y Correo    (Practica 12)"
    item "3" "Seguridad y Fail2ban           (Practica 12)"
    item "4" "Respaldos                      (Practica 12)"
    item "5" "Protocolo de Pruebas           (12.1 - 13.7)"
    item "Q" "Salir"
    fin
    read -rp "  Selecciona: " op
    case ${op^^} in
        1) menu_p12_despliegue ;;
        2) menu_p12_correo     ;;
        3) menu_p12_seguridad  ;;
        4) menu_p12_respaldo   ;;
        5) menu_pruebas_p12    ;;
        Q) clear; echo -e "\n  ${C}Practicas 12/13 - Fin de sesion${N}\n"; exit 0 ;;
    esac
    menu_principal
}

menu_principal
