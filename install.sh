#!/bin/bash

# Defina o URL do executável
EXECUTABLE_URL="https://https://nirooh-instalador.github.io/nirooh.zip"
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

# Baixar o executável
download_executable() {
    echo "Baixando o executável de $EXECUTABLE_URL..."
    curl -o "$INSTALL_DIR/$EXECUTABLE_NAME" "$EXECUTABLE_URL"
    if [[ $? -ne 0 ]]; then
        echo "Falha ao baixar o executável." >&2
        exit 1
    fi
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
    download_executable
    setup_cron
}

main
