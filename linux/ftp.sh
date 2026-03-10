#!/bin/bash
source /home/srv-linux-server/SCRIPS2/FUNCIONES/instalacion.sh
source /home/srv-linux-server/SCRIPS2/FUNCIONES/status.sh

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
    
    # Se usa 777 para que todos escriban/eliminen. 
    # Si quieres que SOLO el dueño borre lo suyo, usa chmod 1777 (Sticky Bit)
    sudo chown ftp:nogroup "$Genera"
    sudo chmod 777 "$Genera"
    
    sudo chown root:root "$gruposC"
    sudo chmod 711 "$gruposC"
    for grupo in "${GRUPOS[@]}"; do
        [ ! -d "$gruposC/$grupo" ] && sudo mkdir -p "$gruposC/$grupo"
        sudo chown ftp:$grupo "$gruposC/$grupo"
        sudo chmod 775 "$gruposC/$grupo"
    done
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
        
        sudo chown -R "$nomU:$gpp" "$usuarioH"
        sudo chmod 755 "$usuarioH"
        
        # Permiso total en el punto de montaje para permitir borrado
        sudo chmod 777 "$usuarioH/general"
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
# umask 000 permite que lo creado tenga permisos totales (777)
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
EOF

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
    sudo umount -l "$usuarioH/reprobados" 2>/dev/null
    sudo umount -l "$usuarioH/recursadores" 2>/dev/null
    sudo umount -l "$usuarioH/general" 2>/dev/null
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
    
    # Asegurar permisos de borrado tras reubicar
    sudo chmod 777 "$usuarioH/general"
    
    echo -e "Usuario $nomU reubicado"
    read -p "ENTER PARA VOLVER"
}

archivos
servicios
sudo ufw allow 21/tcp
sudo ufw allow 40000:50000/tcp
sudo ufw reload

while true; do
    clear
    echo "--- MENU DE FTP REPARADO ---"
    echo "1) Instalar"
    echo "2) Estado del servicio"
    echo "3) Agregar usuarios"
    echo "4) Reubicar usuario"
    echo "5) Salir"
    read -p "OPCION: " opc
    case $opc in
        1) instalar ;;
        2) verificar ;;
        3) agg_users ;;
        4) reubicar ;;
        5) exit 0 ;;
    esac
done