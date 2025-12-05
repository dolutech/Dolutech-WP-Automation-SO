#!/bin/bash

# Dolutech WP Automation SO - Instalação Completa do WordPress com Apache, MariaDB, PHP, phpMyAdmin, Redis, Nginx, Varnish, mod_pagespeed
# Desenvolvido por: Lucas Catão de Moraes
# Sou especialista em Cibersegurança, Big Data e Privacidade de dados
# E-mail: lucas@dolutech.com
# Site: https://dolutech.com
# Licenciado sob GPLv3 - https://www.gnu.org/licenses/gpl-3.0.html
# Sou apaixonado por Café que tal me pagar um?: https://www.paypal.com/paypalme/cataodemoraes

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

if ! command -v figlet &> /dev/null; then
    sudo apt-get update && sudo apt-get install figlet -y
fi
ASCII_ART=$(figlet "Dolutech WP Automation OS")

echo "$ASCII_ART"
echo "=========================================="
echo "Bem-vindo ao $NOME_SISTEMA"
echo "Versão: 0.2 (Modular)"
echo "Para executar nosso menu, digite: dolutech"
echo "Desenvolvido por: Lucas Catão de Moraes"
echo "Site: https://dolutech.com"
echo "Gostou do projeto? Paga-me um café: https://www.paypal.com/paypalme/cataodemoraes"
echo "Feito com Amor para a comunidade de língua Portuguesa ❤"
echo "Precisa de suporte ou ajuda? Nos envie um e-mail para: lucas@dolutech.com"
echo "=========================================="

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
