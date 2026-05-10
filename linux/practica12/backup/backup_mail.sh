#!/bin/bash
# Script de respaldo de buzones - Practica 12
BACKUP_DIR="/home/srv-linux-server/SCRIPS2/linux/practica12/backup"
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
