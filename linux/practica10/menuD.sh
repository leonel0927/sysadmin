#!/bin/bash
# ================================================================
#  menu.sh - Menu Principal Practicas 10 y 11 | Ubuntu Server
#  Uso: sudo bash menu.sh
# ================================================================

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colores ──────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
C='\033[0;36m' W='\033[1;37m' D='\033[0;37m'
M='\033[0;35m' N='\033[0m'

ok()   { echo -e "  ${G}PASS${N} $1"; }
err()  { echo -e "  ${R}FAIL${N} $1"; }
info() { echo -e "  ${D}INFO${N} $1"; }
pausa(){ echo -e "\n  ${D}Presiona ENTER para continuar...${N}"; read -r; }

# ── Banner + estado de contenedores ─────────────────────────────
banner() {
    clear
    echo ""
    echo -e "${C}  ╔══════════════════════════════════════════════════════╗${N}"
    echo -e "${C}  ║       PRACTICAS 10 y 11 - CONTENEDORES DOCKER        ║${N}"
    echo -e "${C}  ║          Infraestructura - Ubuntu Server             ║${N}"
    echo -e "${C}  ╚══════════════════════════════════════════════════════╝${N}"
    echo ""

    # Practica 10
    echo -e "  ${D}[P10]${N}"
    local p10=("web_server" "postgres_db" "ftp_server")
    local c10=("$G" "$C" "$Y")
    printf "  "
    for i in 0 1 2; do
        local s
        s=$(sudo docker inspect --format='{{.State.Status}}' "${p10[$i]}" 2>/dev/null || echo "no creado")
        local sym="o" col="$D"
        [[ "$s" == "running" ]] && sym="*" && col="${c10[$i]}"
        printf "${col}${sym} %-22s${N}" "${p10[$i]}: $s"
    done
    echo ""

    # Practica 11
    echo -e "  ${D}[P11]${N}"
    local p11=("nginx_lb" "app_server" "postgres11" "pgadmin")
    local c11=("$G" "$M" "$C" "$Y")
    printf "  "
    for i in 0 1 2 3; do
        local s
        s=$(sudo docker inspect --format='{{.State.Status}}' "${p11[$i]}" 2>/dev/null || echo "no creado")
        local sym="o" col="$D"
        [[ "$s" == "running" ]] && sym="*" && col="${c11[$i]}"
        printf "${col}${sym} %-22s${N}" "${p11[$i]}: $s"
    done
    echo -e "\n"
}

sep()  { echo -e "  ${C}+-- $1 $( printf '-%.0s' $(seq 1 $((46-${#1}))) )${N}"; }
item() { echo -e "  ${C}|${N}  ${W}[$1]${N} $2"; }
fin()  { echo -e "  ${C}+$(printf -- '-%.0s' $(seq 1 52))${N}\n"; }

# ================================================================
#  SUBMENU 1: DESPLIEGUE
# ================================================================
menu_despliegue() {
    banner
    sep "DESPLIEGUE Y CONTENEDORES"
    item "1" "Ejecutar despliegue completo  (deploy.sh)"
    item "2" "Construir imagenes            (build)"
    item "3" "Levantar servicios            (up -d)"
    item "4" "Detener servicios             (stop)"
    item "5" "Reiniciar servicios           (restart)"
    item "6" "Reconstruir desde cero        (--no-cache + up)"
    item "7" "Eliminar contenedor especifico (rm -f)"
    item "8" "Eliminar TODO                 (down -v)"
    item "9" "Recargar HTML al servidor web  (docker cp)"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) bash "$BASE_DIR/deploy.sh"; pausa ;;
        2) docker compose -f "$BASE_DIR/docker-compose.yml" build; pausa ;;
        3) docker compose -f "$BASE_DIR/docker-compose.yml" up -d; sleep 3; pausa ;;
        4) docker compose -f "$BASE_DIR/docker-compose.yml" stop; pausa ;;
        5) docker compose -f "$BASE_DIR/docker-compose.yml" restart; sleep 5; pausa ;;
        6)
            docker compose -f "$BASE_DIR/docker-compose.yml" down
            docker compose -f "$BASE_DIR/docker-compose.yml" build --no-cache
            docker compose -f "$BASE_DIR/docker-compose.yml" up -d
            sleep 5; pausa ;;
        7)
            read -rp "  Contenedor [web_server/postgres_db/ftp_server]: " c
            read -rp "  Eliminar $c? [s/N]: " conf
            [[ "$conf" =~ ^[Ss]$ ]] && docker rm -f "$c" && ok "$c eliminado"
            pausa ;;
        8)
            read -rp "  Eliminar TODOS los contenedores y volumenes? [s/N]: " conf
            [[ "$conf" =~ ^[Ss]$ ]] && docker compose -f "$BASE_DIR/docker-compose.yml" down -v
            pausa ;;
        9)
            docker cp "$BASE_DIR/web/html/index.html" web_server:/var/www/localhost/htdocs/index.html
            ok "index.html copiado al contenedor web_server"
            echo -e "  URL: http://localhost:8080"
            pausa ;;
        0) return ;;
    esac
    menu_despliegue
}

