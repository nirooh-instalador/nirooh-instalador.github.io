#!/bin/bash

set -eu # Interrompe em caso de erro e falhas em pipes
umask 022  # Define permissoes seguras

SISTEMA="Ubuntu"
VERSAO="24.04"

ZIP_BASE="nirooh-linux-ubuntu"
ZIP_NAME="$ZIP_BASE-24-04.tar.gz"
URL_NIROOH="https://instalador.nirooh.com"
ZIP_URL="$URL_NIROOH/$ZIP_NAME"

EXECUTABLE_NAME="nirooh"
INSTALL_DIR="$HOME/.local/bin"

SYSTEMD_CONFIGURADO=0

atualizar_path() {
    mkdir -p "$INSTALL_DIR"

    if ! grep -qx "export PATH=\"\$HOME/.local/bin:\$PATH\"" "$HOME/.profile"; then
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.profile"
    fi

    # Adiciona ao PATH da sessão atual somente se ainda não estiver presente
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac

    echo "PATH atualizado -> $PATH"
}


identificar_sistema() {
    [ "$(uname -s)" = "Linux" ] || { echo "Apenas para Linux"; exit 1; }

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
        SISTEMA=$(awk '{print $1}' /etc/redhat-release)
        VERSAO=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release)
    else
        echo "Sistema não reconhecido"; exit 1
    fi

    # Normaliza sistema para minúsculas e versão para MAIOR.MENOR
    SISTEMA=$(printf "%s" "$SISTEMA" | tr '[:upper:]' '[:lower:]')
    VERSAO=$(printf "%s" "$VERSAO" | awk -F. '{print $1 "." $2}')

    echo "Sistema detectado: $SISTEMA $VERSAO"
}


validar_versao() {
    case "$SISTEMA" in
        ubuntu)
            case "$VERSAO" in
                16.04|22.04|24.04)
                    return 0 ;;
                *)
                    echo "Versão do Ubuntu não suportada: $VERSAO. Suportadas: 16.04, 22.04, 24.04." >&2
                    exit 1 ;;
            esac
            ;;
        *)
            echo "Distribuição não suportada: $SISTEMA. Apenas Ubuntu (16.04, 22.04, 24.04) é suportado no momento." >&2
            exit 1 ;;
    esac
}

selecionar_zip() {
    if [ "$SISTEMA" = "ubuntu" ]; then
        if [ "$VERSAO" = "16.04" ]; then
            ZIP_NAME="$ZIP_BASE-16-04.tar.gz"
        elif [ "$VERSAO" = "22.04" ]; then
            ZIP_NAME="$ZIP_BASE-22-04.tar.gz"
        elif [ "$VERSAO" = "24.04" ]; then
            ZIP_NAME="$ZIP_BASE-24-04.tar.gz"
        else
            echo "Versão do Ubuntu não suportada: $VERSAO." >&2
            exit 1
        fi
    else
        echo "Distribuição não suportada para seleção de pacote: $SISTEMA" >&2
        exit 1
    fi

    ZIP_URL="$URL_NIROOH/$ZIP_NAME"

    echo "zip selecionado $ZIP_URL"
}


enable_linger() {
    if command -v loginctl &>/dev/null; then
        echo "Ativando linger para $USER..."
        loginctl enable-linger "$USER" && echo "Linger ativado com sucesso para $USER."
    else
        echo "Comando loginctl não encontrado. O serviço pode não iniciar no boot."
    fi
}


download_tar() {
    echo "Baixando o arquivo tar de $ZIP_URL..."
    curl -fLo "/tmp/$ZIP_NAME" "$ZIP_URL"
    echo "Arquivo tar.gz baixado em /tmp/$ZIP_NAME."
}


extract_tar() {
    echo "Descompactando o arquivo tar.gz..."
    tar -xzf "/tmp/$ZIP_NAME" -C "/tmp/"

    # Tenta localizar o executável extraído (direto na raiz ou dentro de diretórios)
    local EXTRAIDO_EXEC
    if [ -f "/tmp/$EXECUTABLE_NAME" ]; then
        EXTRAIDO_EXEC="/tmp/$EXECUTABLE_NAME"
    else
        EXTRAIDO_EXEC=$(find "/tmp" -maxdepth 3 -type f -name "$EXECUTABLE_NAME" -perm -u+x 2>/dev/null | head -n1 || true)
    fi

    if [ -z "${EXTRAIDO_EXEC:-}" ] || [ ! -f "$EXTRAIDO_EXEC" ]; then
        echo "Executável não encontrado no conteúdo do tar.gz." >&2
        exit 1
    fi

    mv "$EXTRAIDO_EXEC" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$EXECUTABLE_NAME"
    echo "Executável instalado em $INSTALL_DIR/$EXECUTABLE_NAME."
}


setup_systemd() {
    local SERVICE_FILE="$HOME/.config/systemd/user/nirooh.service"
    mkdir -p "$HOME/.config/systemd/user/"

    if ! command -v systemctl >/dev/null 2>&1; then
        echo "systemctl não disponível; pulando configuração do systemd de usuário."
        SYSTEMD_CONFIGURADO=0
        return 0
    fi

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Nirooh Player
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$EXECUTABLE_NAME
Restart=always
RestartSec=5
User=$USER
Group=$USER

[Install]
WantedBy=default.target
EOF

    if systemctl --user daemon-reload && systemctl --user enable --now nirooh.service; then
        SYSTEMD_CONFIGURADO=1
        echo "Servico $SERVICE_FILE ativado"
    else
        SYSTEMD_CONFIGURADO=0
        echo "Falha ao ativar serviço de usuário via systemd; será usado fallback (cron) se habilitado."
    fi
}


arquivo_desktop() {
    # Criando o arquivo .desktop para iniciar o Nirooh Player automaticamente no boot
    local DESKTOP_FILE="$HOME/.config/autostart/nirooh.desktop"
    mkdir -p "$HOME/.config/autostart/"
    touch "$INSTALL_DIR/nirooh.png"

    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Exec=$INSTALL_DIR/$EXECUTABLE_NAME --minimize
Icon=$INSTALL_DIR/nirooh.png
Version=1.0
Type=Application
Categories=Player
Name=Nirooh Player
StartupWMClass=nirooh
Terminal=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
X-GNOME-Autostart-Delay=10
X-MATE-Autostart-Delay=10
X-KDE-autostart-after=panel
EOF

    echo "Autostart $DESKTOP_FILE ativado"
}


setup_cron() {
    echo "Verificando se o crontab ja esta configurado..."
    if crontab -l 2>/dev/null | grep -qF "$INSTALL_DIR/$EXECUTABLE_NAME"; then
        echo "Crontab ja esta configurado para este executavel."
    else
        echo "Configurando o crontab para rodar a cada 5 minutos..."
        local CRON_JOB="*/5 * * * * $INSTALL_DIR/$EXECUTABLE_NAME"
        echo "CRON_JOB -> $CRON_JOB"
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "Crontab configurado com sucesso."
    fi
}


main() {
    atualizar_path
    identificar_sistema
    validar_versao
    selecionar_zip
    enable_linger
    download_tar
    extract_tar
    setup_systemd
    arquivo_desktop
    # Usa cron apenas se systemd não foi configurado
    if [ "$SYSTEMD_CONFIGURADO" -ne 1 ]; then
        setup_cron
    fi
}


main
