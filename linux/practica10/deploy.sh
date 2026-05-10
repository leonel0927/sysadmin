#!/bin/bash
# ================================================================
#  deploy.sh - Practica 10 | Ubuntu Server
#  Genera toda la estructura de archivos y despliega contenedores
#  Uso: sudo bash deploy.sh
# ================================================================

set -e
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colores ──────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
C='\033[0;36m' W='\033[1;37m' D='\033[0;37m' N='\033[0m'

ok()   { echo -e "  ${G}✔${N} $1"; }
err()  { echo -e "  ${R}✘${N} $1"; }
info() { echo -e "  ${D}ℹ${N} $1"; }
step() { echo -e "\n  ${Y}►${N} $1"; }

# ── Verificar Docker ─────────────────────────────────────────────
check_docker() {
    step "Verificando Docker..."
    if ! command -v docker &>/dev/null; then
        err "Docker no encontrado. Instalando..."
        apt-get update -qq
        apt-get install -y ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
            gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
            https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
            > /etc/apt/sources.list.d/docker.list
        apt-get update -qq
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl enable --now docker
        ok "Docker instalado"
    else
        ok "Docker $(docker --version | awk '{print $3}' | tr -d ',')"
    fi
}

# ── Crear directorios ────────────────────────────────────────────
create_dirs() {
    step "Creando estructura de directorios..."
    mkdir -p \
        "$BASE_DIR/web/html/css" \
        "$BASE_DIR/web/html/images" \
        "$BASE_DIR/web/html/uploads" \
        "$BASE_DIR/postgres/backups" \
        "$BASE_DIR/ftp"
    ok "Directorios listos"
}

