#!/bin/bash
# ================================================================
#  menu.sh - Menu Principal Practica 10 | Ubuntu Server
#  Uso: sudo bash menu.sh
# ================================================================

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colores ──────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
C='\033[0;36m' W='\033[1;37m' D='\033[0;37m'
M='\033[0;35m' N='\033[0m'

ok()   { echo -e "  ${G}[OK]${N} $1"; }
err()  { echo -e "  ${R}[ERROR]${N} $1"; }
info() { echo -e "  ${D}[INFO]${N} $1"; }
pausa(){ echo -e "\n  ${D}Presiona ENTER para continuar...${N}"; read -r; }

# ── Banner + estado de contenedores ─────────────────────────────
banner() {
    clear
    echo ""
    echo -e "${C}  ╔══════════════════════════════════════════════════════╗${N}"
    echo -e "${C}  ║          PRACTICA 10 - CONTENEDORES DOCKER           ║${N}"
    echo -e "${C}  ║          Migracion de Servicios - Ubuntu Server      ║${N}"
    echo -e "${C}  ╚══════════════════════════════════════════════════════╝${N}"
    echo ""

    # Estado rapido de los tres contenedores
    local names=("web_server" "postgres_db" "ftp_server")
    local cols=("$G" "$C" "$Y")
    printf "  "
    for i in 0 1 2; do
        local s
        s=$(sudo docker inspect --format='{{.State.Status}}' "${names[$i]}" 2>/dev/null || echo "no creado")
        local sym="[ ]" col="$D"
        [[ "$s" == "running" ]] && sym="[*]" && col="${cols[$i]}"
        printf "${col}${sym} %-22s${N}" "${names[$i]}: $s"
    done
    echo -e "\n"
}