# ================================================================
#  SUBMENU 2: POSTGRESQL
# ================================================================
menu_postgres() {
    banner
    sep "POSTGRESQL"
    item "1" "Consola interactiva psql"
    item "2" "Ver usuarios registrados"
    item "3" "Listar tablas"
    item "4" "Respaldo manual ahora"
    item "5" "Ver respaldos existentes"
    item "6" "Programar respaldo diario (cron)"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) docker exec -it postgres_db psql -U practica10 -d practica10_db; pausa ;;
        2)
            docker exec postgres_db psql -U practica10 -d practica10_db \
                -c "SELECT id, nombre, email, rol, activo, creado_en FROM usuarios ORDER BY id;"
            pausa ;;
        3)
            docker exec postgres_db psql -U practica10 -d practica10_db -c "\dt"
            pausa ;;
        4)
            local ts; ts=$(date +"%Y%m%d_%H%M%S")
            docker exec postgres_db sh -c \
                "PGPASSWORD='Practica10Pass!' pg_dump -U practica10 practica10_db \
                 > /backups/backup_${ts}.sql && echo 'OK'"
            ok "Respaldo guardado en postgres/backups/backup_${ts}.sql"
            pausa ;;
        5)
            echo ""
            ls -lh "$BASE_DIR/postgres/backups/" 2>/dev/null || info "Sin respaldos todavia"
            pausa ;;
        6)
            local job="0 2 * * * docker exec postgres_db sh -c \"PGPASSWORD='Practica10Pass!' pg_dump -U practica10 practica10_db > /backups/backup_auto_\$(date +\\%Y\\%m\\%d_\\%H\\%M\\%S).sql\""
            (crontab -l 2>/dev/null | grep -v "pg_dump"; echo "$job") | crontab -
            ok "Cron configurado: respaldo diario a las 02:00"
            pausa ;;
        0) return ;;
    esac
    menu_postgres
}

# ================================================================
#  SUBMENU 3: FTP
# ================================================================
menu_ftp() {
    banner
    sep "SERVIDOR FTP"
    item "1" "Ver archivos en volumen FTP"
    item "2" "Ver archivos visibles en servidor web"
    item "3" "Crear archivo de prueba en FTP"
    item "4" "Ver logs de vsftpd"
    item "5" "Mostrar credenciales FTP"
    item "6" "Shell en contenedor FTP"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) docker exec ftp_server ls -lah /ftp/uploads/; pausa ;;
        2)
            docker exec web_server ls -lah /var/www/html/uploads/
            echo -e "\n  ${C}URL: http://localhost:8080/uploads/${N}"
            pausa ;;
        3)
            local ts; ts=$(date +"%Y%m%d_%H%M%S")
            docker exec ftp_server sh -c "echo 'Prueba FTP - $ts' > /ftp/uploads/test_${ts}.txt"
            ok "Archivo creado: test_${ts}.txt"
            pausa ;;
        4) docker exec ftp_server cat /var/log/vsftpd.log 2>&1; pausa ;;
        5)
            echo ""
            echo -e "  ${C}+--------------------------------------+${N}"
            echo -e "  ${C}|${N}  Host    : localhost                  ${C}|${N}"
            echo -e "  ${C}|${N}  Puerto  : 21  (pasivo: 21100-21110)  ${C}|${N}"
            echo -e "  ${C}|${N}  ${G}Usuario : ftpadmin${N}                  ${C}|${N}"
            echo -e "  ${C}|${N}  ${G}Password: FtpPass2024!${N}              ${C}|${N}"
            echo -e "  ${C}+--------------------------------------+${N}"
            pausa ;;
        6) docker exec -it ftp_server sh; pausa ;;
        0) return ;;
    esac
    menu_ftp
}

