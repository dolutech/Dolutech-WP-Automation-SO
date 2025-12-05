#!/bin/bash

source "$(dirname "$0")/modulos/config.sh"

# Função de log
function log {
    local message="$1"
    local type="$2"
    local color="$NC"

    case "$type" in
        "INFO") color="$GREEN" ;;
        "WARN") color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
    esac

    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] [$type] $message${NC}" | tee -a "$LOG_FILE"
}

# Verificar se é root
function check_root {
    if [ "$EUID" -ne 0 ]; then
        log "Por favor, execute como root." "ERROR"
        exit 1
    fi
}

# Função para verificar dependências binárias
function check_binary {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# Verificar e instalar utilitários básicos (zip, unzip, curl, wget, git)
function install_utils {
    log "Verificando utilitários básicos..." "INFO"
    local packages=("zip" "unzip" "curl" "wget" "git" "figlet")
    local install_list=""

    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -qw "$pkg"; then
            install_list="$install_list $pkg"
        fi
    done

    if [ -n "$install_list" ]; then
        log "Instalando: $install_list" "INFO"
        apt-get update && apt-get install -y $install_list
    fi
}

# Gerar senha aleatória
function generate_password {
    openssl rand -base64 "${1:-12}"
}
