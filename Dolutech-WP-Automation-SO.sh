#!/bin/bash

# Dolutech WP Automation SO - Bootstrapper
# Refactored Version

# Define o diretório base
BASE_DIR="$(dirname "$(realpath "$0")")"
cd "$BASE_DIR"

# Importar configurações e módulos
if [ -f "modulos/config.sh" ]; then
    source "modulos/config.sh"
else
    echo "Erro: Arquivo modulos/config.sh não encontrado."
    echo "Certifique-se de ter clonado o repositório completo."
    exit 1
fi

source "modulos/utils.sh"
source "modulos/install_stack.sh"
source "modulos/menu.sh"

# Verificação de root
check_root

# Argument Handling for Automation (Cron)
if [ "$1" == "backup" ]; then
    # Usage: ./script.sh backup <domain> <type>
    DOMINIO=$2
    BACKUP_OPTION=$3
    fazer_backup "$DOMINIO" "$BACKUP_OPTION"
    exit 0
elif [ "$1" == "renew_ssl" ]; then
    atualizar_certificados_ssl
    exit 0
fi

# Boas vindas (Interactive Mode)
clear
if command -v figlet &> /dev/null; then
    figlet "Dolutech WP Auto"
else
    echo "================= Dolutech WP Automation SO ================="
fi
echo "Versão: $VERSAO_LOCAL"

# Verificar instalação inicial
if [ ! -f "$FLAG_ARQUIVO" ]; then
    log "Instalação inicial não detectada. Iniciando setup..." "INFO"
    instalar_dependencias_iniciais
else
    log "Sistema já configurado." "INFO"
fi

# Configurar Alias se necessário
if ! grep -q "alias dolutech=" ~/.bashrc; then
    echo "alias dolutech='sudo $BASE_DIR/Dolutech-WP-Automation-SO.sh'" >> ~/.bashrc
    log "Alias 'dolutech' adicionado." "INFO"
fi

# Loop do Menu
menu_wp
