#!/bin/bash
source /home/srv-linux-server/SCRIPS2/FUNCIONES/instalacion.sh
source /home/srv-linux-server/SCRIPS2/FUNCIONES/status.sh
Activador(){
    clear
    echo "ACTIVANDO SERVIDOR SSH..."
    sudo systemctl enable ssh 
    sudo systemctl restart ssh
    sudo ufw allow 22/tcp
    IP_FINAL=$(ip -4 addr show enp0s9 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    echo "------------------------------------------------"
    if systemctl is-active --quiet ssh; then
        echo "ESTADO: SERVIDOR ACTIVO"
        if [ -n "$IP_FINAL" ]; then
            echo "SERVIDOR ESCUCHANDO EN: $IP_FINAL"
        else
            echo "SERVIDOR ACTIVO (No se detectó IP en enp0s9)"
        fi
    else
        echo "ESTADO: ERROR AL INICIAR EL SERVICIO"
    fi
    echo "------------------------------------------------"
    
    read -p "PRESIONE ENTER PARA VOLVER AL MENU...."
}
while true; do
clear
    echo "***********SERVIDOR SSH*********"
    echo "-SELECCIONE UNA OPCION:"
    echo "1) Instalar"
    echo "2) Estado"
    echo "3) Activar"
    echo "4) Salir"
    read -p "Opcion: " opc
    case $opc in
        1) verificacion_instalacion "openssh-server" ;;
        2) verificador_status "ssh" ;;
        3) Activador ;;
        4) echo "Cerrando script..." 
            clear 
            exit 0 ;;
        *) echo "Opción inválida." ;;

    esac
done