# ================================================================
#  SUBMENU 4: REDES Y RECURSOS
# ================================================================
menu_redes() {
    banner
    sep "REDES Y RECURSOS"
    item "1" "docker stats --no-stream  (evidencia Prueba 10.4)"
    item "2" "docker stats en tiempo real"
    item "3" "Limites RAM/CPU por contenedor"
    item "4" "Inspeccionar red infra_red"
    item "5" "IPs asignadas en infra_red"
    item "6" "Ping entre contenedores   (Prueba 10.2)"
    item "7" "Ver todos los volumenes"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1)
            echo ""
            docker stats --no-stream \
                --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"
            pausa ;;
        2) docker stats ;;
        3)
            echo ""
            for c in web_server postgres_db ftp_server; do
                local mem cpu mb
                mem=$(docker inspect "$c" --format='{{.HostConfig.Memory}}' 2>/dev/null)
                cpu=$(docker inspect "$c" --format='{{.HostConfig.CpuQuota}}' 2>/dev/null)
                mb=$(( mem / 1024 / 1024 ))
                printf "  ${W}%-16s${N} RAM: ${G}%sMB${N}  CPU Quota: ${Y}%s${N}\n" "$c" "$mb" "$cpu"
            done
            pausa ;;
        4) docker network inspect infra_red; pausa ;;
        5)
            echo ""
            docker network inspect infra_red \
                --format '{{range .Containers}}  {{.Name}} -> {{.IPv4Address}}{{println}}{{end}}'
            pausa ;;
        6)
            echo -e "\n  ${C}web_server -> postgres_db:${N}"
            docker exec web_server ping -c 4 postgres_db 2>&1
            echo -e "\n  ${C}web_server -> ftp_server:${N}"
            docker exec web_server ping -c 4 ftp_server 2>&1
            pausa ;;
        7) docker volume ls; pausa ;;
        0) return ;;
    esac
    menu_redes
}

# ================================================================
#  SUBMENU 5: PRUEBAS
# ================================================================

prueba_10_1() {
    echo -e "\n  ${Y}== PRUEBA 10.1: PERSISTENCIA DE BASE DE DATOS ==${N}"
    info "Insertando registro de prueba..."
    docker exec postgres_db psql -U practica10 -d practica10_db -c \
        "INSERT INTO usuarios(nombre,email,rol) VALUES('Test Persistencia','persist@test.local','test') ON CONFLICT(email) DO NOTHING;" \
        &>/dev/null
    local antes
    antes=$(docker exec postgres_db psql -U practica10 -d practica10_db -t \
        -c "SELECT COUNT(*) FROM usuarios;" 2>/dev/null | tr -d ' ')
    echo -e "  Registros ${W}antes${N} de eliminar contenedor: ${W}$antes${N}"

    info "Ejecutando: docker rm -f postgres_db ..."
    docker rm -f postgres_db &>/dev/null
    sleep 3
    info "Recreando contenedor con volumen db_data..."
    docker compose -f "$BASE_DIR/docker-compose.yml" up -d postgres_db &>/dev/null
    sleep 15

    local despues
    despues=$(docker exec postgres_db psql -U practica10 -d practica10_db -t \
        -c "SELECT COUNT(*) FROM usuarios;" 2>/dev/null | tr -d ' ')
    echo -e "  Registros ${W}despues${N} de recrear contenedor: ${W}$despues${N}"
    echo ""
    docker exec postgres_db psql -U practica10 -d practica10_db \
        -c "SELECT id, nombre, email FROM usuarios;" 2>/dev/null

    [[ "$despues" -ge "$antes" ]] \
        && ok "Los datos persisten en el volumen db_data" \
        || err "Los datos no persistieron, revisar db_data"
}

