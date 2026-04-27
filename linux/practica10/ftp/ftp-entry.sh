#!/bin/sh
# ================================================================
#  ftp-entry.sh - Entrypoint del contenedor FTP
#  Configura usuario dinamico y arranca vsftpd
# ================================================================

FTP_USER="${FTP_USER:-ftpadmin}"
FTP_PASS="${FTP_PASS:-FtpPass2024!}"

echo "[FTP] Configurando usuario: $FTP_USER"

# Crear usuario con password recibido por variable de entorno
adduser -D -h /ftp -s /bin/false "$FTP_USER" 2>/dev/null || true
echo "${FTP_USER}:${FTP_PASS}" | chpasswd

# Permisos correctos: root dueño del chroot, usuario dueño de uploads
chown root:root /ftp
chmod 755 /ftp
mkdir -p /ftp/uploads
chown "$FTP_USER":ftpgroup /ftp/uploads
chmod 775 /ftp/uploads

echo "[FTP] Directorio listo: /ftp/uploads"
echo "[FTP] Iniciando vsftpd..."

exec vsftpd /etc/vsftpd/vsftpd.conf
