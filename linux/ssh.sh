#!/bin/bash
source /home/srv-linux-server/SCRIPS2/FUNCIONES/instalacion.sh
source /home/srv-linux-server/SCRIPS2/FUNCIONES/status.sh
Activador(){
    clear
    sudo killall -9 sshd 2>/dev/null
    echo "ACTIVANDO SERVIDOR"
    sudo ip addr flush dev enp0s8
    sudo systemctl start ssh
    sudo systemctl enable ssh
    sudo ip addr add 192.168.1.1/24 dev enp0s8
    echo "SERVIDOR ACTIVADO CON LA IP: 192.168.1.1"
    read -p "PRESIONE ENTER PARA SALIR...."
}
Desactivador(){
    clear
    echo "DESACTIVANDO SERVIDOR"
    sudo systemctl stop ssh
    sudo systemctl disable ssh
    echo "SERVIDOR DESACTIVADO"
    read -p "PRESIONE ENTER PARA SALIR...."
}
while true; do
clear
    echo "***********SERVIDOR SSH*********"
    echo "-SELECCIONE UNA OPCION:"
    echo "1) Instalar"
    echo "2) Estado"
    echo "3) Activar"
    echo "4) Desactivar"
    echo "5) Salir"
    read -p "Opcion: " opc
    case $opc in
        1) verificacion_instalacion "openssh-server" ;;
        2) verificador_status "ssh" ;;
        3) Activador ;;
        4) Desactivador ;;
        5) echo "Cerrando script..." 
            clear 
            exit 0 ;;
        *) echo "Opción inválida." ;;

    esac
done