prueba_10_2() {
    echo -e "\n  ${Y}== PRUEBA 10.2: AISLAMIENTO DE RED ==${N}"
    echo -e "\n  ${C}Ping web_server -> postgres_db (DNS):${N}"
    local r1; r1=$(docker exec web_server ping -c 3 postgres_db 2>&1)
    echo "$r1"
    echo -e "\n  ${C}Ping web_server -> ftp_server (DNS):${N}"
    local r2; r2=$(docker exec web_server ping -c 3 ftp_server 2>&1)
    echo "$r2"
    echo ""
    ( echo "$r1" | grep -q "bytes from" && echo "$r2" | grep -q "bytes from" ) \
        && ok "Resolucion DNS y conectividad en infra_red correcta" \
        || err "Revisar red infra_red"
}

prueba_10_3() {
    echo -e "\n  ${Y}== PRUEBA 10.3: PERMISOS FTP ==${N}"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local f="prueba103_${ts}.txt"
    docker exec ftp_server sh -c "echo 'Prueba de funcionalidad - $ts' > /ftp/uploads/$f"
    info "Archivo creado en FTP: $f"
    local web_ls
    web_ls=$(docker exec web_server ls /var/www/html/uploads/ 2>&1)
    echo -e "  Contenido visible en web_server:\n  $web_ls"
    echo ""
    echo "$web_ls" | grep -q "$f" \
        && ok "Archivo FTP visible en web (volumen compartido OK)" \
        && echo -e "  ${C}URL: http://localhost:8080/uploads/$f${N}" \
        || err "Archivo no visible en web, revisar ftp_uploads"
}

prueba_10_4() {
    echo -e "\n  ${Y}== PRUEBA 10.4: LIMITES DE RECURSOS ==${N}"
    echo -e "\n  ${C}docker stats --no-stream:${N}"
    docker stats --no-stream \
        --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    echo -e "\n  ${C}Limites configurados:${N}"
    for c in web_server postgres_db ftp_server; do
        local mem cpu mb
        mem=$(docker inspect "$c" --format='{{.HostConfig.Memory}}' 2>/dev/null)
        cpu=$(docker inspect "$c" --format='{{.HostConfig.CpuQuota}}' 2>/dev/null)
        mb=$(( mem / 1024 / 1024 ))
        printf "  ${W}%-16s${N} Mem: ${G}%sMB${N}  CpuQuota: ${Y}%s${N}\n" "$c" "$mb" "$cpu"
    done
    echo ""
    ok "EVIDENCIA - Captura la tabla de docker stats de arriba"
}

menu_pruebas() {
    banner
    sep "PROTOCOLO DE PRUEBAS"
    item "1" "Prueba 10.1 - Persistencia de Base de Datos"
    item "2" "Prueba 10.2 - Aislamiento de Red (ping DNS)"
    item "3" "Prueba 10.3 - Permisos FTP"
    item "4" "Prueba 10.4 - Limites de Recursos (stats)"
    item "5" "Ejecutar TODAS las pruebas"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) prueba_10_1; pausa ;;
        2) prueba_10_2; pausa ;;
        3) prueba_10_3; pausa ;;
        4) prueba_10_4; pausa ;;
        5) prueba_10_1; prueba_10_2; prueba_10_3; prueba_10_4; pausa ;;
        0) return ;;
    esac
    menu_pruebas
}

# ================================================================
#  PRACTICA 11 - SUBMENU PRINCIPAL
# ================================================================
menu_p11() {
    banner
    sep "PRACTICA 11 - ORQUESTACION AVANZADA"
    item "1" "Despliegue Practica 11"
    item "2" "Gestion nginx (balanceador)"
    item "3" "Gestion pgAdmin"
    item "4" "Tunel SSH"
    item "5" "Protocolo de Pruebas  (11.1 - 11.4)"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) menu_p11_despliegue ;;
        2) menu_p11_nginx      ;;
        3) menu_p11_pgadmin    ;;
        4) menu_p11_tunel      ;;
        5) menu_p11_pruebas    ;;
        0) return ;;
    esac
    menu_p11
}

