#!/bin/bash

ZIP_URL="https://nirooh-instalador.github.io/nirooh-linux-ubuntu-22-04.zip"
ZIP_NAME="nirooh-linux-ubuntu-22-04.zip"
EXECUTABLE_NAME="nirooh"
INSTALL_DIR="/usr/local/bin"
CRON_JOB="*/15 * * * * $INSTALL_DIR/$EXECUTABLE_NAME"

check_root() {
    if [ "$EUID" -ne "0" ]; then
        echo "Este script precisa ser executado como root. Use sudo." >&2
        exit 1
    fi
}

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

download_zip() {
    echo "Baixando o arquivo zip de $ZIP_URL..."
    curl -o "/tmp/$ZIP_NAME" "$ZIP_URL"
    if [ $? -ne 0 ]; then
        echo "Falha ao baixar o arquivo zip." >&2
        exit 1
    fi
    echo "Arquivo zip baixado em /tmp/$ZIP_NAME."
}

unzip_executable() {
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
