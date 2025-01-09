#!/bin/bash

# Defina o URL do executável
ZIP_URL="https://nirooh-instalador.github.io/nirooh.zip"
ZIP_URL="nirooh.zip"
EXECUTABLE_NAME="nirooh"
INSTALL_DIR="/usr/local/bin"
CRON_JOB="*/15 * * * * $INSTALL_DIR/$EXECUTABLE_NAME"

# Função para verificar se o usuário é root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Este script precisa ser executado como root. Use sudo." >&2
        exit 1
    fi
}

# Verificar e instalar dependências (unzip)
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

# Baixar o arquivo zip
download_zip() {
    echo "Baixando o arquivo zip de $ZIP_URL..."
    curl -o "/tmp/$ZIP_NAME" "$ZIP_URL"
    if [[ $? -ne 0 ]]; then
        echo "Falha ao baixar o arquivo zip." >&2
        exit 1
    fi
    echo "Arquivo zip baixado em /tmp/$ZIP_NAME."
}

# Descompactar o arquivo zip
unzip_executable() {
    echo "Descompactando o arquivo zip..."
    unzip -o "/tmp/$ZIP_NAME" -d "/tmp/"
    if [[ $? -ne 0 ]]; then
        echo "Falha ao descompactar o arquivo zip." >&2
        exit 1
    fi
    if [[ ! -f "/tmp/$EXECUTABLE_NAME" ]]; then
        echo "Executável não encontrado no zip." >&2
        exit 1
    fi
    mv "/tmp/$EXECUTABLE_NAME" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$EXECUTABLE_NAME"
    echo "Executável instalado em $INSTALL_DIR."
}

# Configurar o cron
setup_cron() {
    echo "Configurando o crontab para rodar a cada 15 minutos..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    if [[ $? -eq 0 ]]; then
        echo "Crontab configurado com sucesso."
    else
        echo "Falha ao configurar o crontab." >&2
        exit 1
    fi
}

# Execução principal
main() {
    check_root
    install_dependencies
    download_zip
    unzip_executable
    setup_cron
}

main