# ================================================================
#  PRACTICA 11 - SUBMENU DESPLIEGUE
# ================================================================
menu_p11_despliegue() {
    banner
    sep "P11 - DESPLIEGUE"
    item "1" "Generar .env y docker-compose.yml"
    item "2" "Levantar stack completo  (up -d)"
    item "3" "Detener stack            (stop)"
    item "4" "Reiniciar stack          (restart)"
    item "5" "Reconstruir desde cero   (down + build + up)"
    item "6" "Eliminar TODO con datos  (down -v)"
    item "7" "Ver logs de un servicio"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) p11_generar_archivos; pausa ;;
        2)
            sudo docker compose -f "$BASE_DIR/practica11/docker-compose.yml" \
                --env-file "$BASE_DIR/practica11/.env" up -d
            sleep 5; pausa ;;
        3)
            sudo docker compose -f "$BASE_DIR/practica11/docker-compose.yml" \
                --env-file "$BASE_DIR/practica11/.env" stop; pausa ;;
        4)
            sudo docker compose -f "$BASE_DIR/practica11/docker-compose.yml" \
                --env-file "$BASE_DIR/practica11/.env" restart
            sleep 5; pausa ;;
        5)
            sudo docker compose -f "$BASE_DIR/practica11/docker-compose.yml" \
                --env-file "$BASE_DIR/practica11/.env" down
            sudo docker compose -f "$BASE_DIR/practica11/docker-compose.yml" \
                --env-file "$BASE_DIR/practica11/.env" build --no-cache
            sudo docker compose -f "$BASE_DIR/practica11/docker-compose.yml" \
                --env-file "$BASE_DIR/practica11/.env" up -d
            sleep 5; pausa ;;
        6)
            read -rp "  Eliminar TODO incluyendo volumenes? [s/N]: " conf
            [[ "$conf" =~ ^[Ss]$ ]] && sudo docker compose \
                -f "$BASE_DIR/practica11/docker-compose.yml" \
                --env-file "$BASE_DIR/practica11/.env" down -v
            pausa ;;
        7)
            read -rp "  Servicio [nginx_lb/app_server/postgres11/pgadmin]: " s
            sudo docker logs --tail=50 "$s" 2>&1; pausa ;;
        0) return ;;
    esac
    menu_p11_despliegue
}

# ================================================================
#  PRACTICA 11 - SUBMENU NGINX
# ================================================================
menu_p11_nginx() {
    banner
    sep "P11 - NGINX BALANCEADOR"
    item "1" "Ver configuracion nginx"
    item "2" "Ver logs de acceso"
    item "3" "Recargar configuracion nginx"
    item "4" "Verificar cabeceras del servidor"
    item "5" "Shell en contenedor nginx"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) sudo docker exec nginx_lb cat /etc/nginx/nginx.conf; pausa ;;
        2) sudo docker logs --tail=50 nginx_lb 2>&1; pausa ;;
        3) sudo docker exec nginx_lb nginx -s reload; ok "nginx recargado"; pausa ;;
        4)
            echo ""
            curl -sI http://localhost:80 | grep -i "server\|x-powered"
            pausa ;;
        5) sudo docker exec -it nginx_lb sh; pausa ;;
        0) return ;;
    esac
    menu_p11_nginx
}

# ================================================================
#  PRACTICA 11 - SUBMENU PGADMIN
# ================================================================
menu_p11_pgadmin() {
    banner
    sep "P11 - PGADMIN"
    item "1" "Ver estado del contenedor pgadmin"
    item "2" "Ver logs de pgadmin"
    item "3" "Mostrar instrucciones tunel SSH"
    item "4" "Verificar que puerto pgadmin NO es accesible"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) sudo docker inspect pgadmin --format='Estado: {{.State.Status}}'; pausa ;;
        2) sudo docker logs --tail=50 pgadmin 2>&1; pausa ;;
        3)
            echo ""
            echo -e "  ${C}+-- Instrucciones Tunel SSH -----------------------+${N}"
            echo -e "  ${C}|${N}  Ejecutar en tu maquina local:                  ${C}|${N}"
            echo -e "  ${C}|${N}                                                  ${C}|${N}"
            echo -e "  ${C}|${N}  ${W}ssh -L 8888:localhost:5050${N}                     ${C}|${N}"
            echo -e "  ${C}|${N}  ${W}    srv-linux-server@192.168.117.10${N}            ${C}|${N}"
            echo -e "  ${C}|${N}                                                  ${C}|${N}"
            echo -e "  ${C}|${N}  Luego abrir: ${G}http://localhost:8888${N}             ${C}|${N}"
            echo -e "  ${C}+--------------------------------------------------+${N}"
            pausa ;;
        4)
            echo ""
            info "Intentando conectar a pgadmin desde exterior (debe fallar)..."
            curl -m 5 http://192.168.117.10:5050 &>/dev/null \
                && err "ALERTA - pgadmin ES accesible desde exterior" \
                || ok "pgadmin NO es accesible desde exterior - firewall OK"
            pausa ;;
        0) return ;;
    esac
    menu_p11_pgadmin
}

