#!/bin/bash

SISTEMA="Ubuntu"
VERSAO="24.04"

ZIP_NAME="nirooh-linux-ubuntu-24-04.tar.gz"
URL_NIROOH="https://instalador.nirooh.com"
ZIP_URL="$URL_NIROOH/$ZIP_NAME"

EXECUTABLE_NAME="nirooh"
INSTALL_DIR="$HOME/.local/bin"


atualizar_path() {
    mkdir -p "$INSTALL_DIR/"

    if ! grep -qx 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi

    if ! grep -qx 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.profile"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
    fi

    # Adiciona ao PATH da sessão atual somente se ainda não estiver presente
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac

    echo "PATH atualizado -> $PATH"
}


identificar_sistema() {
    [ "$(uname -s)" = "Linux" ] || error 'This script is intended to run on Linux only.'

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        SISTEMA="$ID"
        VERSAO="$VERSION_ID"

    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        SISTEMA="$DISTRIB_ID"
        VERSAO="$DISTRIB_RELEASE"

    elif [ -f /etc/debian_version ]; then
        SISTEMA="debian"
        VERSAO=$(cat /etc/debian_version)

    elif [ -f /etc/redhat-release ]; then
        # Red Hat, CentOS e derivados
        SISTEMA=$(cat /etc/redhat-release | cut -d " " -f 1)
        VERSAO=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+')
    fi

    echo "Sistema detectado: $SISTEMA $VERSAO"
}


selecionar_zip() {
    if [ "$SISTEMA" = "ubuntu" ]; then
        if [ "$VERSAO" = "20.04" ]; then
            ZIP_NAME="nirooh-linux-ubuntu-20-04.tar.gz"
        elif [ "$VERSAO" = "22.04" ]; then
            ZIP_NAME="nirooh-linux-ubuntu-22-04.tar.gz"
        elif [ "$VERSAO" = "24.04" ]; then
            ZIP_NAME="nirooh-linux-ubuntu-24-04.tar.gz"
        fi
    fi

    ZIP_URL="$URL_NIROOH/$ZIP_NAME"

    echo "zip selecionado $ZIP_URL"
}


enable_linger() {
    if command -v loginctl &>/dev/null; then
        echo "Ativando linger para $USER..."
        loginctl enable-linger "$USER"
        if [ $? -eq 0 ]; then
            echo "Linger ativado com sucesso para $USER."
        else
            echo "Falha ao ativar linger." >&2
            exit 1
        fi
    else
        echo "Comando loginctl não encontrado. O serviço pode não iniciar no boot."
    fi
}


download_tar() {
    echo "Baixando o arquivo tar de $ZIP_URL..."
    curl -o "/tmp/$ZIP_NAME" "$ZIP_URL"
    if [ $? -ne 0 ]; then
        echo "Falha ao baixar o arquivo tar.gz." >&2
        exit 1
    fi
    echo "Arquivo tar.gz baixado em /tmp/$ZIP_NAME."
}


extract_tar() {
    echo "Descompactando o arquivo tar.gz..."
    tar -xzf "/tmp/$ZIP_NAME" -C "/tmp/"
    if [ $? -ne 0 ]; then
        echo "Falha ao descompactar o tar.gz." >&2
        exit 1
    fi
    if [ ! -f "/tmp/$EXECUTABLE_NAME" ]; then
        echo "Executável não encontrado no tar.gz." >&2
        exit 1
    fi
    mv "/tmp/$EXECUTABLE_NAME" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$EXECUTABLE_NAME"
    echo "Executável instalado em $INSTALL_DIR/$EXECUTABLE_NAME."
}


setup_systemd() {
    SERVICE_FILE="$HOME/.config/systemd/user/nirooh.service"
    mkdir -p "$HOME/.config/systemd/user/"

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Execução contínua do Nirooh Player
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$EXECUTABLE_NAME
Restart=always
RestartSec=5
User=$USER

[Install]
WantedBy=default.target
EOF

    chmod 644 $SERVICE_FILE
    # com --user ou nao?
    systemctl --user daemon-reload
    systemctl --user enable nirooh.service
    systemctl --user start nirooh.service

    echo "Servico $SERVICE_FILE ativado"

    systemctl --user status nirooh.service
}


main() {
    atualizar_path
    identificar_sistema
    selecionar_zip
    enable_linger
    download_tar
    extract_tar
    setup_systemd
}


main


"$INSTALL_DIR/$EXECUTABLE_NAME" &
