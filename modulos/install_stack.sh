#!/bin/bash

source "$(dirname "$0")/modulos/config.sh"
source "$(dirname "$0")/modulos/utils.sh"

function instalar_apache {
    log "Instalando Apache..." "INFO"
    if dpkg -l | grep -qw apache2; then
        log "Apache já está instalado." "INFO"
    else
        apt update
        apt install -y apache2
        if [ $? -ne 0 ]; then
            log "Erro na instalação do Apache." "ERROR"
            exit 1
        fi
        systemctl enable apache2
        systemctl start apache2
        log "Apache instalado e iniciado com sucesso." "INFO"
    fi

    # Configurar portas
    log "Configurando portas do Apache..." "INFO"
    if ! grep -q "Listen $APACHE_PORT" /etc/apache2/ports.conf; then
        sed -i "s/Listen 80/Listen $APACHE_PORT/" /etc/apache2/ports.conf
        sed -i "s/:80>/:$APACHE_PORT>/g" /etc/apache2/sites-available/*.conf
    fi

    if ! grep -q "Listen $APACHE_SSL_PORT" /etc/apache2/ports.conf; then
        sed -i "s/Listen 443/Listen $APACHE_SSL_PORT/" /etc/apache2/ports.conf
        sed -i "s/:443>/:$APACHE_SSL_PORT>/g" /etc/apache2/sites-available/*.conf
    fi

    systemctl restart apache2

    # MPM Event
    log "Configurando MPM Event..." "INFO"
    a2dismod mpm_prefork
    a2enmod mpm_event
    systemctl restart apache2
}

function otimizar_apache {
    log "Configurando e otimizando o Apache..." "INFO"
    a2enmod rewrite headers deflate expires ssl
    echo "
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json
</IfModule>
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresDefault \"access plus 1 month\"
</IfModule>
Header always set X-Content-Type-Options \"nosniff\"
Header always set X-Frame-Options \"SAMEORIGIN\"
Header always set X-XSS-Protection \"1; mode=block\"
" | tee /etc/apache2/conf-available/optimization.conf > /dev/null
    a2enconf optimization.conf
    systemctl reload apache2
    log "Configurações de otimização do Apache aplicadas." "INFO"
}

function instalar_mariadb {
    log "Instalando MariaDB Server..." "INFO"
    if dpkg -l | grep -qw mariadb-server; then
        log "MariaDB já está instalado." "INFO"
    else
        apt install -y mariadb-server
        if [ $? -ne 0 ]; then
            log "Erro na instalação do MariaDB Server." "ERROR"
            exit 1
        fi
        systemctl enable mariadb
        systemctl start mariadb

        log "Configurando autenticação do root..." "INFO"
        mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
FLUSH PRIVILEGES;
EOF
    fi
}

function instalar_php {
    log "Instalando PHP $PHP_VERSION e módulos..." "INFO"
    if dpkg -l | grep -qw "php$PHP_VERSION"; then
        log "PHP $PHP_VERSION já está instalado." "INFO"
    else
        apt install -y "php$PHP_VERSION" "libapache2-mod-php$PHP_VERSION" "php$PHP_VERSION-fpm" "php$PHP_VERSION-mysql" "php$PHP_VERSION-curl" "php$PHP_VERSION-xml" "php$PHP_VERSION-zip" "php$PHP_VERSION-gd" "php$PHP_VERSION-mbstring" "php$PHP_VERSION-soap" "php$PHP_VERSION-intl" "php$PHP_VERSION-bcmath" "php$PHP_VERSION-cli" "php$PHP_VERSION-redis"
        if [ $? -ne 0 ]; then
            log "Erro na instalação do PHP." "ERROR"
            exit 1
        fi
    fi
}

function otimizar_php {
    local PHP_INI="/etc/php/$PHP_VERSION/apache2/php.ini"
    log "Otimizando configurações do PHP em $PHP_INI..." "INFO"
    if [ -f "$PHP_INI" ]; then
        sed -i 's|memory_limit = .*|memory_limit = 1024M|' "$PHP_INI"
        sed -i 's|upload_max_filesize = .*|upload_max_filesize = 128M|' "$PHP_INI"
        sed -i 's|post_max_size = .*|post_max_size = 128M|' "$PHP_INI"
        sed -i 's|max_execution_time = .*|max_execution_time = 3000|' "$PHP_INI"
        sed -i 's|max_input_time = .*|max_input_time = 3000|' "$PHP_INI"
        sed -i 's|max_input_vars = .*|max_input_vars = 3000|' "$PHP_INI"
        systemctl restart apache2
    else
        log "Arquivo php.ini não encontrado." "WARN"
    fi
}

function instalar_redis {
    log "Instalando Redis Server..." "INFO"
    if dpkg -l | grep -qw redis-server; then
        log "Redis Server já está instalado." "INFO"
    else
        apt install -y redis-server
        systemctl enable redis-server
        systemctl start redis-server
    fi

    log "Instalando extensão PHP Redis..." "INFO"
    apt install -y php-redis
    systemctl restart apache2
}

function instalar_varnish {
    log "Instalando Varnish Cache..." "INFO"
    if dpkg -l | grep -qw varnish; then
        log "Varnish já está instalado." "INFO"
    else
        apt install -y varnish
        if [ $? -ne 0 ]; then
            log "Erro na instalação do Varnish." "ERROR"
            exit 1
        fi
    fi

    log "Configurando Varnish..." "INFO"
    cat > /etc/varnish/default.vcl <<EOF
vcl 4.0;

backend default {
    .host = "127.0.0.1";
    .port = "$APACHE_PORT";
}

sub vcl_recv {
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "Not allowed."));
        }
        return (purge);
    }
}

acl purge {
    "localhost";
}

sub vcl_backend_response {
    set beresp.ttl = 1h;
}

sub vcl_deliver {
    set resp.http.X-Cache = "HIT";
}
EOF

    cat > /etc/default/varnish <<EOF
DAEMON_OPTS="-a :$VARNISH_PORT \\
             -T localhost:$VARNISH_ADMIN_PORT \\
             -f /etc/varnish/default.vcl \\
             -S /etc/varnish/secret \\
             -s malloc,256m"
EOF

    # Ajuste para systemd se necessário (Ubuntu 24.04 usa systemd service file para varnish)
    # Mas editando /etc/default/varnish pode não ser suficiente se o serviço systemd não usar esse arquivo.
    # Vamos garantir editando o serviço systemd se necessário, mas geralmente o pacote debian configura isso.
    # No Ubuntu recente, as configurações de porta podem estar no arquivo de serviço.

    # Vamos sobrescrever a configuração do serviço systemd para garantir as portas
    mkdir -p /etc/systemd/system/varnish.service.d
    cat > /etc/systemd/system/varnish.service.d/customport.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/varnishd -j unix,user=varnish -F -a :$VARNISH_PORT -T localhost:$VARNISH_ADMIN_PORT -f /etc/varnish/default.vcl -S /etc/varnish/secret -s malloc,256m
EOF

    systemctl daemon-reload
    systemctl restart varnish
}

function instalar_nginx {
    log "Instalando Nginx..." "INFO"
    if dpkg -l | grep -qw nginx; then
        log "Nginx já está instalado." "INFO"
    else
        apt update
        apt install -y nginx
        systemctl enable nginx
        systemctl start nginx
    fi

    log "Configurando Nginx como Proxy Reverso..." "INFO"
    cat > /etc/nginx/sites-available/proxy.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:$VARNISH_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    error_log /var/log/nginx/proxy-error.log;
    access_log /var/log/nginx/proxy-access.log;
}
EOF

    if [ ! -L /etc/nginx/sites-enabled/proxy.conf ]; then
        ln -s /etc/nginx/sites-available/proxy.conf /etc/nginx/sites-enabled/
    fi

    # Remover default se existir
    if [ -f /etc/nginx/sites-enabled/default ]; then
        unlink /etc/nginx/sites-enabled/default
    fi

    nginx -t && systemctl reload nginx
}

function instalar_phpmyadmin {
    if ! dpkg -l | grep -qw phpmyadmin; then
        log "Instalando phpMyAdmin..." "INFO"

        local PHPMYADMIN_PORT
        while true; do
            read -p "Digite a porta customizada para acessar o phpMyAdmin (ex: 8080): " PHPMYADMIN_PORT
            if lsof -i TCP:$PHPMYADMIN_PORT -sTCP:LISTEN -t >/dev/null ; then
                log "A porta $PHPMYADMIN_PORT já está em uso." "WARN"
            else
                break
            fi
        done

        debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
        debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean false"

        apt install -y phpmyadmin

        cat > /etc/apache2/sites-available/phpmyadmin.conf <<EOF
<VirtualHost *:${PHPMYADMIN_PORT}>
    ServerAdmin webmaster@localhost
    DocumentRoot /usr/share/phpmyadmin

    <Directory /usr/share/phpmyadmin>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/phpmyadmin-error.log
    CustomLog \${APACHE_LOG_DIR}/phpmyadmin-access.log combined
</VirtualHost>
EOF

        echo "Listen ${PHPMYADMIN_PORT}" >> /etc/apache2/ports.conf
        a2ensite phpmyadmin.conf
        systemctl reload apache2
        log "phpMyAdmin instalado na porta $PHPMYADMIN_PORT." "INFO"
    else
        log "phpMyAdmin já está instalado." "INFO"
    fi
}

function instalar_certbot {
    log "Instalando Certbot..." "INFO"
    apt install -y certbot python3-certbot-nginx
}

function instalar_mta {
    log "Instalando MTA (Postfix)..." "INFO"
    if ! dpkg -l | grep -qw postfix; then
        debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
        debconf-set-selections <<< "postfix postfix/mailname string $(hostname)"
        apt install -y postfix mailutils
    fi
}

function instalar_wp_cli {
    if ! command -v wp &> /dev/null; then
        log "Instalando WP-CLI..." "INFO"
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        mv wp-cli.phar /usr/local/bin/wp
    fi

    mkdir -p /var/www/.wp-cli/cache/
    chown -R www-data:www-data /var/www/.wp-cli
}

function instalar_mod_pagespeed {
    log "Verificando mod_pagespeed..." "INFO"
    if apache2ctl -M | grep -qw pagespeed; then
        log "mod_pagespeed já está ativo." "INFO"
        return
    fi

    # Check architecture (mod_pagespeed .deb URL is for amd64)
    if [ "$(uname -m)" != "x86_64" ]; then
        log "Arquitetura $(uname -m) não suportada automaticamente para mod_pagespeed (requer amd64)." "WARN"
        return
    fi

    log "Baixando e instalando mod_pagespeed..." "INFO"
    wget -O mod-pagespeed.deb "$MOD_PAGESPEED_URL"
    dpkg -i mod-pagespeed.deb
    if [ $? -ne 0 ]; then
        log "Erro ao instalar o pacote .deb, tentando corrigir dependências..." "WARN"
        apt-get -f install -y
    fi
    rm mod-pagespeed.deb

    systemctl restart apache2

    if apache2ctl -M | grep -qw pagespeed; then
        log "mod_pagespeed instalado e ativado com sucesso." "INFO"
    else
        log "Falha ao ativar mod_pagespeed." "ERROR"
    fi
}

function instalar_dependencias_iniciais {
    log "Iniciando a instalação das dependências iniciais..." "INFO"
    instalar_utils
    instalar_apache
    instalar_mariadb
    instalar_php
    instalar_redis
    instalar_varnish
    instalar_nginx
    instalar_mod_pagespeed
    instalar_phpmyadmin
    otimizar_php
    otimizar_apache
    instalar_certbot
    instalar_wp_cli
    instalar_mta

    log "Todas as dependências iniciais foram instaladas." "INFO"
    touch "$FLAG_ARQUIVO"
}
