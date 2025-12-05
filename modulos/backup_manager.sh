#!/bin/bash

source "$(dirname "$0")/modulos/config.sh"
source "$(dirname "$0")/modulos/utils.sh"

function fazer_backup {
    local DOMINIO=$1
    local BACKUP_OPTION=$2

    # Definir o PATH
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Definir HOME se não estiver definido
    if [ -z "$HOME" ]; then
        HOME=$(getent passwd $(whoami) | cut -d: -f6)
    fi

    check_binary "zip" || install_utils

    # Se não passado, perguntar
    if [ -z "$DOMINIO" ]; then
        listar_instalacoes
        read -p "Domínio para backup: " DOMINIO
    fi

    if [ ! -d "/var/www/$DOMINIO/public_html" ]; then
        log "Domínio não encontrado." "ERROR"
        return
    fi

    mkdir -p "$BACKUP_DIR"
    local DATA=$(date +"%Y%m%d-%H%M%S")
    local BACKUP_FILE="$BACKUP_DIR/${DOMINIO}_backup_$DATA.zip"

    # DB Export
    WP_CONFIG="/var/www/$DOMINIO/public_html/wp-config.php"
    if [ ! -f "$WP_CONFIG" ]; then
        log "wp-config.php não encontrado." "ERROR"
        return
    fi

    DB_NAME=$(grep "DB_NAME" "$WP_CONFIG" | awk -F "'" '{print $4}')
    DB_USER=$(grep "DB_USER" "$WP_CONFIG" | awk -F "'" '{print $4}')
    DB_PASS=$(grep "DB_PASSWORD" "$WP_CONFIG" | awk -F "'" '{print $4}')

    if [ -z "$DB_USER" ] || [ -z "$DB_NAME" ] || [ -z "$DB_PASS" ]; then
        log "Erro ao ler credenciais do DB." "ERROR"
        return
    fi

    local DB_BACKUP_DIR="/var/www/$DOMINIO/public_html/db"
    mkdir -p "$DB_BACKUP_DIR"

    log "Exportando banco de dados $DB_NAME..." "INFO"
    mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$DB_BACKUP_DIR/${DB_NAME}_backup.sql"

    if [ $? -ne 0 ]; then
        log "Erro no mysqldump." "ERROR"
        return
    fi

    log "Compactando arquivos..." "INFO"
    zip -r "$BACKUP_FILE" "/var/www/$DOMINIO/public_html" > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        log "Erro ao criar ZIP." "ERROR"
        return
    fi

    # Limpar dump
    rm -rf "$DB_BACKUP_DIR"
    log "Backup salvo em $BACKUP_FILE" "INFO"

    # FTP Logic
    local ENVIAR_FTP="n"
    if [ "$BACKUP_OPTION" == "ftp" ]; then
        ENVIAR_FTP="s"
    elif [ "$BACKUP_OPTION" != "local" ]; then
        read -p "Deseja enviar para FTP? (s/n): " ENVIAR_FTP
    fi

    if [ "$ENVIAR_FTP" == "s" ]; then
        if ! command -v lftp &> /dev/null; then
             apt-get update && apt-get install -y lftp
        fi

        FTP_CREDENTIALS_FILE="$HOME/.ftp_credentials"
        if [ -f "$FTP_CREDENTIALS_FILE" ]; then
            source "$FTP_CREDENTIALS_FILE"
        else
            read -p "FTP Server: " FTP_SERVIDOR
            read -p "FTP User: " FTP_USUARIO
            read -s -p "FTP Pass: " FTP_SENHA
            echo
            read -p "FTP Port (21): " FTP_PORTA
            FTP_PORTA=${FTP_PORTA:-21}
            read -p "FTP Path (/): " FTP_PASTA
            FTP_PASTA=${FTP_PASTA:-"/"}

            read -p "Salvar credenciais? (s/n): " SAVE
            if [ "$SAVE" == "s" ]; then
                echo "FTP_SERVIDOR='$FTP_SERVIDOR'" > "$FTP_CREDENTIALS_FILE"
                echo "FTP_USUARIO='$FTP_USUARIO'" >> "$FTP_CREDENTIALS_FILE"
                echo "FTP_SENHA='$FTP_SENHA'" >> "$FTP_CREDENTIALS_FILE"
                echo "FTP_PORTA='$FTP_PORTA'" >> "$FTP_CREDENTIALS_FILE"
                echo "FTP_PASTA='$FTP_PASTA'" >> "$FTP_CREDENTIALS_FILE"
                chmod 600 "$FTP_CREDENTIALS_FILE"
            fi
        fi

        log "Enviando para FTP..." "INFO"
        lftp -u "$FTP_USUARIO","$FTP_SENHA" -p "$FTP_PORTA" "$FTP_SERVIDOR" <<EOF
put "$BACKUP_FILE" -o "$FTP_PASTA/$(basename "$BACKUP_FILE")"
bye
EOF
        if [ $? -eq 0 ]; then
            log "Upload FTP concluído." "INFO"
        else
            log "Erro no upload FTP." "ERROR"
        fi
    fi

    # Agendamento
    if [ -z "$BACKUP_OPTION" ]; then
        read -p "Agendar backup diário? (s/n): " AGENDAR
        if [ "$AGENDAR" == "s" ]; then
             read -p "Hora (0-23): " HORA
             read -p "Tipo (1: Local, 2: FTP): " TIPO
             local TIPO_TXT="local"
             [ "$TIPO" == "2" ] && TIPO_TXT="ftp"

             # We assume the main script is running, so $0 should be the main script path
             # or we find it relative to this module
             local SCRIPT_PATH
             if [[ "$0" == *"Dolutech-WP-Automation-SO.sh" ]]; then
                 SCRIPT_PATH=$(realpath "$0")
             else
                 # Fallback if sourced differently, assume standard install location or relative
                 SCRIPT_PATH=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../Dolutech-WP-Automation-SO.sh")
             fi

             local CMD="0 $HORA * * * $SCRIPT_PATH backup \"$DOMINIO\" \"$TIPO_TXT\""
             (crontab -l 2>/dev/null; echo "$CMD") | crontab -
             log "Agendado para as ${HORA}h." "INFO"
        fi
    fi
}