# ================================================================
#  PRACTICA 11 - SUBMENU TUNEL SSH
# ================================================================
menu_p11_tunel() {
    banner
    sep "P11 - TUNEL SSH"
    item "1" "Ver estado del firewall (ufw)"
    item "2" "Configurar firewall (bloquear 5050 y 5432)"
    item "3" "Instrucciones tunel pgAdmin"
    item "4" "Instrucciones tunel PostgreSQL"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) sudo ufw status verbose; pausa ;;
        2)
            info "Bloqueando puertos 5050 y 5432 en firewall..."
            sudo ufw deny 5050/tcp
            sudo ufw deny 5432/tcp
            sudo ufw allow 22/tcp
            sudo ufw allow 80/tcp
            sudo ufw --force enable
            ok "Firewall configurado"
            sudo ufw status verbose
            pausa ;;
        3)
            echo ""
            echo -e "  ${C}Tunel para pgAdmin:${N}"
            echo -e "  ${W}ssh -L 8888:localhost:5050 srv-linux-server@192.168.117.10${N}"
            echo -e "  Abrir: ${G}http://localhost:8888${N}"
            pausa ;;
        4)
            echo ""
            echo -e "  ${C}Tunel para PostgreSQL:${N}"
            echo -e "  ${W}ssh -L 5555:localhost:5432 srv-linux-server@192.168.117.10${N}"
            echo -e "  Conectar DBeaver/pgAdmin local a: ${G}localhost:5555${N}"
            pausa ;;
        0) return ;;
    esac
    menu_p11_tunel
}

# ================================================================
#  PRACTICA 11 - PRUEBAS
# ================================================================
prueba_11_1() {
    echo -e "\n  ${Y}== PRUEBA 11.1: AISLAMIENTO DE RED ==${N}"
    info "Intentando curl a PostgreSQL puerto 5432 desde exterior..."
    curl -m 5 http://192.168.117.10:5432 &>/dev/null \
        && err "FAIL - Puerto 5432 accesible desde exterior" \
        || ok "Puerto 5432 rechazado - aislamiento correcto"
    info "Intentando curl a pgAdmin puerto 5050 desde exterior..."
    curl -m 5 http://192.168.117.10:5050 &>/dev/null \
        && err "FAIL - Puerto 5050 accesible desde exterior" \
        || ok "Puerto 5050 rechazado - aislamiento correcto"
}

prueba_11_2() {
    echo -e "\n  ${Y}== PRUEBA 11.2: RESOLUCION DNS INTERNA ==${N}"
    info "Ping desde nginx_lb hacia postgres11 por nombre..."
    local r
    r=$(sudo docker exec nginx_lb ping -c 3 postgres11 2>&1)
    echo "$r"
    echo ""
    echo "$r" | grep -q "bytes from" \
        && ok "DNS interno resuelve postgres11 correctamente" \
        || err "FAIL - No se resuelve postgres11 por nombre"
}

prueba_11_3() {
    echo -e "\n  ${Y}== PRUEBA 11.3: TUNEL SSH ==${N}"
    echo ""
    echo -e "  Esta prueba requiere accion manual desde tu maquina local."
    echo ""
    echo -e "  ${W}Paso 1${N} - Abrir terminal en tu maquina y ejecutar:"
    echo -e "  ${C}ssh -L 8888:localhost:5050 srv-linux-server@192.168.117.10${N}"
    echo ""
    echo -e "  ${W}Paso 2${N} - Abrir en navegador: ${G}http://localhost:8888${N}"
    echo ""
    echo -e "  ${W}Credenciales pgAdmin:${N}"
    local email pass
    email=$(grep PGADMIN_EMAIL "$BASE_DIR/practica11/.env" 2>/dev/null | cut -d= -f2)
    pass=$(grep PGADMIN_PASS "$BASE_DIR/practica11/.env" 2>/dev/null | cut -d= -f2)
    echo -e "  Email   : ${G}${email:-admin@practica11.local}${N}"
    echo -e "  Password: ${G}${pass:-Admin1234!}${N}"
    echo ""
    info "Verifica que pgAdmin cargue en el navegador via tunel"
}

