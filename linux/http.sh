#!/bin/bash
source "/home/srv-linux-server/SCRIPS2/linux/httpF.sh"
instalacion() {
    clear
    echo "--- SELECCIÓN DE SERVIDOR ---"
    echo "1) Apache2"
    echo "2) Nginx"
    echo "3) Tomcat"
    read -p "Seleccione el servicio: " tipo_serv

    case $tipo_serv in
        1) serv="apache2" ;;
        2) serv="nginx" ;;
        3) serv="tomcat9" ;; 
        *) echo "Opción inválida"; sleep 2; return ;;
    esac
   consultar_versiones_dinamico "$serv"
    read -p "Elija opción 1) Latest, 2) Estable (Enter para opción 1): " opcion_ver
    mapfile -t VERSIONES < <(apt-cache madison "$serv" | awk '{print $3}')
if [[ "$opcion_ver" == "2" && ${#VERSIONES[@]} -gt 1 ]]; then
    ver_elegida=${VERSIONES[1]}
    echo "[INFO] Seleccionada Versión Estable: $ver_elegida"
else
    ver_elegida=${VERSIONES[0]}
    echo "[INFO] Seleccionada Versión Latest: $ver_elegida"
fi
    while true; do
        read -p "Ingrese el puerto para $serv : " port
        if validar_puerto "$port"; then
            break
        fi
    done
    case $tipo_serv in
        1) instalar_apache "$ver_elegida" "$port" ;;
        2) instalar_nginx "$ver_elegida" "$port" ;;
        3) instalar_tomcat "$ver_elegida" "$port" ;;
    esac

    echo -e "\nInstalación completada. Presione Enter para volver al menú."
    read
}
while true; do
    clear
    echo "******************************************"
    echo "    SISTEMA DE APROVISIONAMIENTO WEB     "
    echo "******************************************"
    echo "1) Instalar Servidor HTTP"
    echo "2) Listar puertos activos"
    echo "3) Salir"
    read -p "INGRESE SU OPCIÓN: " opc
    
    case $opc in
        1) instalacion ;;
        2) listar_puertos_activos ;;
        3) echo "Saliendo..."; exit 0 ;;
        *) echo "Opción no válida"; sleep 1 ;;
    esac
done