function restaurar_backup {
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    local BACKUPS=($(ls -1 "$BACKUP_DIR"/*.zip 2>/dev/null))
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        log "Nenhum backup encontrado em $BACKUP_DIR." "WARN"
        return
    fi

    echo "Backups disponíveis:"
    for i in "${!BACKUPS[@]}"; do
        echo "$((i+1)). $(basename "${BACKUPS[$i]}")"
    done

    read -p "Escolha o número: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt ${#BACKUPS[@]} ]; then
        log "Opção inválida." "ERROR"
        return
    fi

    local FILE="${BACKUPS[$((NUM-1))]}"
    log "Restaurando $FILE..." "INFO"

    local TEMP_DIR="/tmp/restore_$(date +%s)"
    mkdir -p "$TEMP_DIR"
    unzip -q "$FILE" -d "$TEMP_DIR"

    if [ -d "$TEMP_DIR/var/www/" ]; then
        local DOMAIN_NAME=$(ls "$TEMP_DIR/var/www/")
        local RESTORE_SOURCE="$TEMP_DIR/var/www/$DOMAIN_NAME/public_html"
    else
        log "Estrutura de backup inválida." "ERROR"
        rm -rf "$TEMP_DIR"
        return
    fi

    log "Restaurando arquivos para /var/www/$DOMAIN_NAME/public_html..." "INFO"
    mkdir -p "/var/www/$DOMAIN_NAME/public_html"
    cp -R "$RESTORE_SOURCE/"* "/var/www/$DOMAIN_NAME/public_html/"
    chown -R www-data:www-data "/var/www/$DOMAIN_NAME/public_html"
    chmod -R 755 "/var/www/$DOMAIN_NAME/public_html"

    # .htaccess
    if [ ! -f "/var/www/$DOMAIN_NAME/public_html/.htaccess" ]; then
        cat > "/var/www/$DOMAIN_NAME/public_html/.htaccess" <<EOL
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOL
        chown www-data:www-data "/var/www/$DOMAIN_NAME/public_html/.htaccess"
    fi

    # DB Restore
    local CONFIG_FILE="/var/www/$DOMAIN_NAME/public_html/wp-config.php"
    local DB_NAME=$(grep "DB_NAME" "$CONFIG_FILE" | cut -d "'" -f 4)
    local DB_USER=$(grep "DB_USER" "$CONFIG_FILE" | cut -d "'" -f 4)
    local DB_PASS=$(grep "DB_PASSWORD" "$CONFIG_FILE" | cut -d "'" -f 4)

    log "Restaurando Banco de Dados $DB_NAME..." "INFO"
    mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
    mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    local DB_DUMP="$TEMP_DIR/var/www/$DOMAIN_NAME/public_html/db/${DB_NAME}_backup.sql"
    if [ -f "$DB_DUMP" ]; then
        mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$DB_DUMP"
    else
        log "Arquivo SQL não encontrado no backup." "WARN"
    fi

    # Limpeza
    rm -rf "/var/www/$DOMAIN_NAME/public_html/db"
    rm -rf "$TEMP_DIR"

    # Reconfigurar VHosts e SSL (simplificado, chamando funções existentes se possível ou recriando)
    # Como as funções de wordpress_manager criam vhosts, idealmente chamariamos algo de lá,
    # mas aqui vamos recriar o básico

    log "Recriando configurações de servidor web..." "INFO"

    # Apache
    cat > /etc/apache2/sites-available/${DOMAIN_NAME}.conf <<EOF
<VirtualHost *:$APACHE_PORT>
    ServerName ${DOMAIN_NAME}
    DocumentRoot /var/www/${DOMAIN_NAME}/public_html
    <Directory /var/www/${DOMAIN_NAME}/public_html>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}-error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}-access.log combined
</VirtualHost>
EOF
    a2ensite "${DOMAIN_NAME}.conf"
    systemctl reload apache2

    # Nginx
    cat > /etc/nginx/sites-available/${DOMAIN_NAME}.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME};
    location / {
        proxy_pass http://127.0.0.1:$VARNISH_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    error_log /var/log/nginx/${DOMAIN_NAME}-error.log;
    access_log /var/log/nginx/${DOMAIN_NAME}-access.log;
}
EOF
    ln -sf /etc/nginx/sites-available/${DOMAIN_NAME}.conf /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx

    # SSL
    certbot --nginx -d "${DOMAIN_NAME}" --non-interactive --agree-tos -m "admin@${DOMAIN_NAME}" --redirect

    log "Restauração concluída." "INFO"
}

function gerenciar_backups_automaticos {
    echo "Rotinas de backup:"
    crontab -l | grep "backup" | nl

    read -p "Remover rotina? (s/n): " REM
    if [ "$REM" == "s" ]; then
        read -p "Número: " NUM
        local CRON=$(crontab -l)
        local LINE=$(echo "$CRON" | grep "backup" | sed -n "${NUM}p")
        if [ -n "$LINE" ]; then
            echo "$CRON" | grep -vF "$LINE" | crontab -
            log "Removido." "INFO"
        fi
    fi
}
