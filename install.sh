#!/bin/bash

ZIP_NAME="nirooh-linux-ubuntu-22-04.tar.gz"

EXECUTABLE_NAME="nirooh"
INSTALL_DIR="/usr/local/bin"
CRON_JOB="*/15 * * * * $INSTALL_DIR/$EXECUTABLE_NAME"


if [[ $(lsb_release -i | grep -i "Ubuntu") ]]; then
    versao=$(lsb_release -sr)
    echo "O sistema é Ubuntu $versao"
    case $versao in
        "20.04")
            ZIP_NAME="nirooh-linux-ubuntu-20-04.tar.gz"
            ;;
        "22.04")
            ZIP_NAME="nirooh-linux-ubuntu-22-04.tar.gz"
            ;;
        "24.04")
            ZIP_NAME="nirooh-linux-ubuntu-24-04.tar.gz"
            ;;
        *)
            echo "Versão do Ubuntu não reconhecida: $versao"
            ;;
    esac
else
    echo "Não encontrada versão especifica compativel."
    echo "Será usada versão default, $ZIP_NAME"
    exit 1
fi

ZIP_URL="https://instalador.nirooh.com/$ZIP_NAME"


# TODO: Nao sei se o cliente tem permissao de root
# entao precisa instalar no usuario atual
check_root() {
    ## Pode usar o $USER -eq 
    if [ "$EUID" -ne "0" ]; then
        echo "Este script precisa ser executado como root. Use sudo." >&2
        # Mas não precisa mais, por causa do targz
        exit 1
    fi
}


# TODO: Trocar dependencia zip, por tar.gz
install_dependencies() {
    if ! command -v unzip &>/dev/null; then
        echo "Instalando a dependência 'unzip'..."
        apt-get update && apt-get install -y unzip
        if [[ $? -ne 0 ]]; then
            echo "Falha ao instalar o 'unzip'." >&2
            exit 1
        fi
    fi
}

# TODO: Atualizar o curl
download_zip() {
    echo "Baixando o arquivo zip de $ZIP_URL..."
    curl -o "/tmp/$ZIP_NAME" "$ZIP_URL"
    if [ $? -ne 0 ]; then
        echo "Falha ao baixar o arquivo zip." >&2
        exit 1
    fi
    echo "Arquivo zip baixado em /tmp/$ZIP_NAME."
}


# TODO: Atualizar unzip com tar.gz
unzip_executable() {
    sudo apt-get install unzip -y
    echo "Descompactando o arquivo zip..."
    unzip -o "/tmp/$ZIP_NAME" -d "/tmp/"
    if [ $? -ne 0 ]; then
        echo "Falha ao descompactar o arquivo zip." >&2
        exit 1
    fi
    if [ ! -f "/tmp/$EXECUTABLE_NAME" ]; then
        echo "Executável não encontrado no zip." >&2
        exit 1
    fi
    mv "/tmp/$EXECUTABLE_NAME" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$EXECUTABLE_NAME"
    echo "Executável instalado em $INSTALL_DIR."
}


# TODO: atualizar de cron para systemctl
setup_cron() {
    echo "Verificando se o crontab já está configurado..."
    EXISTING_CRON=$(crontab -l 2>/dev/null | grep -F "$INSTALL_DIR/$EXECUTABLE_NAME")
    if [ -z "$EXISTING_CRON" ]; then
        echo "Configurando o crontab para rodar a cada 15 minutos..."
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        if [ $? -eq 0 ]; then
            echo "Crontab configurado com sucesso."
        else
            echo "Falha ao configurar o crontab." >&2
            exit 1
        fi
    else
        echo "Crontab já está configurado para este executável."
    fi
}

main() {
    check_root
    install_dependencies
    download_zip
    unzip_executable
    setup_cron
}

main

"$INSTALL_DIR/$EXECUTABLE_NAME" &