# ── web/Dockerfile ───────────────────────────────────────────────
gen_web_dockerfile() {
    cat > "$BASE_DIR/web/Dockerfile" <<'DOCKERFILE'
FROM alpine:3.19
LABEL description="Apache personalizado - Practica 10"
RUN apk update && apk add --no-cache apache2 apache2-utils curl iputils-ping \
    && rm -rf /var/cache/apk/* \
    && echo "ServerTokens Prod"   >> /etc/apache2/httpd.conf \
    && echo "ServerSignature Off" >> /etc/apache2/httpd.conf \
    && echo "TraceEnable Off"     >> /etc/apache2/httpd.conf \
    && addgroup -S webgroup \
    && adduser  -S webuser -G webgroup \
    && mkdir -p /var/www/html/uploads /var/log/apache2 /var/run/apache2
COPY html/ /var/www/html/
RUN printf '<Directory "/var/www/html/uploads">\n  Options +Indexes\n  Require all granted\n</Directory>\n' \
        >> /etc/apache2/conf.d/uploads.conf \
    && chown -R webuser:webgroup /var/www/html /var/log/apache2
EXPOSE 80
USER webuser
CMD ["httpd","-D","FOREGROUND","-f","/etc/apache2/httpd.conf"]
DOCKERFILE
}

# ── web/html/index.html ──────────────────────────────────────────
gen_web_html() {
    cat > "$BASE_DIR/web/html/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>Practica 10</title>
  <link rel="stylesheet" href="/css/styles.css">
</head>
<body>
    <h1>si jala</h1>
</body>
</html>
HTML
}

# ── web/html/css/styles.css ──────────────────────────────────────
gen_web_css() {
    cat > "$BASE_DIR/web/html/css/styles.css" <<'CSS'
@import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Barlow+Condensed:wght@600;800&display=swap');
:root{--bg:#0a0c10;--sur:#111420;--brd:#1e2535;--a1:#00e5ff;--a2:#7c4dff;--a3:#ff6d00;--gr:#00e676;--tx:#c9d1e0;--tm:#5a6480;--mono:'Space Mono',monospace;--disp:'Barlow Condensed',sans-serif}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--tx);font-family:var(--mono);font-size:13px;line-height:1.7;overflow-x:hidden}
.scanline{pointer-events:none;position:fixed;inset:0;z-index:9999;background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,0,0,.15) 2px,rgba(0,0,0,.15) 4px)}
header{border-bottom:1px solid var(--brd);background:rgba(10,12,16,.95);backdrop-filter:blur(12px);position:sticky;top:0;z-index:100}
.hdr{max-width:1100px;margin:0 auto;padding:14px 24px;display:flex;align-items:center;justify-content:space-between}
.logo{display:flex;align-items:center;gap:12px}.ico{font-size:28px;color:var(--a1);filter:drop-shadow(0 0 8px var(--a1))}
.sub{font-size:10px;letter-spacing:.2em;color:var(--tm);text-transform:uppercase}
h1{font-family:var(--disp);font-weight:800;font-size:22px;color:#fff;line-height:1}
nav{display:flex;gap:8px}.pill{padding:4px 10px;border-radius:999px;font-size:10px;border:1px solid}
.g{color:var(--gr);border-color:var(--gr);background:rgba(0,230,118,.08)}
.b{color:var(--a1);border-color:var(--a1);background:rgba(0,229,255,.08)}
.o{color:var(--a3);border-color:var(--a3);background:rgba(255,109,0,.08)}
main{max-width:1100px;margin:0 auto;padding:48px 24px 80px}
.hero{position:relative;overflow:hidden;border:1px solid var(--brd);border-radius:12px;padding:60px 48px;margin-bottom:48px;background:var(--sur)}
.hbg{position:absolute;inset:0;background:radial-gradient(ellipse at 70% 50%,rgba(124,77,255,.15),transparent 70%)}
.hc{position:relative;z-index:2;max-width:540px}
.tag{font-size:10px;letter-spacing:.2em;text-transform:uppercase;color:var(--a1);margin-bottom:16px}
.hc h2{font-family:var(--disp);font-weight:800;font-size:clamp(40px,7vw,70px);line-height:.95;color:#fff;margin-bottom:20px}
.hc h2 em{font-style:normal;color:var(--a1)}.hc p{color:var(--tm)}.hc strong{color:var(--tx)}
.sec{margin-bottom:52px}
h3{font-family:var(--disp);font-size:20px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:#fff;margin-bottom:24px;display:flex;align-items:center;gap:10px}
h3 span{font-size:11px;color:var(--a1);border:1px solid var(--a1);padding:2px 8px;border-radius:4px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:18px}
.card{background:var(--sur);border:1px solid var(--brd);border-radius:10px;padding:26px 22px;position:relative;overflow:hidden;transition:transform .2s,border-color .2s}
.card:hover{transform:translateY(-3px)}.card::before{content:'';position:absolute;top:0;left:0;right:0;height:3px}
.cw::before{background:linear-gradient(90deg,var(--gr),var(--a1))}.cw:hover{border-color:var(--gr)}
.cd::before{background:linear-gradient(90deg,var(--a1),var(--a2))}.cd:hover{border-color:var(--a1)}
.cf::before{background:linear-gradient(90deg,var(--a3),#ff1744)}.cf:hover{border-color:var(--a3)}
.ci{font-size:30px;margin-bottom:12px}.card h4{font-family:var(--disp);font-size:18px;color:#fff;margin-bottom:8px}
.card p{color:var(--tm);font-size:12px;margin-bottom:14px}
code{background:rgba(0,229,255,.1);color:var(--a1);padding:1px 5px;border-radius:3px}
.ct{font-size:10px;padding:3px 10px;border-radius:4px;background:rgba(255,255,255,.05);border:1px solid var(--brd);color:var(--tm)}
.net{background:var(--sur);border:1px solid var(--brd);border-radius:10px;padding:36px 24px;display:flex;flex-wrap:wrap;align-items:center;justify-content:center;gap:0}
.nn{background:var(--bg);border:1px solid var(--brd);border-radius:8px;padding:14px 18px;text-align:center;font-size:11px;font-weight:700;min-width:115px}
.nw{border-color:var(--gr);color:var(--gr)}.nd{border-color:var(--a1);color:var(--a1)}.nf{border-color:var(--a3);color:var(--a3)}
.nn small{display:block;color:var(--tm);font-weight:400;margin-top:4px}
.nh{background:rgba(124,77,255,.15);border:2px solid var(--a2);border-radius:50%;padding:16px 20px;text-align:center;font-size:11px;font-weight:700;color:var(--a2);min-width:115px}
.nh small{display:block;color:var(--tm);font-weight:400;margin-top:4px}
.nl{width:36px;height:2px;background:linear-gradient(90deg,var(--brd),var(--a2),var(--brd))}
.nv{width:2px;height:36px;background:linear-gradient(180deg,var(--a2),var(--brd));margin:0 auto}
.btn{display:inline-block;padding:8px 18px;border:1px solid var(--a1);color:var(--a1);border-radius:6px;text-decoration:none;font-size:11px;transition:background .2s}
.btn:hover{background:rgba(0,229,255,.1)}
.rg{display:grid;grid-template-columns:1fr 1fr;gap:18px}
.ri{background:var(--sur);border:1px solid var(--brd);border-radius:10px;padding:22px}
.rl{font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--tm);margin-bottom:10px}
.rb{height:8px;background:rgba(255,255,255,.06);border-radius:999px;overflow:hidden;margin-bottom:10px}
.rf{height:100%;width:50%;background:linear-gradient(90deg,var(--a1),var(--a2));border-radius:999px;animation:fb 2s ease-out}
.rfc{background:linear-gradient(90deg,var(--a3),#ff1744)}
@keyframes fb{from{width:0}}
footer{border-top:1px solid var(--brd);padding:20px;text-align:center;font-size:11px;color:var(--tm)}
@media(max-width:640px){.hero{padding:36px 20px}.rg{grid-template-columns:1fr}.net{flex-direction:column}}
CSS
}

# ── ftp/Dockerfile ───────────────────────────────────────────────
gen_ftp_dockerfile() {
    cat > "$BASE_DIR/ftp/Dockerfile" <<'DOCKERFILE'
FROM alpine:3.19
LABEL description="vsftpd FTP - Practica 10"
RUN apk update && apk add --no-cache vsftpd && rm -rf /var/cache/apk/* \
    && addgroup -S ftpgroup \
    && adduser  -S ftpuser -G ftpgroup -h /ftp -s /bin/false \
    && mkdir -p /var/run/vsftpd/empty /ftp/uploads \
    && chown -R ftpuser:ftpgroup /ftp
COPY vsftpd.conf   /etc/vsftpd/vsftpd.conf
COPY ftp-entry.sh  /usr/local/bin/ftp-entry.sh
RUN chmod +x /usr/local/bin/ftp-entry.sh
EXPOSE 21 21100-21110
ENTRYPOINT ["/usr/local/bin/ftp-entry.sh"]
DOCKERFILE
}

# ── ftp/vsftpd.conf ──────────────────────────────────────────────
gen_ftp_conf() {
    cat > "$BASE_DIR/ftp/vsftpd.conf" <<'CONF'
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
hide_ids=YES
pasv_enable=YES
pasv_min_port=21100
pasv_max_port=21110
pasv_address=127.0.0.1
xferlog_enable=YES
ftpd_banner=FTP Practica10
listen=YES
listen_ipv6=NO
CONF
}

# ── docker-compose.yml ───────────────────────────────────────────
gen_compose() {
    cat > "$BASE_DIR/docker-compose.yml" <<'YAML'
services:
  web_server:
    build:
      context: ./web
      dockerfile: Dockerfile
    container_name: web_server
    hostname: web_server
    networks:
      infra_red:
        ipv4_address: 172.20.0.10
    ports:
      - "8080:80"
    volumes:
      - web_content:/var/www/html
      - ftp_uploads:/var/www/html/uploads:ro
    mem_limit: 512m
    memswap_limit: 512m
    cpus: "0.5"
    depends_on: [postgres_db]
    restart: unless-stopped

  postgres_db:
    image: postgres:16-alpine
    container_name: postgres_db
    hostname: postgres_db
    networks:
      infra_red:
        ipv4_address: 172.20.0.20
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB:       practica10_db
      POSTGRES_USER:     practica10
      POSTGRES_PASSWORD: Practica10Pass!
    volumes:
      - db_data:/var/lib/postgresql/data
      - ./postgres/init_db.sql:/docker-entrypoint-initdb.d/init_db.sql:ro
      - ./postgres/backups:/backups
    mem_limit: 512m
    memswap_limit: 512m
    cpus: "0.5"
    restart: unless-stopped

  ftp_server:
    build:
      context: ./ftp
      dockerfile: Dockerfile
    container_name: ftp_server
    hostname: ftp_server
    networks:
      infra_red:
        ipv4_address: 172.20.0.30
    ports:
      - "21:21"
      - "21100-21110:21100-21110"
    environment:
      FTP_USER: ftpadmin
      FTP_PASS: FtpPass2024!
    volumes:
      - ftp_uploads:/ftp/uploads
    mem_limit: 256m
    memswap_limit: 256m
    cpus: "0.25"
    restart: unless-stopped

volumes:
  db_data:     { name: db_data,     driver: local }
  web_content: { name: web_content, driver: local }
  ftp_uploads: { name: ftp_uploads, driver: local }

networks:
  infra_red:
    name: infra_red
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1
YAML
}

# ── Copiar archivos separados al lugar correcto ──────────────────
link_external_files() {
    # init_db.sql ya debe existir en postgres/
    if [[ ! -f "$BASE_DIR/postgres/init_db.sql" ]]; then
        err "Falta postgres/init_db.sql — copia el archivo antes de desplegar"
        exit 1
    fi
    # ftp-entry.sh ya debe existir en ftp/
    if [[ ! -f "$BASE_DIR/ftp/ftp-entry.sh" ]]; then
        err "Falta ftp/ftp-entry.sh — copia el archivo antes de desplegar"
        exit 1
    fi
    chmod +x "$BASE_DIR/ftp/ftp-entry.sh"
    ok "Archivos externos verificados"
}

# ── Construir y levantar ─────────────────────────────────────────
build_and_up() {
    step "Construyendo imagenes..."
    docker compose -f "$BASE_DIR/docker-compose.yml" build --no-cache
    ok "Imagenes construidas"

    step "Levantando servicios..."
    docker compose -f "$BASE_DIR/docker-compose.yml" up -d
    ok "Servicios iniciados"

    step "Esperando que los servicios arranquen (20s)..."
    sleep 20

    echo ""
    echo -e "  ${C}══ Estado final ══${N}"
    for c in web_server postgres_db ftp_server; do
        s=$(docker inspect --format='{{.State.Status}}' "$c" 2>/dev/null || echo "no creado")
        [[ "$s" == "running" ]] && echo -e "  ${G}●${N} $c → RUNNING" || echo -e "  ${R}○${N} $c → $s"
    done

    echo ""
    echo -e "  ${W}Acceso:${N}"
    echo -e "  ${G}Web${N}      → http://localhost:8080"
    echo -e "  ${C}PostgreSQL${N}→ localhost:5432  |  practica10 / Practica10Pass!"
    echo -e "  ${Y}FTP${N}      → ftp://localhost  |  ftpadmin / FtpPass2024!"
}

# ── Main ─────────────────────────────────────────────────────────
echo ""
echo -e "${C}  ╔══════════════════════════════════════════════════╗${N}"
echo -e "${C}  ║       PRACTICA 10 - DESPLIEGUE COMPLETO          ║${N}"
echo -e "${C}  ║       Ubuntu Server · Docker Engine              ║${N}"
echo -e "${C}  ╚══════════════════════════════════════════════════╝${N}"
echo ""

check_docker
create_dirs
step "Generando Dockerfiles y configuraciones..."
gen_web_dockerfile
gen_web_html
gen_web_css
gen_ftp_dockerfile
gen_ftp_conf
gen_compose
ok "Archivos generados"
link_external_files
build_and_up
