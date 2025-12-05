#!/bin/bash

# Cores e Estilos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Nome do Sistema
NOME_SISTEMA="Dolutech WP Automation SO"

# Versões
PHP_VERSION="8.3"
APACHE_PORT="8091"
APACHE_SSL_PORT="8443"
VARNISH_PORT="6081"
VARNISH_ADMIN_PORT="6082"

# Caminhos
LOG_FILE="/var/log/dolutech_install.log"
FLAG_ARQUIVO="/etc/dolutech_wp_initial_setup_done"
BACKUP_DIR="/backup"

# URLs
VERSION_URL="https://raw.githubusercontent.com/dolutech/Dolutech-WP-Automation-SO/main/version.txt"
SCRIPT_URL="https://raw.githubusercontent.com/dolutech/Dolutech-WP-Automation-SO/main/Dolutech-WP-Automation-SO.sh"
MOD_PAGESPEED_URL="https://dl-ssl.google.com/dl/linux/direct/mod-pagespeed-stable_current_amd64.deb"
