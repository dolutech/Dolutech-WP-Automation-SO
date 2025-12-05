#!/bin/bash

source "$(dirname "$0")/modulos/config.sh"
source "$(dirname "$0")/modulos/utils.sh"

function instalar_wordpress {
    read -p "Digite o nome do domínio para o WordPress (exemplo.com): " DOMAIN_NAME

    if [ -d "/var/www/$DOMAIN_NAME/public_html" ]; then
        log "Uma instalação para o domínio $DOMAIN_NAME já existe." "WARN"
        return
    fi

    read -p "Digite o nome do banco de dados para o WordPress: " DB_NAME
    read -p "Digite o usuário do banco de dados para o WordPress: " DB_USER
    DB_PASS=$(generate_password 12)
    log "Senha DB gerada: $DB_PASS" "INFO"

    read -p "Digite o usuário administrador do WordPress: " WP_ADMIN_USER
    WP_ADMIN_PASS=$(generate_password 16)
    log "Senha Admin WP gerada: $WP_ADMIN_PASS" "INFO"

    read -p "Digite o e-mail do administrador do WordPress: " WP_ADMIN_EMAIL

    echo "Selecione o idioma:"
    echo "1 - Português do Brasil"
    echo "2 - Português de Portugal"
    echo "3 - Inglês"
    read -p "Opção: " LANG_OPTION

    case $LANG_OPTION in
        1) WP_LANG="pt_BR";;
        2) WP_LANG="pt_PT";;
        3) WP_LANG="en_GB";;
        *) WP_LANG="en_GB";;
    esac

    # Criar DB e User
    log "Criando banco de dados..." "INFO"
    mysql -u root <<EOF
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

    WP_PATH="/var/www/$DOMAIN_NAME/public_html"
    mkdir -p "$WP_PATH"
    chown -R www-data:www-data "$WP_PATH"

    log "Baixando WordPress..." "INFO"
    sudo -u www-data wp core download --locale="${WP_LANG}" --path="${WP_PATH}"

    log "Configurando wp-config.php..." "INFO"
    sudo -u www-data wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" --dbhost="localhost" --path="$WP_PATH"
    sudo -u www-data wp config shuffle-salts --path="$WP_PATH"
    sudo -u www-data wp config set WP_CACHE true --type=constant --path="$WP_PATH"

    # Configurar Redis
    sudo -u www-data wp config set WP_REDIS_HOST "127.0.0.1" --type=constant --path="$WP_PATH"
    sudo -u www-data wp config set WP_REDIS_PORT "6379" --type=constant --path="$WP_PATH"

    log "Instalando WordPress..." "INFO"
    sudo -u www-data wp core install --url="https://${DOMAIN_NAME}" --title="Site ${DOMAIN_NAME}" --admin_user="${WP_ADMIN_USER}" --admin_password="${WP_ADMIN_PASS}" --admin_email="${WP_ADMIN_EMAIL}" --path="${WP_PATH}"

    log "Instalando plugins..." "INFO"
    sudo -u www-data wp plugin install all-in-one-wp-security-and-firewall headers-security-advanced-hsts-wp sucuri-scanner redis-cache --activate --path="${WP_PATH}"
    sudo -u www-data wp redis enable --path="${WP_PATH}"

    # Configurar Apache VHost
    log "Configurando VHost Apache..." "INFO"
    cat > /etc/apache2/sites-available/${DOMAIN_NAME}.conf <<EOF
<VirtualHost *:$APACHE_PORT>
    ServerName ${DOMAIN_NAME}
    DocumentRoot ${WP_PATH}

    <Directory ${WP_PATH}>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}-error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN_NAME}-access.log combined