sep()  { echo -e "  ${C}┌─ $1 $( printf '─%.0s' $(seq 1 $((46-${#1}))) )${N}"; }
item() { echo -e "  ${C}│${N}  ${W}[$1]${N} $2"; }
fin()  { echo -e "  ${C}└$(printf '─%.0s' $(seq 1 52))${N}\n"; }

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
    item "0" "← Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) bash "$BASE_DIR/deploy.sh"; pausa ;;
        2) sudo sudo docker compose -f "$BASE_DIR/docker-compose.yml" build; pausa ;;
        3) sudo sudo docker compose -f "$BASE_DIR/docker-compose.yml" up -d; sleep 3; pausa ;;
        4) sudo sudo docker compose -f "$BASE_DIR/docker-compose.yml" stop; pausa ;;
        5) sudo sudo docker compose -f "$BASE_DIR/docker-compose.yml" restart; sleep 5; pausa ;;
        6)
            sudo sudo docker compose -f "$BASE_DIR/docker-compose.yml" down
            sudo sudo docker compose -f "$BASE_DIR/docker-compose.yml" build --no-cache
            sudo sudo docker compose -f "$BASE_DIR/docker-compose.yml" up -d
            sleep 5; pausa ;;
        7)
            read -rp "  Contenedor [web_server/postgres_db/ftp_server]: " c
            read -rp "  ¿Eliminar $c? [s/N]: " conf
            [[ "$conf" =~ ^[Ss]$ ]] && sudo sudo docker rm -f "$c" && ok "$c eliminado"
            pausa ;;
        8)
            read -rp "  ¿Eliminar TODOS los contenedores y volumenes? [s/N]: " conf
            [[ "$conf" =~ ^[Ss]$ ]] && sudo sudo docker compose -f "$BASE_DIR/docker-compose.yml" down -v
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
    item "0" "← Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) sudo sudo docker exec -it postgres_db psql -U practica10 -d practica10_db; pausa ;;
        2)
            sudo sudo docker exec postgres_db psql -U practica10 -d practica10_db \
                -c "SELECT id, nombre, email, rol, activo, creado_en FROM usuarios ORDER BY id;"
            pausa ;;
        3)
            sudo sudo docker exec postgres_db psql -U practica10 -d practica10_db -c "\dt"
            pausa ;;
        4)
            local ts; ts=$(date +"%Y%m%d_%H%M%S")
            sudo sudo docker exec postgres_db sh -c \
                "PGPASSWORD='Practica10Pass!' pg_dump -U practica10 practica10_db \
                 > /backups/backup_${ts}.sql && echo 'OK'"
            ok "Respaldo guardado en postgres/backups/backup_${ts}.sql"
            pausa ;;
        5)
            echo ""
            ls -lh "$BASE_DIR/postgres/backups/" 2>/dev/null || info "Sin respaldos todavia"
            pausa ;;
        6)
            local job="0 2 * * * sudo sudo docker exec postgres_db sh -c \"PGPASSWORD='Practica10Pass!' pg_dump -U practica10 practica10_db > /backups/backup_auto_\$(date +\\%Y\\%m\\%d_\\%H\\%M\\%S).sql\""
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
    item "0" "← Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1) sudo sudo docker exec ftp_server ls -lah /ftp/uploads/; pausa ;;
        2)
            sudo sudo docker exec web_server ls -lah /var/www/html/uploads/
            echo -e "\n  ${C}URL: http://localhost:8080/uploads/${N}"
            pausa ;;
        3)
            local ts; ts=$(date +"%Y%m%d_%H%M%S")
            sudo sudo docker exec ftp_server sh -c "echo 'Prueba FTP - $ts' > /ftp/uploads/test_${ts}.txt"
            ok "Archivo creado: test_${ts}.txt"
            pausa ;;
        4) sudo sudo docker exec ftp_server cat /var/log/vsftpd.log 2>&1; pausa ;;
        5)
            echo ""
            echo -e "  ${C}┌──────────────────────────────────────┐${N}"
            echo -e "  ${C}│${N}  Host    : localhost                  ${C}│${N}"
            echo -e "  ${C}│${N}  Puerto  : 21  (pasivo: 21100-21110)  ${C}│${N}"
            echo -e "  ${C}│${N}  ${G}Usuario : ftpadmin${N}                  ${C}│${N}"
            echo -e "  ${C}│${N}  ${G}Password: FtpPass2024!${N}              ${C}│${N}"
            echo -e "  ${C}└──────────────────────────────────────┘${N}"
            pausa ;;
        6) sudo sudo docker exec -it ftp_server sh; pausa ;;
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
    item "1" "sudo sudo docker stats --no-stream  (evidencia Prueba 10.4)"
    item "2" "sudo sudo docker stats en tiempo real"
    item "3" "Limites RAM/CPU por contenedor"
    item "4" "Inspeccionar red infra_red"
    item "5" "IPs asignadas en infra_red"
    item "6" "Ping entre contenedores   (Prueba 10.2)"
    item "7" "Ver todos los volumenes"
    item "0" "← Volver"
    fin
    read -rp "  Selecciona: " op
    case $op in
        1)
            echo ""
            sudo sudo docker stats --no-stream \
                --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"
            pausa ;;
        2) sudo sudo docker stats ;;
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
        4) sudo sudo docker network inspect infra_red; pausa ;;
        5)
            echo ""
            sudo sudo docker network inspect infra_red \
                --format '{{range .Containers}}  {{.Name}} → {{.IPv4Address}}{{println}}{{end}}'
            pausa ;;
        6)
            echo -e "\n  ${C}web_server → postgres_db:${N}"
            sudo sudo docker exec web_server ping -c 4 postgres_db 2>&1
            echo -e "\n  ${C}web_server → ftp_server:${N}"
            sudo sudo docker exec web_server ping -c 4 ftp_server 2>&1
            pausa ;;
        7) sudo sudo docker volume ls; pausa ;;
        0) return ;;
    esac
    menu_redes
}

# ================================================================
#  SUBMENU 5: PRUEBAS
# ================================================================