prueba_11_4() {
    echo -e "\n  ${Y}== PRUEBA 11.4: PERSISTENCIA Y HEALTHCHECK ==${N}"
    info "Insertando dato de prueba en postgres11..."
    sudo docker exec postgres11 psql -U practica11 -d practica11_db -c \
        "INSERT INTO usuarios(nombre,email) VALUES('Test P11','test11@local.com') ON CONFLICT(email) DO NOTHING;" \
        &>/dev/null
    local antes
    antes=$(sudo docker exec postgres11 psql -U practica11 -d practica11_db -t \
        -c "SELECT COUNT(*) FROM usuarios;" 2>/dev/null | tr -d ' ')
    echo -e "  Registros antes: ${W}$antes${N}"

    info "Ejecutando docker compose down..."
    sudo docker compose -f "$BASE_DIR/practica11/docker-compose.yml" \
        --env-file "$BASE_DIR/practica11/.env" down &>/dev/null
    sleep 3

    info "Levantando de nuevo (observar orden de inicio)..."
    sudo docker compose -f "$BASE_DIR/practica11/docker-compose.yml" \
        --env-file "$BASE_DIR/practica11/.env" up -d
    sleep 20

    info "Verificando estado de healthcheck..."
    sudo docker inspect postgres11 --format='  postgres11 health: {{.State.Health.Status}}' 2>/dev/null
    sudo docker inspect pgadmin    --format='  pgadmin    status: {{.State.Status}}'        2>/dev/null

    local despues
    despues=$(sudo docker exec postgres11 psql -U practica11 -d practica11_db -t \
        -c "SELECT COUNT(*) FROM usuarios;" 2>/dev/null | tr -d ' ')
    echo -e "  Registros despues: ${W}$despues${N}"
    echo ""
    [[ "$despues" -ge "$antes" ]] \
        && ok "Datos persisten y healthcheck funciona correctamente" \
        || err "FAIL - Datos no persistieron"
}

menu_p11_pruebas() {
    banner
    sep "P11 - PROTOCOLO DE PRUEBAS"
    item "1" "Prueba 11.1 - Aislamiento de Red"
    item "2" "Prueba 11.2 - Resolucion DNS Interna"
    item "3" "Prueba 11.3 - Tunel SSH (manual)"
    item "4" "Prueba 11.4 - Persistencia y Healthcheck"
    item "5" "Ejecutar TODAS"
    item "0" "<- Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) prueba_11_1; pausa ;;
        2) prueba_11_2; pausa ;;
        3) prueba_11_3; pausa ;;
        4) prueba_11_4; pausa ;;
        5) prueba_11_1; prueba_11_2; prueba_11_3; prueba_11_4; pausa ;;
        0) return ;;
    esac
    menu_p11_pruebas
}

