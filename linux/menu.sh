#!/bin/bash
clear
while true; do
echo "********* BIENVENIDO AL SERVIDOR LINUX************"
echo "--SELECCIONE UNA OPCION:"
    echo "1) DHCP"
    echo "2) DNS"
    echo "3) SSH"
    echo "4) FTP"
    echo "5) HTTP"
    echo "6) Practica 7"
    echo "7) Dockers"
    echo "8) Salir"
    read -p "SELECCIONE UNA OPCION: " opcion
    case $opcion in
    1)bash ./dhcp.sh ;;
    2)bash ./dns.sh ;;
    3)bash ./ssh.sh ;;
    4)bash ./ftp.sh ;;
    5)bash ./http.sh ;;
    6)bash ./practica7.sh ;;
    7) practica10/menuD.sh;;
    8) echo "Saliendo.."
        exit 0 ;;
    *) 
        echo "Opcion no válida."
        sleep 1 ;;
    esac
done
clear   