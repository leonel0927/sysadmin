verificador_status(){
    local estado="$1"
    sudo systemctl is-active --quiet $1 && echo "FUNCIONANDO" || echo "ERROR / DETENIDO"
        read -p "PRESIONE ENTER PARA SALIR...."
}