# ================================================================
#  GENERADOR DE ARCHIVOS PRACTICA 11
# ================================================================
p11_generar_archivos() {
    local p11="$BASE_DIR/practica11"
    mkdir -p "$p11/nginx" "$p11/app"
    info "Generando archivos Practica 11..."

    # ── .env ────────────────────────────────────────────────────
    cat > "$p11/.env" <<'ENV'
# ================================================================
#  .env - Variables de entorno Practica 11
#  NO subir este archivo a repositorios publicos
# ================================================================
POSTGRES_DB=practica11_db
POSTGRES_USER=practica11
POSTGRES_PASSWORD=P11Pass_Seguro!

PGADMIN_EMAIL=admin@practica11.local
PGADMIN_PASS=Admin1234!

APP_PORT=3000
NGINX_PORT=80
ENV

    # ── nginx/nginx.conf ─────────────────────────────────────────
    cat > "$p11/nginx/nginx.conf" <<'NGINX'
events { worker_connections 1024; }

http {
    # Ocultar version del servidor
    server_tokens off;

    upstream app_backend {
        server app_server:3000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass         http://app_backend;
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
NGINX

    # ── app/index.html ───────────────────────────────────────────
    cat > "$p11/app/index.html" <<'HTML'
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Practica 11 - App Server</title></head>
<body>
<h1>Practica 11 - Servidor de Aplicacion Interno</h1>
<p>Este contenedor no tiene puertos expuestos al host.</p>
<p>Solo es accesible a traves del balanceador nginx.</p>
</body>
</html>
HTML

    # ── app/Dockerfile ───────────────────────────────────────────
    cat > "$p11/app/Dockerfile" <<'DOCKERFILE'
FROM alpine:3.19
RUN apk add --no-cache python3
WORKDIR /app
COPY index.html .
EXPOSE 3000
CMD ["python3", "-m", "http.server", "3000"]
DOCKERFILE

    # ── init_db_p11.sql ──────────────────────────────────────────
    cat > "$p11/init_db_p11.sql" <<'SQL'
CREATE TABLE IF NOT EXISTS usuarios (
    id        SERIAL PRIMARY KEY,
    nombre    VARCHAR(100) NOT NULL,
    email     VARCHAR(150) UNIQUE NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO usuarios (nombre, email) VALUES
    ('Admin P11',  'admin@practica11.local'),
    ('Usuario P11','user@practica11.local')
ON CONFLICT (email) DO NOTHING;
SQL

    # ── docker-compose.yml ───────────────────────────────────────
    cat > "$p11/docker-compose.yml" <<'YAML'
services:

  # ── Balanceador / Frontend publico ──────────────────────────
  nginx_lb:
    image: nginx:alpine
    container_name: nginx_lb
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "${NGINX_PORT}:80"
    networks:
      - red_publica
    depends_on:
      - app_server
    restart: always

  # ── App server interno (sin puertos al host) ─────────────────
  app_server:
    build:
      context: ./app
      dockerfile: Dockerfile
    container_name: app_server
    networks:
      - red_publica
    restart: always

  # ── Base de datos ────────────────────────────────────────────
  postgres11:
    image: postgres:16-alpine
    container_name: postgres11
    environment:
      POSTGRES_DB:       ${POSTGRES_DB}
      POSTGRES_USER:     ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - db_data_p11:/var/lib/postgresql/data
      - ./init_db_p11.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - red_datos
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ── pgAdmin (solo accesible via tunel SSH) ───────────────────
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL:    ${PGADMIN_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASS}
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    networks:
      - red_datos
    ports:
      - "127.0.0.1:5050:80"
    depends_on:
      postgres11:
        condition: service_healthy
    restart: always

volumes:
  db_data_p11: { name: db_data_p11, driver: local }
  pgadmin_data: { name: pgadmin_data, driver: local }

networks:
  red_publica:
    name: red_publica
    driver: bridge
  red_datos:
    name: red_datos
    driver: bridge
    internal: true
YAML

    ok "Archivos Practica 11 generados en $p11"
    echo ""
    echo -e "  Estructura:"
    find "$p11" -type f | sort | while read -r f; do
        echo -e "  ${D}${f/$BASE_DIR\//}${N}"
    done
}

# ================================================================
#  MENU PRINCIPAL
# ================================================================
menu_principal() {
    banner
    sep "MENU PRINCIPAL"
    item "1" "Despliegue y Contenedores     (Practica 10)"
    item "2" "PostgreSQL                    (Practica 10)"
    item "3" "Servidor FTP                  (Practica 10)"
    item "4" "Redes y Recursos              (Practica 10)"
    item "5" "Protocolo de Pruebas          (10.1 - 10.4)"
    item "6" "Practica 11 - Orquestacion Avanzada"
    item "Q" "Salir"
    fin
    read -rp "  Selecciona: " op
    case ${op^^} in
        1) menu_despliegue ;;
        2) menu_postgres   ;;
        3) menu_ftp        ;;
        4) menu_redes      ;;
        5) menu_pruebas    ;;
        6) menu_p11        ;;
        Q) clear; echo -e "\n  ${C}Fin de sesion${N}\n"; exit 0 ;;
    esac
    menu_principal
}

menu_principal