</VirtualHost>
EOF
    a2ensite "${DOMAIN_NAME}.conf"
    systemctl reload apache2

    # Configurar Nginx VHost
    log "Configurando VHost Nginx..." "INFO"
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
    ln -s /etc/nginx/sites-available/${DOMAIN_NAME}.conf /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx

    # Configurar .htaccess e wp-config extras
    cat > "$WP_PATH/.htaccess" <<EOL
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
    chown www-data:www-data "$WP_PATH/.htaccess"
    chmod 644 "$WP_PATH/.htaccess"

    # SSL + Varnish Fix
    sudo -u www-data wp config set FORCE_SSL_LOGIN true --type=constant --path="$WP_PATH"
    sudo -u www-data wp config set FORCE_SSL_ADMIN true --type=constant --path="$WP_PATH"

    # Injetar o fix de HTTPS atrás de proxy manualmente se wp-cli não suportar blocos de código facilmente
    if ! grep -q "HTTP_X_FORWARDED_PROTO" "$WP_PATH/wp-config.php"; then
        sed -i "/\/\* That's all, stop editing!/i if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) { \$_SERVER['HTTPS'] = 'on'; }" "$WP_PATH/wp-config.php"
    fi

    # SSL Certbot
    log "Gerando certificado SSL..." "INFO"
    certbot --nginx -d "${DOMAIN_NAME}" --non-interactive --agree-tos -m "${WP_ADMIN_EMAIL}" --redirect

    log "Instalação concluída!" "INFO"
    echo "URL: https://${DOMAIN_NAME}/wp-admin"
    echo "User: ${WP_ADMIN_USER}"
    echo "Pass: ${WP_ADMIN_PASS}"
}

function listar_instalacoes {
    echo "Instalações encontradas:"
    find /var/www -mindepth 1 -maxdepth 1 -type d -not -name "html" -not -name ".*" -not -name ".wp-cli" | sed 's|/var/www/||'
}

function remover_instalacao {
    read -p "Domínio a remover: " DOMAIN
    if [ ! -d "/var/www/$DOMAIN/public_html" ]; then
        log "Instalação não encontrada." "ERROR"
        return
    fi

    WP_CONFIG="/var/www/$DOMAIN/public_html/wp-config.php"
    DB_NAME=$(grep "DB_NAME" "$WP_CONFIG" | awk -F "'" '{print $4}')
    DB_USER=$(grep "DB_USER" "$WP_CONFIG" | awk -F "'" '{print $4}')

    log "Removendo arquivos..." "INFO"
    rm -rf "/var/www/$DOMAIN"

    log "Removendo VHosts..." "INFO"
    [ -f "/etc/apache2/sites-enabled/$DOMAIN.conf" ] && a2dissite "$DOMAIN.conf" && rm "/etc/apache2/sites-available/$DOMAIN.conf"
    [ -f "/etc/nginx/sites-enabled/$DOMAIN.conf" ] && unlink "/etc/nginx/sites-enabled/$DOMAIN.conf" && rm "/etc/nginx/sites-available/$DOMAIN.conf"

    log "Removendo DB..." "INFO"
    mysql -u root <<EOF
DROP DATABASE IF EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

    log "Removendo SSL..." "INFO"
    certbot delete --cert-name "$DOMAIN" --non-interactive

    systemctl reload apache2
    systemctl reload nginx
    log "Remoção concluída." "INFO"
}

function dominio_instalacao_manual {
    read -p "Digite o nome do domínio para configuração manual: " DOMAIN_NAME
    if [ -d "/var/www/${DOMAIN_NAME}" ]; then
        log "O domínio ${DOMAIN_NAME} já existe." "WARN"
        return
    fi

    mkdir -p "/var/www/${DOMAIN_NAME}/public_html"
    chown -R www-data:www-data "/var/www/${DOMAIN_NAME}"
    chmod -R 755 "/var/www/${DOMAIN_NAME}"

    cat > "/var/www/${DOMAIN_NAME}/public_html/index.html" <<EOL
<!DOCTYPE html>
<html><body><h1>${DOMAIN_NAME} configurado via Dolutech WP Automation</h1></body></html>
EOL
    chown www-data:www-data "/var/www/${DOMAIN_NAME}/public_html/index.html"

    # Apache VHost
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

    # Nginx VHost
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
}
EOF
    ln -s /etc/nginx/sites-available/${DOMAIN_NAME}.conf /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx

    # SSL
    certbot --nginx -d "${DOMAIN_NAME}" --non-interactive --agree-tos -m "admin@${DOMAIN_NAME}" --redirect

    log "Configuração manual concluída para ${DOMAIN_NAME}." "INFO"
}