prueba_10_1() {
    echo -e "\n  ${Y}══ PRUEBA 10.1: PERSISTENCIA DE BASE DE DATOS ══${N}"
    info "Insertando registro de prueba..."
    sudo sudo docker exec postgres_db psql -U practica10 -d practica10_db -c \
        "INSERT INTO usuarios(nombre,email,rol) VALUES('Test Persistencia','persist@test.local','test') ON CONFLICT(email) DO NOTHING;" \
        &>/dev/null
    local antes
    antes=$(sudo sudo docker exec postgres_db psql -U practica10 -d practica10_db -t \
        -c "SELECT COUNT(*) FROM usuarios;" 2>/dev/null | tr -d ' ')
    echo -e "  Registros ${W}antes${N} de eliminar contenedor: ${W}$antes${N}"

    info "Ejecutando: sudo sudo docker rm -f postgres_db ..."
    sudo sudo docker rm -f postgres_db &>/dev/null
    sleep 3
    info "Recreando contenedor con volumen db_data..."
    sudo sudo docker compose -f "$BASE_DIR/docker-compose.yml" up -d postgres_db &>/dev/null
    sleep 15

    local despues
    despues=$(sudo sudo docker exec postgres_db psql -U practica10 -d practica10_db -t \
        -c "SELECT COUNT(*) FROM usuarios;" 2>/dev/null | tr -d ' ')
    echo -e "  Registros ${W}despues${N} de recrear contenedor: ${W}$despues${N}"
    echo ""
    sudo sudo docker exec postgres_db psql -U practica10 -d practica10_db \
        -c "SELECT id, nombre, email FROM usuarios;" 2>/dev/null

    [[ "$despues" -ge "$antes" ]] \
        && ok "PASS — Los datos persisten en el volumen db_data" \
        || err "FAIL — Los datos no persistieron, revisar db_data"
}

prueba_10_2() {
    echo -e "\n  ${Y}══ PRUEBA 10.2: AISLAMIENTO DE RED ══${N}"
    echo -e "\n  ${C}Ping web_server → postgres_db (DNS):${N}"
    local r1; r1=$(sudo sudo docker exec web_server ping -c 3 postgres_db 2>&1)
    echo "$r1"
    echo -e "\n  ${C}Ping web_server → ftp_server (DNS):${N}"
    local r2; r2=$(sudo sudo docker exec web_server ping -c 3 ftp_server 2>&1)
    echo "$r2"
    echo ""
    ( echo "$r1" | grep -q "bytes from" && echo "$r2" | grep -q "bytes from" ) \
        && ok "PASS — Resolucion DNS y conectividad en infra_red correcta" \
        || err "FAIL — Revisar red infra_red"
}

prueba_10_3() {
    echo -e "\n  ${Y}══ PRUEBA 10.3: PERMISOS FTP ══${N}"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local f="prueba103_${ts}.txt"
    sudo sudo docker exec ftp_server sh -c "echo 'Prueba de funcionalidad' > /ftp/uploads/$f"
    info "Archivo creado en FTP: $f"
    local web_ls
    web_ls=$(sudo sudo docker exec web_server ls /var/www/html/uploads/ 2>&1)
    echo -e "  Contenido visible en web_server:\n  $web_ls"
    echo ""
    echo "$web_ls" | grep -q "$f" \
        && ok "PASS — Archivo FTP visible en web (volumen compartido OK)" \
        && echo -e "  ${C}URL: http://192.168.117.10:8080/uploads/$f${N}" \
        || err "FAIL — Archivo no visible en web, revisar ftp_uploads"
}

prueba_10_4() {
    echo -e "\n  ${Y}══ PRUEBA 10.4: LIMITES DE RECURSOS ══${N}"
    echo -e "\n  ${C}sudo sudo docker stats --no-stream:${N}"
    sudo sudo docker stats --no-stream \
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
}

menu_pruebas() {
    banner
    sep "PROTOCOLO DE PRUEBAS"
    item "1" "Prueba 1 — Persistencia de Base de Datos"
    item "2" "Prueba 2 — Aislamiento de Red (ping DNS)"
    item "3" "Prueba 3 — Permisos FTP"
    item "4" "Prueba 4 — Limites de Recursos (stats)"
    item "5" "Ejecutar TODAS las pruebas"
    item "0" "← Volver"
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
#  MENU PRINCIPAL
# ================================================================
menu_principal() {
    banner
    sep "MENU PRINCIPAL"
    item "1" "Despliegue y Contenedores"
    item "2" "PostgreSQL"
    item "3" "Servidor FTP"
    item "4" "Redes y Recursos"
    item "5" "Protocolo de Pruebas  (10.1 – 10.4)"
    item "Q" "Salir"
    fin
    read -rp "  Selecciona: " op
    case ${op^^} in
        1) menu_despliegue ;;
        2) menu_postgres   ;;
        3) menu_ftp        ;;
        4) menu_redes      ;;
        5) menu_pruebas    ;;
        Q) clear; echo -e "\n  ${C}Practica 10 — Fin de sesion${N}\n"; exit 0 ;;
    esac
    menu_principal
}

menu_principal