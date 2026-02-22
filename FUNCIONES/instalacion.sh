#!/bin/bash
verificacion_instalacion(){
    local paquete="$1"
 echo "VERIFICANDO SERVIDOR..."
    if dpkg -l | grep -q "$paquete"; then
        echo "ESTADO: INSTALADO"
    else
        echo "INSTALANDO SERVIDOR..."
        sudo apt-get install -y $paquete  >/dev/null 2>&1
    fi
        read -p "PRESIONE ENTER PARA SALIR...."
}