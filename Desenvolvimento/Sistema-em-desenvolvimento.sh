#!/bin/bash

# Dolutech WP Automation SO - Instalação Completa do WordPress com Apache, MariaDB, PHP, phpMyAdmin, Redis, Nginx, Varnish, mod_pagespeed
# Desenvolvido por: Lucas Catão de Moraes
# Sou especialista em Cibersegurança, Big Data e Privacidade de dados
# E-mail: lucas@dolutech.com
# Site: https://dolutech.com
# Licenciado sob GPLv3 - https://www.gnu.org/licenses/gpl-3.0.html
# Sou apaixonado por Café que tal me pagar um?: https://www.paypal.com/paypalme/cataodemoraes

# Nome do Sistema
NOME_SISTEMA="Dolutech WP Automation SO"

# Arquivo de flag para verificar se a configuração inicial foi concluída
FLAG_ARQUIVO="/etc/dolutech_wp_initial_setup_done"

# URL do arquivo version.txt no GitHub
VERSION_URL="https://raw.githubusercontent.com/dolutech/Dolutech-WP-Automation-SO/main/version.txt"

# URL do script atualizado no GitHub
SCRIPT_URL="https://raw.githubusercontent.com/dolutech/Dolutech-WP-Automation-SO/main/Dolutech-WP-Automation-SO.sh"

# Caminho do script local
SCRIPT_LOCAL="/usr/local/bin/Dolutech-WP-Automation-SO.sh"

# Diretório do script
DIR_SCRIPT=$(dirname $(realpath $0))

# Verifica se o arquivo version.txt existe localmente, caso contrário, faz o download
if [ ! -f "$DIR_SCRIPT/version.txt" ]; then
    echo "Arquivo version.txt não encontrado localmente. Baixando..."
    curl -o "$DIR_SCRIPT/version.txt" $VERSION_URL
fi

# Verifica a versão local
VERSAO_LOCAL=$(grep "Version=" "$DIR_SCRIPT/version.txt" | cut -d'=' -f2)

# Obtém a versão remota
VERSAO_REMOTA=$(curl -s $VERSION_URL | grep "Version=" | cut -d'=' -f2)

echo "Versão local: $VERSAO_LOCAL"
echo "Versão remota: $VERSAO_REMOTA"

# Verifica se a versão remota é diferente da local
if [ "$VERSAO_REMOTA" != "$VERSAO_LOCAL" ]; then
    echo "Nova versão disponível. Atualizando o script..."
    curl -o $SCRIPT_LOCAL $SCRIPT_URL
    chmod +x $SCRIPT_LOCAL
    echo "Script atualizado para a versão $VERSAO_REMOTA"
    # Atualiza a versão local no arquivo version.txt
    echo "Version=$VERSAO_REMOTA" > "$DIR_SCRIPT/version.txt"
    VERSAO_LOCAL=$VERSAO_REMOTA  # Atualiza a variável para a nova versão
    configurar_mensagem_boas_vindas  # Atualiza a mensagem de boas-vindas
else
    echo "O script já está atualizado."
fi

# Função para configurar a mensagem de boas-vindas com créditos e versão no /etc/motd
function configurar_mensagem_boas_vindas {
    echo "Configurando mensagem de boas-vindas com créditos..."
    echo -e "==========================================\nBem-vindo ao $NOME_SISTEMA\nVersão atual: $VERSAO_LOCAL\nPara executar nosso menu, digite: dolutech\nDesenvolvido por: Lucas Catão de Moraes\nSite: https://dolutech.com\nGostou do projeto? paga-me um café : https://www.paypal.com/paypalme/cataodemoraes\nFeito com Amor para a comunidade de língua Portuguesa ❤\nPrecisa de suporte ou ajuda? nos envie um e-mail para: lucas@dolutech.com\n==========================================" | sudo tee /etc/motd > /dev/null
}

# Função para criar o alias 'dolutech' e configurar o link simbólico
function configurar_alias_wp {
    echo "Configurando alias 'dolutech'..."

    # Adiciona o alias no ~/.bashrc para persistência
    if ! grep -q "alias dolutech=" ~/.bashrc; then
        echo "alias dolutech='sudo /usr/local/bin/Dolutech-WP-Automation-SO.sh'" >> ~/.bashrc
        source ~/.bashrc
        echo "Alias 'dolutech' configurado no ~/.bashrc."
    fi

    # Cria o link simbólico em /usr/local/bin para o comando imediato
    if [ ! -f /usr/local/bin/dolutech ]; then
        echo "Criando link simbólico para o comando 'dolutech'..."
        sudo ln -s /usr/local/bin/Dolutech-WP-Automation-SO.sh /usr/local/bin/dolutech
        sudo chmod +x /usr/local/bin/Dolutech-WP-Automation-SO.sh
        echo "Link simbólico 'dolutech' criado e pronto para uso."
    fi

    echo "Configuração de alias e link simbólico concluída."
}

# Função para instalar o WP-CLI
function instalar_wp_cli {
    if ! command -v wp &> /dev/null; then
        echo "Instalando WP-CLI..."
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        sudo mv wp-cli.phar /usr/local/bin/wp
        echo "WP-CLI instalado com sucesso."
    else
        echo "WP-CLI já está instalado."
    fi
}

# Função para instalar e configurar o Apache
function instalar_apache {
    echo "Instalando Apache..."
    sudo apt update
    sudo apt install -y apache2
    if [ $? -ne 0 ]; then
        echo "Erro na instalação do Apache."
        exit 1
    fi
    sudo systemctl enable apache2
    sudo systemctl start apache2
    echo "Apache instalado e iniciado com sucesso."

    # Alterar a porta de escuta HTTP para 8091
    echo "Configurando Apache para escutar na porta 8091..."
    sudo sed -i 's/Listen 80/Listen 8091/' /etc/apache2/ports.conf

    # Alterar a porta de escuta HTTPS para 8443
    echo "Configurando Apache para escutar na porta SSL 8443..."
    sudo sed -i 's/Listen 443/Listen 8443/' /etc/apache2/ports.conf

    # Atualizar VirtualHosts existentes para escutar na porta 8091
    echo "Atualizando VirtualHosts do Apache para escutar na porta 8091..."
    sudo sed -i 's/:80>/:8091>/g' /etc/apache2/sites-available/*.conf

    # Atualizar VirtualHosts existentes para escutar na porta 8443 para SSL
    echo "Atualizando VirtualHosts do Apache para escutar na porta SSL 8443..."
    sudo sed -i 's/:443>/:8443>/g' /etc/apache2/sites-available/*.conf

    # Reiniciar o Apache para aplicar as alterações
    echo "Reiniciando o Apache para aplicar as novas configurações..."
    sudo systemctl restart apache2

    # Habilitar MPM Event e desabilitar MPM Prefork
    echo "Configurando MPM Event para Apache..."
    sudo a2dismod mpm_prefork
    sudo a2enmod mpm_event
    sudo systemctl restart apache2
    echo "MPM Event habilitado e Apache reiniciado."
}

# Função para instalar e configurar o MariaDB Server
function instalar_mariadb {
    echo "Instalando MariaDB Server..."
    sudo apt install -y mariadb-server
    if [ $? -ne 0 ]; then
        echo "Erro na instalação do MariaDB Server."
        exit 1
    fi
    sudo systemctl enable mariadb
    sudo systemctl start mariadb
    echo "MariaDB Server instalado e iniciado com sucesso."
    
    echo "Configurando o método de autenticação do usuário root para unix_socket..."
    sudo mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
FLUSH PRIVILEGES;
EOF

    if [ $? -ne 0 ]; then
        echo "Erro na configuração do método de autenticação do usuário root do MariaDB."
        exit 1
    fi

    echo "Método de autenticação do usuário root configurado para unix_socket com sucesso."
}

# Função para instalar e configurar o PHP
function instalar_php {
    echo "Instalando PHP e módulos necessários..."
    sudo apt install -y php8.3 libapache2-mod-php8.3 php8.3-fpm php8.3-mysql php8.3-curl php8.3-xml php8.3-zip php8.3-gd php8.3-mbstring php8.3-soap php8.3-intl php8.3-bcmath php8.3-cli php8.3-redis
    if [ $? -ne 0 ]; then
        echo "Erro na instalação do PHP."
        exit 1
    fi
    echo "PHP e módulos instalados com sucesso."
}

# Função para instalar e configurar o Redis
function instalar_redis {
    echo "Instalando Redis Server..."
    sudo apt install -y redis-server
    if [ $? -ne 0 ]; then
        echo "Erro na instalação do Redis Server."
        exit 1
    fi
    sudo systemctl enable redis-server
    sudo systemctl start redis-server
    echo "Redis Server instalado e iniciado com sucesso."

    echo "Instalando a extensão PHP Redis..."
    sudo apt install -y php-redis
    if [ $? -ne 0 ]; then
        echo "Erro na instalação da extensão PHP Redis."
        exit 1
    fi

    echo "Reiniciando Apache para carregar a extensão PHP Redis..."
    sudo systemctl restart apache2
    echo "Extensão PHP Redis instalada e Apache reiniciado."
}

# Função para instalar e configurar o Varnish Cache
function instalar_varnish {
    echo "Instalando Varnish Cache..."
    sudo apt install -y varnish
    if [ $? -ne 0 ]; then
        echo "Erro na instalação do Varnish."
        exit 1
    fi

    # Configurar Varnish para escutar na porta 6081 e proxy para Apache na 8091
    echo "Configurando Varnish para escutar na porta 6081 e proxy para Apache na porta 8091..."
    sudo bash -c "cat > /etc/varnish/default.vcl" <<EOF
vcl 4.0;

backend default {
    .host = "127.0.0.1";
    .port = "8091";
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

    # Configurar as opções do Varnish
    sudo bash -c "cat > /etc/default/varnish" <<EOF
DAEMON_OPTS="-a :6081 \
             -T localhost:6082 \
             -f /etc/varnish/default.vcl \
             -S /etc/varnish/secret \
             -s malloc,256m"
EOF

    # Reiniciar Varnish para aplicar as configurações
    sudo systemctl restart varnish
    echo "Varnish Cache instalado e configurado com sucesso."
}

# Função para instalar e configurar o Nginx como Proxy Reverso
function instalar_nginx {
    echo "Instalando Nginx..."
    sudo apt update
    sudo apt install -y nginx
    if [ $? -ne 0 ]; then
        echo "Erro na instalação do Nginx."
        exit 1
    fi
    sudo systemctl enable nginx
    sudo systemctl start nginx
    echo "Nginx instalado e iniciado com sucesso."

    # Configurar Nginx como proxy reverso para Varnish
    echo "Configurando Nginx como Proxy Reverso para Varnish..."
    sudo bash -c "cat > /etc/nginx/sites-available/proxy.conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:6081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    error_log /var/log/nginx/proxy-error.log;
    access_log /var/log/nginx/proxy-access.log;
}
EOF

    sudo ln -s /etc/nginx/sites-available/proxy.conf /etc/nginx/sites-enabled/
    sudo nginx -t
    if [ $? -ne 0 ]; then
        echo "Erro na configuração do Nginx como Proxy Reverso."
        exit 1
    fi
    sudo systemctl reload nginx
    echo "Nginx configurado como Proxy Reverso para Varnish com sucesso."
}

# Função para instalar e configurar o phpMyAdmin
function instalar_phpmyadmin {
    if ! dpkg -l | grep -qw phpmyadmin; then
        echo "Instalando phpMyAdmin..."

        # Solicitar porta customizada para phpMyAdmin
        while true; do
            read -p "Digite a porta customizada para acessar o phpMyAdmin (ex: 8080): " PHPMYADMIN_PORT
            # Verificar se a porta está livre
            if sudo lsof -i TCP:$PHPMYADMIN_PORT -sTCP:LISTEN -t >/dev/null ; then
                echo "A porta $PHPMYADMIN_PORT já está em uso. Por favor, escolha outra porta."
            else
                break
            fi
        done

        # Preconfigurar as opções do phpMyAdmin para instalação não interativa
        echo "Preconfigurando opções do phpMyAdmin..."
        sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
        sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean false"

        # Instalar phpMyAdmin sem configurar o banco de dados
        sudo apt install -y phpmyadmin
        if [ $? -ne 0 ]; then
            echo "Erro na instalação do phpMyAdmin."
            exit 1
        fi

        # Configurar Apache para phpMyAdmin na porta customizada
        echo "Configurando Apache para phpMyAdmin na porta $PHPMYADMIN_PORT..."
        sudo bash -c "cat > /etc/apache2/sites-available/phpmyadmin.conf" <<EOF
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

        # Adicionar a porta customizada no Apache
        echo "Adicionando a porta $PHPMYADMIN_PORT no Apache..."
        sudo bash -c "echo 'Listen ${PHPMYADMIN_PORT}' >> /etc/apache2/ports.conf"

        # Habilitar o site do phpMyAdmin
        sudo a2ensite phpmyadmin.conf

        # Recarregar o Apache para aplicar as mudanças
        sudo systemctl reload apache2

        echo "phpMyAdmin instalado e configurado na porta $PHPMYADMIN_PORT com sucesso."
    else
        echo "phpMyAdmin já está instalado."
    fi
}

# Função para otimizar configurações do PHP
function otimizar_php {
    PHP_INI="/etc/php/8.3/apache2/php.ini"
    echo "Otimizando configurações do PHP..."
    sudo sed -i 's|memory_limit = .*|memory_limit = 1024M|' "$PHP_INI"
    sudo sed -i 's|upload_max_filesize = .*|upload_max_filesize = 128M|' "$PHP_INI"
    sudo sed -i 's|post_max_size = .*|post_max_size = 128M|' "$PHP_INI"
    sudo sed -i 's|max_execution_time = .*|max_execution_time = 3000|' "$PHP_INI"
    sudo sed -i 's|max_input_time = .*|max_input_time = 3000|' "$PHP_INI"
    sudo sed -i 's|max_input_vars = .*|max_input_vars = 3000|' "$PHP_INI"
    sudo systemctl restart apache2
    echo "Configurações do PHP otimizadas e Apache reiniciado."
}

# Função para otimizar configurações do Apache
function otimizar_apache {
    echo "Configurando e otimizando o Apache..."
    sudo a2enmod rewrite headers deflate expires ssl
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
" | sudo tee /etc/apache2/conf-available/optimization.conf > /dev/null
    sudo a2enconf optimization.conf
    sudo systemctl reload apache2
    echo "Configurações de otimização do Apache aplicadas."
}

# Função para instalar e configurar Certbot para SSL
function instalar_certbot {
    echo "Instalando Certbot para SSL..."
    sudo apt install -y certbot python3-certbot-nginx
    if [ $? -ne 0 ]; then
        echo "Erro na instalação do Certbot."
        exit 1
    fi
    echo "Certbot instalado com sucesso."
}

# Função para instalar um MTA minimalista para resolver o erro de sendmail
function instalar_mta {
    echo "Instalando um MTA minimalista para resolver o erro de sendmail não encontrado..."
    sudo apt install -y postfix mailutils
    if [ $? -ne 0 ]; then
        echo "Erro na instalação do MTA."
        exit 1
    fi
    echo "MTA instalado com sucesso."
}

# Função para ajustar permissões do WP-CLI cache
function ajustar_permissoes_wp_cli {
    echo "Ajustando permissões do diretório de cache do WP-CLI..."
    sudo mkdir -p /var/www/.wp-cli/cache/
    sudo chown -R www-data:www-data /var/www/.wp-cli
    sudo chmod -R 755 /var/www/.wp-cli
    echo "Permissões ajustadas com sucesso."
}

# Função para instalar dependências iniciais
function instalar_dependencias_iniciais {
    echo "Iniciando a instalação das dependências iniciais..."
    instalar_apache
    instalar_mariadb
    instalar_php
    instalar_redis
    instalar_varnish
    instalar_nginx
    instalar_phpmyadmin
    otimizar_php
    otimizar_apache
    instalar_certbot
    instalar_wp_cli
    instalar_mta
    ajustar_permissoes_wp_cli
    echo "Todas as dependências iniciais foram instaladas e configuradas com sucesso."

    # Criar arquivo de flag para indicar que a configuração inicial foi concluída
    sudo touch "$FLAG_ARQUIVO"
}

# Função para instalar o WordPress
function instalar_wordpress {
    read -p "Digite o nome do domínio para o WordPress (exemplo.com): " DOMAIN_NAME

    # Verificar se a instalação já existe
    if [ -d "/var/www/$DOMAIN_NAME/public_html" ]; then
        echo "Uma instalação para o domínio $DOMAIN_NAME já existe."
        return
    fi

    read -p "Digite o nome do banco de dados para o WordPress: " DB_NAME
    read -p "Digite o usuário do banco de dados para o WordPress: " DB_USER
    DB_PASS=$(openssl rand -base64 12)
    echo "Senha gerada para o banco de dados do WordPress: $DB_PASS"
    read -p "Digite o usuário administrador do WordPress: " WP_ADMIN_USER
    WP_ADMIN_PASS=$(openssl rand -base64 16)
    echo "Senha gerada para o administrador do WordPress: $WP_ADMIN_PASS"
    read -p "Digite o e-mail do administrador do WordPress: " WP_ADMIN_EMAIL

    echo "Selecione o idioma de instalação do WordPress:"
    echo "1 - Português do Brasil"
    echo "2 - Português de Portugal"
    echo "3 - Inglês"
    read -p "Escolha uma opção (1, 2 ou 3): " LANG_OPTION

    case $LANG_OPTION in
        1) WP_LANG="pt_BR";;
        2) WP_LANG="pt_PT";;
        3) WP_LANG="en_GB";;
        *) WP_LANG="en_GB"; echo "Opção inválida. Configurando padrão para Inglês.";;
    esac

    # Criação do banco de dados e do usuário
    echo "Criando banco de dados e usuário no MariaDB..."
    sudo mysql -u root <<EOF
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

    if [ $? -ne 0 ]; then
        echo "Erro na criação do banco de dados ou usuário."
        return
    fi
    echo "Banco de dados e usuário criados com sucesso."

    # Configuração do diretório do WordPress
    WP_PATH="/var/www/$DOMAIN_NAME/public_html"
    echo "Configurando diretório do WordPress em $WP_PATH..."
    sudo mkdir -p "$WP_PATH"
    sudo chown -R www-data:www-data "$WP_PATH"

    # Download e configuração do WordPress
    echo "Baixando e configurando o WordPress..."
    wget "https://${WP_LANG}.wordpress.org/latest-${WP_LANG}.tar.gz" -P /tmp
    tar -xzf "/tmp/latest-${WP_LANG}.tar.gz" -C "$WP_PATH" --strip-components=1
    sudo chown -R www-data:www-data "$WP_PATH"
    sudo chmod -R 755 "$WP_PATH"

    # Configuração do wp-config.php usando WP-CLI
    echo "Configurando wp-config.php..."
    sudo -u www-data wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" --dbhost="localhost" --path="$WP_PATH" --allow-root

    if [ $? -ne 0 ]; then
        echo "Erro na criação do wp-config.php via WP-CLI."
        return
    fi

    # Shuffle das chaves secretas
    echo "Gerando e configurando chaves únicas de autenticação..."
    sudo -u www-data wp config shuffle-salts --path="$WP_PATH" --allow-root

    if [ $? -ne 0 ]; then
        echo "Erro na configuração das chaves secretas."
        return
    fi

    # Definir WP_CACHE como true antes de ativar o plugin
    echo "Definindo WP_CACHE como true no wp-config.php..."
    sudo -u www-data wp config set WP_CACHE true --type=constant --path="$WP_PATH" --allow-root

    if [ $? -ne 0 ]; then
        echo "Erro ao definir WP_CACHE no wp-config.php."
        return
    fi

    # Configurar Redis no wp-config.php
    echo "Configurando Redis no wp-config.php..."
    sudo -u www-data wp config set WP_REDIS_HOST "127.0.0.1" --type=constant --path="$WP_PATH" --allow-root
    sudo -u www-data wp config set WP_REDIS_PORT "6379" --type=constant --path="$WP_PATH" --allow-root
    sudo -u www-data wp config set WP_REDIS_PASSWORD "" --type=constant --path="$WP_PATH" --allow-root
    sudo -u www-data wp config set WP_REDIS_MAXTTL "7200" --type=constant --path="$WP_PATH" --allow-root

    # Instalação do WordPress usando WP-CLI
    echo "Instalando o WordPress via WP-CLI..."
    sudo -u www-data wp core install --url="https://${DOMAIN_NAME}" --title="Site ${DOMAIN_NAME}" --admin_user="${WP_ADMIN_USER}" --admin_password="${WP_ADMIN_PASS}" --admin_email="${WP_ADMIN_EMAIL}" --path="${WP_PATH}" --locale="${WP_LANG}" --allow-root

    if [ $? -ne 0 ]; then
        echo "Erro na instalação do WordPress via WP-CLI."
        return
    fi

    # Instalação dos plugins de segurança e Redis Object Cache (com slug correto)
    echo "Instalando plugins de segurança e Redis Object Cache..."
    sudo -u www-data wp plugin install all-in-one-wp-security-and-firewall headers-security-advanced-hsts-wp sucuri-scanner redis-cache --activate --path="${WP_PATH}" --allow-root

    if [ $? -ne 0 ]; then
        echo "Erro na instalação dos plugins de segurança."
        return
    fi

    # Ativar Redis Object Cache
    echo "Ativando Redis Object Cache..."
    sudo -u www-data wp redis enable --path="${WP_PATH}" --allow-root

    if [ $? -ne 0 ]; then
        echo "Erro ao ativar Redis Object Cache."
        return
    fi

    # Configuração do Virtual Host no Apache para o domínio
    echo "Configurando Virtual Host no Apache para ${DOMAIN_NAME}..."
    sudo bash -c "cat > /etc/apache2/sites-available/${DOMAIN_NAME}.conf" <<EOF
<VirtualHost *:8091>
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

    sudo a2ensite "${DOMAIN_NAME}.conf"

    # Reiniciar Apache para aplicar as configurações
    sudo systemctl reload apache2

    # Configuração do Virtual Host no Nginx para o domínio com suporte SSL
    echo "Configurando Virtual Host no Nginx para ${DOMAIN_NAME}..."
    sudo bash -c "cat > /etc/nginx/sites-available/${DOMAIN_NAME}.conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME};

    location / {
        proxy_pass http://127.0.0.1:6081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    error_log /var/log/nginx/${DOMAIN_NAME}-error.log;
    access_log /var/log/nginx/${DOMAIN_NAME}-access.log;
}
EOF

    sudo ln -s /etc/nginx/sites-available/${DOMAIN_NAME}.conf /etc/nginx/sites-enabled/
    sudo nginx -t
    if [ $? -ne 0 ]; then
        echo "Erro na configuração do Nginx para ${DOMAIN_NAME}."
        exit 1
    fi
    sudo systemctl reload nginx
    echo "Virtual Host no Nginx para ${DOMAIN_NAME} configurado com sucesso."

    # Adicionar configurações de SSL e Varnish no wp-config.php
    echo "Adicionando configurações de SSL e Varnish no wp-config.php..."
    if [ -f "/var/www/${DOMAIN_NAME}/public_html/wp-config.php" ]; then
    sudo sed -i "/\\/\\* Add any custom values between this line and the \\\"stop editing\\\" line. \\*\\//i \
    // SSL + Varnish\n\
    define('FORCE_SSL_LOGIN', true);\n\
    define('FORCE_SSL_ADMIN', true);\n\
    define('CONCATENATE_SCRIPTS', false);\n\
    if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) {\n\
    \$_SERVER['HTTPS'] = 'on';\n\
    }" /var/www/${DOMAIN_NAME}/public_html/wp-config.php
    else
    echo "Erro: O arquivo wp-config.php não foi encontrado em /var/www/${DOMAIN_NAME}/public_html"
    exit 1
    fi

    # Criar o arquivo .htaccess na raiz da pasta public_html da instalação do WordPress
    echo "Criando o arquivo .htaccess na raiz de /var/www/${DOMAIN_NAME}/public_html..."
    sudo bash -c "cat > /var/www/${DOMAIN_NAME}/public_html/.htaccess" <<EOL
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

    # Definir permissões corretas para o arquivo .htaccess
    sudo chown www-data:www-data /var/www/${DOMAIN_NAME}/public_html/.htaccess
    sudo chmod 644 /var/www/${DOMAIN_NAME}/public_html/.htaccess

    echo "Configurações adicionais adicionadas com sucesso."


    # Instalação do Certificado SSL com Let's Encrypt
    echo "Instalando certificado SSL com Let's Encrypt para ${DOMAIN_NAME}..."
    sudo certbot --nginx -d "${DOMAIN_NAME}" --non-interactive --agree-tos -m "admin@${DOMAIN_NAME}" --redirect

    if [ $? -ne 0 ]; then
        echo "Erro na instalação do Certificado SSL com Let's Encrypt para ${DOMAIN_NAME}."
        return
    fi

    echo "Instalação do WordPress concluída para o domínio ${DOMAIN_NAME}."
    echo "Acesse o WordPress no endereço: https://${DOMAIN_NAME}/wp-admin"
    echo "Usuário administrador: ${WP_ADMIN_USER}"
    echo "Senha administrador: ${WP_ADMIN_PASS}"
}

# Função para remover uma instalação do WordPress
function remover_instalacao {
    read -p "Digite o nome do domínio a ser removido: " REMOVER_DOMINIO

    # Verificar se a instalação existe
    if [ ! -d "/var/www/${REMOVER_DOMINIO}/public_html" ]; then
        echo "A instalação para o domínio ${REMOVER_DOMINIO} não existe."
        return
    fi

    # Extração das credenciais do banco de dados do wp-config.php
    WP_CONFIG="/var/www/${REMOVER_DOMINIO}/public_html/wp-config.php"
    DB_NAME=$(grep "DB_NAME" "$WP_CONFIG" | awk -F "'" '{print $4}')
    DB_USER=$(grep "DB_USER" "$WP_CONFIG" | awk -F "'" '{print $4}')

    # Remover diretório do WordPress
    echo "Removendo diretório do WordPress..."
    sudo rm -rf "/var/www/${REMOVER_DOMINIO}"

    # Remover Virtual Host do Apache
    echo "Removendo Virtual Host do Apache..."
    if [ -f "/etc/apache2/sites-available/${REMOVER_DOMINIO}.conf" ]; then
        sudo a2dissite "${REMOVER_DOMINIO}.conf"
        sudo rm "/etc/apache2/sites-available/${REMOVER_DOMINIO}.conf"
    else
        echo "Arquivo de configuração do Apache para ${REMOVER_DOMINIO} não encontrado."
    fi

    # Remover Virtual Host do Nginx
    echo "Removendo Virtual Host do Nginx..."
    if [ -f "/etc/nginx/sites-available/${REMOVER_DOMINIO}.conf" ]; then
        sudo unlink /etc/nginx/sites-enabled/${REMOVER_DOMINIO}.conf
        sudo rm "/etc/nginx/sites-available/${REMOVER_DOMINIO}.conf"
    else
        echo "Arquivo de configuração do Nginx para ${REMOVER_DOMINIO} não encontrado."
    fi

    # Remover arquivos de log do Nginx
    echo "Removendo arquivos de log do Nginx..."
    sudo rm -f /var/log/nginx/${REMOVER_DOMINIO}-error.log
    sudo rm -f /var/log/nginx/${REMOVER_DOMINIO}-access.log

    # Remover certificados SSL
    echo "Removendo certificados SSL..."
    sudo certbot delete --cert-name "${REMOVER_DOMINIO}" --non-interactive

    # Remover banco de dados e usuário do MariaDB
    echo "Removendo banco de dados e usuário do MariaDB..."
    sudo mysql -u root <<EOF
DROP DATABASE IF EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Recarregar o Nginx para aplicar as mudanças
    sudo systemctl reload nginx

    echo "Instalação de ${REMOVER_DOMINIO} removida com sucesso."
}

# Função para listar todas as instalações do WordPress
function listar_instalacoes {
    echo "Domínios configurados para WordPress em /var/www:"
    # Lista os diretórios em /var/www que parecem ser domínios
    find /var/www -mindepth 1 -maxdepth 1 -type d -not -name "html" -not -name ".*" | sed 's|/var/www/||' | grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" || echo "Nenhuma instalação encontrada."
}

# Função para verificar e instalar zip e unzip
function verificar_zip {
    echo "Verificando se zip e unzip estão instalados..."
    if ! command -v zip &> /dev/null || ! command -v unzip &> /dev/null; then
        echo "Instalando zip e unzip..."
        sudo apt-get update && sudo apt-get install -y zip unzip
        if [ $? -ne 0 ]; then
            echo "Erro ao instalar zip e unzip. Verifique a conexão com a internet."
            exit 1
        fi
        echo "zip e unzip instalados com sucesso."
    else
        echo "zip e unzip já estão instalados."
    fi
}

# Função para fazer backup de uma instalação do WordPress
function fazer_backup {
    local DOMINIO=$1
    local BACKUP_OPTION=$2

    # Definir o PATH para garantir que os comandos sejam encontrados quando executados via cron
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Definir HOME se não estiver definido (cron pode não definir)
    if [ -z "$HOME" ]; then
        HOME=$(getent passwd $(whoami) | cut -d: -f6)
    fi

    # Verificar zip e unzip
    verificar_zip

    # Se o domínio não foi fornecido, solicitar ao usuário
    if [ -z "$DOMINIO" ]; then
        # Listar domínios disponíveis
        echo "Domínios configurados para WordPress em /var/www:"
        DOMINIOS=$(find /var/www -mindepth 1 -maxdepth 1 -type d -not -name "html" -not -name ".*" | sed 's|/var/www/||' | grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
        
        if [ -z "$DOMINIOS" ]; then
            echo "Nenhum domínio encontrado."
            return
        fi

        echo "$DOMINIOS"
        read -p "Digite o domínio para fazer o backup: " DOMINIO
    fi

    if [ ! -d "/var/www/$DOMINIO/public_html" ]; then
        echo "Domínio inválido ou pasta não encontrada."
        return
    fi

    # Criar a pasta de backup, se não existir
    BACKUP_DIR="/backup"
    [ ! -d "$BACKUP_DIR" ] && sudo mkdir -p "$BACKUP_DIR" && sudo chmod 755 "$BACKUP_DIR"

    # Caminhos e nomes
    DATA=$(date +"%Y%m%d-%H%M%S")
    BACKUP_ZIP="$BACKUP_DIR/${DOMINIO}_backup_$DATA.zip"
    DB_BACKUP_DIR="/var/www/$DOMINIO/public_html/db"

    # Criar pasta db dentro do public_html se não existir
    [ ! -d "$DB_BACKUP_DIR" ] && mkdir -p "$DB_BACKUP_DIR"

    # Ler informações do wp-config.php
    CONFIG_FILE="/var/www/$DOMINIO/public_html/wp-config.php"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Arquivo wp-config.php não encontrado em /var/www/$DOMINIO/public_html."
        return
    fi

    DB_USER=$(grep "DB_USER" "$CONFIG_FILE" | cut -d "'" -f 4)
    DB_NAME=$(grep "DB_NAME" "$CONFIG_FILE" | cut -d "'" -f 4)
    DB_PASSWORD=$(grep "DB_PASSWORD" "$CONFIG_FILE" | cut -d "'" -f 4)

    if [ -z "$DB_USER" ] || [ -z "$DB_NAME" ] || [ -z "$DB_PASSWORD" ]; then
        echo "Não foi possível obter informações do banco de dados."
        return
    fi

    echo "Usuário do banco de dados: $DB_USER"
    echo "Nome do banco de dados: $DB_NAME"

    # Fazer dump do banco de dados sem solicitar a senha
    echo "Exportando banco de dados..."
    mysqldump -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "$DB_BACKUP_DIR/${DB_NAME}_backup.sql"
    if [ $? -ne 0 ]; then
        echo "Erro ao exportar o banco de dados. Verifique as credenciais no wp-config.php."
        return
    fi

    # Compactar tudo
    echo "Compactando backup..."
    sudo zip -r "$BACKUP_ZIP" "/var/www/$DOMINIO/public_html" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Erro ao criar o arquivo ZIP. Verifique se o zip está corretamente instalado."
        return
    fi

    echo "Backup criado com sucesso: $BACKUP_ZIP"

    # Remover a pasta /db por segurança
    echo "Removendo pasta temporária /db por segurança..."
    sudo rm -rf "$DB_BACKUP_DIR"
    echo "Pasta /db removida."

    # Determinar se deve enviar para FTP
    if [ "$BACKUP_OPTION" == "ftp" ]; then
        ENVIAR_FTP="s"
    elif [ "$BACKUP_OPTION" == "local" ]; then
        ENVIAR_FTP="n"
    else
        read -p "Deseja enviar o backup para um servidor FTP? (s/n): " ENVIAR_FTP
    fi

    if [ "$ENVIAR_FTP" == "s" ]; then
        if ! command -v lftp &> /dev/null; then
            echo "Instalando lftp..."
            sudo apt-get update && sudo apt-get install -y lftp
        fi

        FTP_CREDENTIALS_FILE="$HOME/.ftp_credentials"

        # Verificar se as credenciais estão salvas
        if [ -f "$FTP_CREDENTIALS_FILE" ]; then
            source "$FTP_CREDENTIALS_FILE"
            echo "Usando credenciais de FTP salvas."
        else
            read -p "Digite o endereço do servidor FTP: " FTP_SERVIDOR
            read -p "Digite o usuário do FTP: " FTP_USUARIO
            read -s -p "Digite a senha do FTP: " FTP_SENHA
            echo
            read -p "Digite a porta do FTP (padrão: 21): " FTP_PORTA
            FTP_PORTA=${FTP_PORTA:-21}
            read -p "Digite a pasta de destino no FTP (deixe em branco para a raiz): " FTP_PASTA
            FTP_PASTA=${FTP_PASTA:-"/"}

            # Oferecer salvar as credenciais
            read -p "Deseja salvar estas credenciais para backups automáticos? (s/n): " SALVAR_CREDENCIAIS
            if [ "$SALVAR_CREDENCIAIS" == "s" ]; then
                echo "FTP_SERVIDOR='$FTP_SERVIDOR'" > "$FTP_CREDENTIALS_FILE"
                echo "FTP_USUARIO='$FTP_USUARIO'" >> "$FTP_CREDENTIALS_FILE"
                echo "FTP_SENHA='$FTP_SENHA'" >> "$FTP_CREDENTIALS_FILE"
                echo "FTP_PORTA='$FTP_PORTA'" >> "$FTP_CREDENTIALS_FILE"
                echo "FTP_PASTA='$FTP_PASTA'" >> "$FTP_CREDENTIALS_FILE"
                chmod 600 "$FTP_CREDENTIALS_FILE"
                echo "Credenciais FTP salvas em $FTP_CREDENTIALS_FILE"
            fi
        fi

        echo "Enviando backup para FTP..."
        lftp -u "$FTP_USUARIO","$FTP_SENHA" -p "$FTP_PORTA" "$FTP_SERVIDOR" <<EOF
put "$BACKUP_ZIP" -o "$FTP_PASTA/$(basename "$BACKUP_ZIP")"
bye
EOF
        if [ $? -eq 0 ]; then
            echo "Backup enviado com sucesso para o servidor FTP."
        else
            echo "Erro ao enviar o backup para o servidor FTP."
        fi
    fi

    # Se não estiver em modo automático, perguntar se deseja agendar backup
    if [ -z "$BACKUP_OPTION" ]; then
        # Perguntar se deseja agendar backups automáticos
        read -p "Deseja agendar backups automáticos diários? (s/n): " AGENDAR_BACKUP
        if [ "$AGENDAR_BACKUP" == "s" ]; then
            read -p "Digite a hora para o backup diário (0-23): " HORA
            read -p "O backup será: (1) Local ou (2) Enviado para FTP? Escolha: " OPCAO_BACKUP
            if [ "$OPCAO_BACKUP" == "2" ]; then
                BACKUP_OPTION="ftp"
            else
                BACKUP_OPTION="local"
            fi
            # Adicionar entrada ao crontab
            SCRIPT_PATH=$(realpath "$0")
            CRON_JOB="0 $HORA * * * $SCRIPT_PATH backup \"$DOMINIO\" \"$BACKUP_OPTION\""
            (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
            echo "Backup automático agendado para o domínio $DOMINIO às $HORA horas diariamente."
        fi
    fi
}

# Função para gerenciar backups automáticos
function gerenciar_backups_automaticos {
    echo "Rotinas de backup automáticas ativas:"
    crontab -l | grep "$0 backup" | nl
    if [ $? -ne 0 ]; then
        echo "Nenhuma rotina de backup automático encontrada."
        return
    fi

    read -p "Deseja remover alguma rotina de backup automática? (s/n): " REMOVER_ROTINA
    if [ "$REMOVER_ROTINA" == "s" ]; then
        crontab -l | grep "$0 backup" | nl
        read -p "Digite o número da rotina que deseja remover: " NUMERO
        CRON_ENTRIES=$(crontab -l)
        BACKUP_CRON_LINES=$(echo "$CRON_ENTRIES" | grep -n "$0 backup")
        LINE_NUMBER=$(echo "$BACKUP_CRON_LINES" | sed -n "${NUMERO}p" | cut -d':' -f1)
        if [ -z "$LINE_NUMBER" ]; then
            echo "Número inválido."
        else
            NEW_CRON=$(echo "$CRON_ENTRIES" | sed "${LINE_NUMBER}d")
            echo "$NEW_CRON" | crontab -
            echo "Rotina de backup removida."
        fi
    fi
}

# Verificar se o script foi chamado com argumentos para backup automático
if [ "$1" == "backup" ]; then
    DOMINIO=$2
    BACKUP_OPTION=$3
    fazer_backup "$DOMINIO" "$BACKUP_OPTION"
    exit 0
fi

# Função para restaurar um backup
function restaurar_backup {
    # Definir o PATH para garantir que os comandos sejam encontrados quando executados via cron ou shell
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Listar backups disponíveis em /backup
    BACKUP_DIR="/backup"
    echo "Backups disponíveis em $BACKUP_DIR:"
    BACKUPS=($(ls -1 "$BACKUP_DIR" | grep -E '\.zip$'))
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo "Nenhum backup encontrado em $BACKUP_DIR."
        return
    fi

    # Exibir a lista de backups numerados
    for i in "${!BACKUPS[@]}"; do
        echo "$((i+1)). ${BACKUPS[$i]}"
    done

    # Solicitar ao usuário que escolha um backup para restaurar
    read -p "Digite o número do backup que deseja restaurar: " NUM_BACKUP
    if ! [[ "$NUM_BACKUP" =~ ^[0-9]+$ ]] || [ "$NUM_BACKUP" -lt 1 ] || [ "$NUM_BACKUP" -gt ${#BACKUPS[@]} ]; then
        echo "Opção inválida."
        return
    fi

    BACKUP_FILE="${BACKUPS[$((NUM_BACKUP-1))]}"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"
    echo "Backup selecionado: $BACKUP_FILE"

    # Extrair o backup para um diretório temporário
    TEMP_DIR="/tmp/restore_${RANDOM}"
    mkdir -p "$TEMP_DIR"
    echo "Extraindo o backup para $TEMP_DIR..."
    unzip -q "$BACKUP_PATH" -d "$TEMP_DIR"
    if [ $? -ne 0 ]; then
        echo "Erro ao extrair o backup."
        rm -rf "$TEMP_DIR"
        return
    fi

    # Identificar o domínio a partir do backup
    if [ -d "$TEMP_DIR/var/www/" ]; then
        DOMAIN_NAME=$(ls "$TEMP_DIR/var/www/")
        WP_PATH="$TEMP_DIR/var/www/$DOMAIN_NAME/public_html"
    else
        echo "Estrutura de backup inválida."
        rm -rf "$TEMP_DIR"
        return
    fi

    echo "Domínio identificado: $DOMAIN_NAME"

    # Restaurar os arquivos para /var/www/$DOMAIN_NAME/public_html
    echo "Restaurando arquivos para /var/www/$DOMAIN_NAME/public_html..."
    sudo mkdir -p "/var/www/$DOMAIN_NAME/public_html"
    sudo cp -R "$WP_PATH/"* "/var/www/$DOMAIN_NAME/public_html/"
    sudo chown -R www-data:www-data "/var/www/$DOMAIN_NAME/public_html"
    sudo chmod -R 755 "/var/www/$DOMAIN_NAME/public_html"

    # Verificar e criar o arquivo .htaccess se não existir
    HTACCESS_FILE="/var/www/$DOMAIN_NAME/public_html/.htaccess"
    if [ ! -f "$HTACCESS_FILE" ]; then
        echo "Criando o arquivo .htaccess na raiz de /var/www/${DOMAIN_NAME}/public_html..."
        sudo bash -c "cat > $HTACCESS_FILE" <<EOL
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

        # Definir permissões corretas para o arquivo .htaccess
        sudo chown www-data:www-data "$HTACCESS_FILE"
        sudo chmod 644 "$HTACCESS_FILE"

        echo "Arquivo .htaccess criado e permissões definidas."
    else
        echo "Arquivo .htaccess já existe. Pulando criação."
    fi

    # Ler informações do wp-config.php
    CONFIG_FILE="/var/www/$DOMAIN_NAME/public_html/wp-config.php"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Arquivo wp-config.php não encontrado."
        rm -rf "$TEMP_DIR"
        return
    fi

    DB_NAME=$(grep "DB_NAME" "$CONFIG_FILE" | cut -d "'" -f 4)
    DB_USER=$(grep "DB_USER" "$CONFIG_FILE" | cut -d "'" -f 4)
    DB_PASSWORD=$(grep "DB_PASSWORD" "$CONFIG_FILE" | cut -d "'" -f 4)

    if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
        echo "Não foi possível obter informações do banco de dados."
        rm -rf "$TEMP_DIR"
        return
    fi

    echo "Banco de dados: $DB_NAME"
    echo "Usuário do banco de dados: $DB_USER"

    # Criar o banco de dados e o usuário sem solicitar senha
    echo "Configurando o banco de dados..."
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"

    if [ $? -ne 0 ]; then
        echo "Erro ao configurar o banco de dados."
        rm -rf "$TEMP_DIR"
        return
    fi

    # Restaurar o banco de dados
    DB_BACKUP_FILE="$TEMP_DIR/var/www/$DOMAIN_NAME/public_html/db/${DB_NAME}_backup.sql"
    if [ ! -f "$DB_BACKUP_FILE" ]; then
        echo "Arquivo de backup do banco de dados não encontrado em $DB_BACKUP_FILE."
        rm -rf "$TEMP_DIR"
        return
    fi

    echo "Importando o banco de dados..."
    mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$DB_BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo "Erro ao importar o banco de dados."
        rm -rf "$TEMP_DIR"
        return
    fi

    # Remover a pasta db por segurança
    echo "Removendo a pasta db por segurança..."
    sudo rm -rf "/var/www/$DOMAIN_NAME/public_html/db"

    # Configurar Virtual Host no Apache
    echo "Configurando Virtual Host no Apache para ${DOMAIN_NAME}..."
    sudo bash -c "cat > /etc/apache2/sites-available/${DOMAIN_NAME}.conf" <<EOF
<VirtualHost *:8091>
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

    sudo a2ensite "${DOMAIN_NAME}.conf"
    sudo systemctl reload apache2

    # Configurar Virtual Host no Nginx com suporte SSL
    echo "Configurando Virtual Host no Nginx para ${DOMAIN_NAME}..."
    sudo bash -c "cat > /etc/nginx/sites-available/${DOMAIN_NAME}.conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME};

    location / {
        proxy_pass http://127.0.0.1:6081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    error_log /var/log/nginx/${DOMAIN_NAME}-error.log;
    access_log /var/log/nginx/${DOMAIN_NAME}-access.log;
}
EOF

    sudo ln -sf /etc/nginx/sites-available/${DOMAIN_NAME}.conf /etc/nginx/sites-enabled/
    sudo nginx -t
    if [ $? -ne 0 ]; then
        echo "Erro na configuração do Nginx para ${DOMAIN_NAME}."
        rm -rf "$TEMP_DIR"
        return
    fi
    sudo systemctl reload nginx
    echo "Virtual Host no Nginx para ${DOMAIN_NAME} configurado com sucesso."

    # Instalação do Certificado SSL com Let's Encrypt
    echo "Instalando certificado SSL com Let's Encrypt para ${DOMAIN_NAME}..."
    sudo certbot --nginx -d "${DOMAIN_NAME}" --non-interactive --agree-tos -m "admin@${DOMAIN_NAME}" --redirect

    if [ $? -ne 0 ]; then
        echo "Erro na instalação do Certificado SSL com Let's Encrypt para ${DOMAIN_NAME}."
    else
        echo "Certificado SSL instalado com sucesso para ${DOMAIN_NAME}."
    fi

    # Adicionar configurações de SSL e Varnish no wp-config.php
    echo "Adicionando configurações de SSL e Varnish no wp-config.php..."
    SSL_VARNISH_CONFIG="
    // SSL + Varnish
    define('FORCE_SSL_LOGIN', true);
    define('FORCE_SSL_ADMIN', true);
    define('CONCATENATE_SCRIPTS', false);
    if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) {
        \$_SERVER['HTTPS'] = 'on';
    }
    "

    # Verificar se as configurações já existem no wp-config.php
    if ! grep -q "SSL + Varnish" "$CONFIG_FILE"; then
        sudo sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i $SSL_VARNISH_CONFIG" "$CONFIG_FILE"
        echo "Configurações adicionadas ao wp-config.php."
    else
        echo "Configurações de SSL e Varnish já existem no wp-config.php."
    fi

    # Limpar o diretório temporário
    rm -rf "$TEMP_DIR"

    echo "Restauração concluída com sucesso!"
}

# Função para atualizar certificados SSL
function atualizar_certificados_ssl {
    # Definir o PATH para garantir que os comandos sejam encontrados
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Verificar se o Certbot está instalado
    if ! command -v certbot &> /dev/null; then
        echo "Certbot não está instalado. Instalando..."
        sudo apt-get update
        sudo apt-get install -y certbot python3-certbot-nginx
    fi

    # Obter lista de certificados SSL instalados
    echo "Obtendo lista de certificados SSL instalados..."
    CERTIFICADOS=$(sudo certbot certificates 2>/dev/null | grep "Certificate Name:" | awk '{print $3}')

    if [ -z "$CERTIFICADOS" ]; then
        echo "Nenhum certificado SSL encontrado."
        return
    fi

    # Exibir lista de domínios com certificados SSL
    echo "Domínios com certificados SSL instalados:"
    IFS=$'\n' read -rd '' -a DOMINIOS <<<"$CERTIFICADOS"

    for i in "${!DOMINIOS[@]}"; do
        echo "$((i+1)). ${DOMINIOS[$i]}"
    done
    echo "$(( ${#DOMINIOS[@]} + 1 )). Renovar todos os certificados"

    # Solicitar ao usuário que escolha um domínio ou renovar todos
    read -p "Digite o número do domínio que deseja renovar ou escolha a opção para renovar todos: " NUM_ESCOLHA

    if ! [[ "$NUM_ESCOLHA" =~ ^[0-9]+$ ]] || [ "$NUM_ESCOLHA" -lt 1 ] || [ "$NUM_ESCOLHA" -gt $(( ${#DOMINIOS[@]} + 1 )) ]; then
        echo "Opção inválida."
        return
    fi

    if [ "$NUM_ESCOLHA" -eq $(( ${#DOMINIOS[@]} + 1 )) ]; then
        # Renovar todos os certificados
        echo "Renovando todos os certificados SSL..."
        sudo certbot renew --nginx
        if [ $? -eq 0 ]; then
            echo "Todos os certificados SSL foram renovados com sucesso."
        else
            echo "Erro ao renovar os certificados SSL."
        fi
    else
        # Renovar certificado específico
        DOMINIO_SELECIONADO="${DOMINIOS[$((NUM_ESCOLHA - 1))]}"
        echo "Renovando o certificado SSL para o domínio: $DOMINIO_SELECIONADO"
        sudo certbot certonly --nginx -d "$DOMINIO_SELECIONADO" --force-renewal
        if [ $? -eq 0 ]; then
            echo "Certificado SSL para $DOMINIO_SELECIONADO renovado com sucesso."
        else
            echo "Erro ao renovar o certificado SSL para $DOMINIO_SELECIONADO."
        fi
    fi

    # Informar sobre a renovação automática
    echo "O Certbot já está configurado para renovar os certificados automaticamente quando estiverem próximos do vencimento."
    echo "Nenhuma ação adicional é necessária."
}

    #Função de Renovar SSl pelo CLI 
    if [ "$1" == "renew_ssl" ]; then
        atualizar_certificados_ssl
        exit 0
    fi

# Função para configurar o domínio para instalação manual
function dominio_instalacao_manual {
    # Definir o PATH para garantir que os comandos sejam encontrados
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Solicitar ao usuário o nome do domínio
    read -p "Digite o nome do domínio (exemplo: seu_dominio.com): " DOMAIN_NAME

    # Verificar se o domínio já existe
    if [ -d "/var/www/${DOMAIN_NAME}" ]; then
        echo "O domínio ${DOMAIN_NAME} já existe."
        return
    fi

    # Criar a estrutura de diretórios
    echo "Criando diretórios para ${DOMAIN_NAME}..."
    sudo mkdir -p "/var/www/${DOMAIN_NAME}/public_html"
    sudo chown -R www-data:www-data "/var/www/${DOMAIN_NAME}"
    sudo chmod -R 755 "/var/www/${DOMAIN_NAME}"

    # Criar o arquivo index.html com o conteúdo especificado
    echo "Criando o arquivo index.html..."
    sudo bash -c "cat > /var/www/${DOMAIN_NAME}/public_html/index.html" <<EOL
<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <title>Website Configurado</title>
    <!-- Bootstrap CSS -->
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.0/css/bootstrap.min.css">
</head>
<body>
    <div class="container text-center mt-5">
        <h1 class="display-4">Configuração do Domínio</h1>
        <p class="lead">O domínio <strong>${DOMAIN_NAME}</strong> foi configurado com sucesso utilizando o Sistema Dolutech WP Automation.</p>
    </div>
</body>
</html>
EOL

    sudo chown www-data:www-data "/var/www/${DOMAIN_NAME}/public_html/index.html"
    sudo chmod 644 "/var/www/${DOMAIN_NAME}/public_html/index.html"

    # Configurar Virtual Host no Apache
    echo "Configurando Virtual Host no Apache para ${DOMAIN_NAME}..."
    sudo bash -c "cat > /etc/apache2/sites-available/${DOMAIN_NAME}.conf" <<EOF
<VirtualHost *:8091>
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

    sudo a2ensite "${DOMAIN_NAME}.conf"
    sudo systemctl reload apache2

    # Configurar Virtual Host no Nginx com suporte SSL
    echo "Configurando Virtual Host no Nginx para ${DOMAIN_NAME}..."
    sudo bash -c "cat > /etc/nginx/sites-available/${DOMAIN_NAME}.conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME};

    location / {
        proxy_pass http://127.0.0.1:6081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    error_log /var/log/nginx/${DOMAIN_NAME}-error.log;
    access_log /var/log/nginx/${DOMAIN_NAME}-access.log;
}
EOF

    sudo ln -sf /etc/nginx/sites-available/${DOMAIN_NAME}.conf /etc/nginx/sites-enabled/
    sudo nginx -t
    if [ $? -ne 0 ]; then
        echo "Erro na configuração do Nginx para ${DOMAIN_NAME}."
        return
    fi
    sudo systemctl reload nginx
    echo "Virtual Host no Nginx para ${DOMAIN_NAME} configurado com sucesso."

    # Instalação do Certificado SSL com Let's Encrypt
    echo "Instalando certificado SSL com Let's Encrypt para ${DOMAIN_NAME}..."
    sudo certbot --nginx -d "${DOMAIN_NAME}" --non-interactive --agree-tos -m "admin@${DOMAIN_NAME}" --redirect

    if [ $? -ne 0 ]; then
        echo "Erro na instalação do Certificado SSL com Let's Encrypt para ${DOMAIN_NAME}."
    else
        echo "Certificado SSL instalado com sucesso para ${DOMAIN_NAME}."
    fi

    echo "Configuração do domínio ${DOMAIN_NAME} concluída com sucesso."
}

# Função Assistente de Banco de Dados
function assistente_data_base {
    # Definir o PATH para garantir que os comandos sejam encontrados
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Solicitar o nome do banco de dados
    read -p "Digite o nome do banco de dados: " DB_NAME

    # Solicitar o nome do usuário do banco de dados
    read -p "Digite o nome do usuário do banco de dados: " DB_USER

    # Gerar uma senha segura para o usuário
    DB_PASSWORD=$(openssl rand -base64 12)
    echo "Senha gerada para o usuário ${DB_USER}: ${DB_PASSWORD}"

    # Criar o banco de dados e o usuário, e associá-los
    echo "Criando o banco de dados e o usuário, e associando-os..."
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"

    if [ $? -ne 0 ]; then
        echo "Erro ao criar o banco de dados ou o usuário."
        return
    fi

    # Perguntar se o usuário deseja importar um arquivo .sql ou .sql.zip
    read -p "Deseja importar um arquivo .sql ou .sql.zip para este banco de dados? (s/n): " IMPORTAR_DB

    if [ "$IMPORTAR_DB" == "s" ]; then
        read -p "Digite o caminho completo para o arquivo .sql ou .sql.zip: " DB_FILE_PATH

        # Verificar se o arquivo existe
        if [ ! -f "$DB_FILE_PATH" ]; then
            echo "Arquivo não encontrado no caminho especificado."
            return
        fi

        # Importar o arquivo .sql ou .sql.zip
        if [[ "$DB_FILE_PATH" == *.zip ]]; then
            echo "Descompactando e importando o arquivo .sql.zip..."
            TEMP_SQL_FILE="/tmp/temp_db_import_${RANDOM}.sql"
            unzip -p "$DB_FILE_PATH" > "$TEMP_SQL_FILE"
            if [ $? -ne 0 ]; then
                echo "Erro ao descompactar o arquivo .zip."
                rm -f "$TEMP_SQL_FILE"
                return
            fi
            mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$TEMP_SQL_FILE"
            if [ $? -ne 0 ]; then
                echo "Erro ao importar o banco de dados."
                rm -f "$TEMP_SQL_FILE"
                return
            fi
            rm -f "$TEMP_SQL_FILE"
        elif [[ "$DB_FILE_PATH" == *.sql ]]; then
            echo "Importando o arquivo .sql..."
            mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$DB_FILE_PATH"
            if [ $? -ne 0 ]; then
                echo "Erro ao importar o banco de dados."
                return
            fi
        else
            echo "Formato de arquivo não suportado. Por favor, forneça um arquivo .sql ou .sql.zip."
            return
        fi

        echo "Banco de dados importado com sucesso."
    fi

    # Exibir as credenciais para o usuário
    echo "=========================================="
    echo "Banco de Dados: $DB_NAME"
    echo "Usuário do Banco de Dados: $DB_USER"
    echo "Senha do Usuário: $DB_PASSWORD"
    echo "=========================================="
    echo "Guarde essas informações para configurar seu sistema."
}

# Função para listar e gerenciar bancos de dados
function gerenciar_bancos_de_dados {
    # Definir o PATH para garantir que os comandos sejam encontrados
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Obter a lista de bancos de dados, excluindo os bancos de dados do sistema
    DATABASES=$(sudo mysql -e "SHOW DATABASES;" | grep -Ev "Database|information_schema|performance_schema|mysql|sys")

    if [ -z "$DATABASES" ]; then
        echo "Nenhum banco de dados encontrado."
        return
    fi

    # Converter a lista de bancos de dados em um array
    IFS=$'\n' read -rd '' -a DB_ARRAY <<<"$DATABASES"

    echo "Bancos de dados disponíveis:"
    for i in "${!DB_ARRAY[@]}"; do
        echo "$((i+1)). ${DB_ARRAY[$i]}"
    done

    # Perguntar se o usuário deseja remover um banco de dados
    read -p "Deseja remover um banco de dados e o usuário associado? (s/n): " REMOVER_DB

    if [ "$REMOVER_DB" != "s" ]; then
        echo "Operação cancelada pelo usuário."
        return
    fi

    # Solicitar ao usuário que escolha um banco de dados para remover
    read -p "Digite o número do banco de dados que deseja remover: " NUM_DB

    if ! [[ "$NUM_DB" =~ ^[0-9]+$ ]] || [ "$NUM_DB" -lt 1 ] || [ "$NUM_DB" -gt ${#DB_ARRAY[@]} ]; then
        echo "Opção inválida."
        return
    fi

    DB_TO_REMOVE="${DB_ARRAY[$((NUM_DB - 1))]}"
    echo "Banco de dados selecionado: $DB_TO_REMOVE"

    # Identificar os usuários associados ao banco de dados
    USERS=$(sudo mysql -e "SELECT DISTINCT USER FROM mysql.db WHERE Db='${DB_TO_REMOVE}';" | grep -v "USER")

    if [ -z "$USERS" ]; then
        echo "Nenhum usuário específico encontrado associado ao banco de dados ${DB_TO_REMOVE}."
        echo "Deseja remover o banco de dados mesmo assim? (s/n): "
        read CONFIRM_REMOVE_DB_ONLY
        if [ "$CONFIRM_REMOVE_DB_ONLY" != "s" ]; then
            echo "Operação cancelada pelo usuário."
            return
        fi
    else
        # Listar os usuários associados
        echo "Usuários associados ao banco de dados ${DB_TO_REMOVE}:"
        IFS=$'\n' read -rd '' -a USER_ARRAY <<<"$USERS"
        for user in "${USER_ARRAY[@]}"; do
            echo "- $user"
        done

        # Confirmar a remoção do banco de dados e dos usuários
        echo "ATENÇÃO: Esta ação removerá o banco de dados '${DB_TO_REMOVE}' e os usuários associados."
        read -p "Tem certeza que deseja continuar? (s/n): " CONFIRM_REMOVE

        if [ "$CONFIRM_REMOVE" != "s" ]; then
            echo "Operação cancelada pelo usuário."
            return
        fi
    fi

    # Remover o banco de dados
    echo "Removendo o banco de dados '${DB_TO_REMOVE}'..."
    sudo mysql -e "DROP DATABASE \`${DB_TO_REMOVE}\`;"

    if [ $? -ne 0 ]; then
        echo "Erro ao remover o banco de dados."
        return
    fi

    # Remover os usuários associados
    if [ -n "$USERS" ]; then
        for user in "${USER_ARRAY[@]}"; do
            echo "Removendo o usuário '${user}'..."
            sudo mysql -e "DROP USER '${user}'@'localhost';"
        done

        # Atualizar os privilégios
        sudo mysql -e "FLUSH PRIVILEGES;"
    fi

    echo "Banco de dados e usuários associados removidos com sucesso."
}

# Menu principal
function menu_wp {
    while true; do
        echo "================= Menu Dolutech WP Automation SO ================="
        echo "1. Instalar nova configuração do WordPress"
        echo "2. Listar todas as instalações do WordPress"
        echo "3. Fazer Backup de uma Instalação do WordPress"
        echo "4. Remover instalação do WordPress"
        echo "5. Gerenciar Backups Automáticos"
        echo "6. Restaurar um Backup"
        echo "7. Atualizar Certificados SSL"
        echo "8. Configurar Domínio para Instalação Manual"
        echo "9. Assistente de Banco de Dados"
        echo "10. Gerenciar Bancos de Dados"
        echo "11. Sair"
        echo "=================================================================="
        read -p "Escolha uma opção: " OPCAO

        case $OPCAO in
            1)
                instalar_wordpress
                ;;
            2)
                listar_instalacoes
                ;;
            3)
                fazer_backup
                ;;
            4)
                remover_instalacao
                ;;
            5)
                gerenciar_backups_automaticos
                ;;
            6)
                restaurar_backup
                ;;
            7)
                atualizar_certificados_ssl
                ;;
            8)
                dominio_instalacao_manual
                ;;
            9)
                assistente_data_base
                ;;
            10)
                gerenciar_bancos_de_dados
                ;;
            11)
                echo "Saindo do sistema."
                exit 0
                ;;
            *)
                echo "Opção inválida!"
                ;;
        esac
    done
}

# Função para verificar se as dependências já estão instaladas
function verificar_dependencias {
    # Verificar se o Apache está instalado
    if ! dpkg -l | grep -qw apache2; then
        return 1
    fi

    # Verificar se o MariaDB Server está instalado
    if ! dpkg -l | grep -qw mariadb-server; then
        return 1
    fi

    # Verificar se o PHP está instalado
    if ! dpkg -l | grep -qw php8.3; then
        return 1
    fi

    # Verificar se o phpMyAdmin está instalado
    if ! dpkg -l | grep -qw phpmyadmin; then
        return 1
    fi

    # Verificar se o WP-CLI está instalado
    if ! command -v wp &> /dev/null; then
        return 1
    fi

    # Verificar se Redis está instalado
    if ! dpkg -l | grep -qw redis-server; then
        return 1
    fi

    # Verificar se Nginx está instalado
    if ! dpkg -l | grep -qw nginx; then
        return 1
    fi

    # Verificar se Varnish está instalado
    if ! dpkg -l | grep -qw varnish; then
        return 1
    fi

    # Verificar se mod_pagespeed está instalado
    if ! apache2ctl -M | grep -qw pagespeed; then
        return 1
    fi

    return 0
}

# Início do Script
clear
echo "================= Dolutech WP Automation SO ================="
echo "Sistema de automação para instalação e gerenciamento de WordPress"
echo "Desenvolvido com Amor ❤ para a comunidade de Lingua Portuguesa"
echo "=============================================================="

# Verificar se a configuração inicial já foi feita
if [ ! -f "$FLAG_ARQUIVO" ]; then
    echo "Configuração inicial não detectada. Iniciando instalação inicial."
    instalar_dependencias_iniciais
    echo "Configuração inicial concluída."
else
    echo "Configuração inicial já foi realizada anteriormente."
fi

# Configurar mensagem de boas-vindas e alias, se não estiverem configurados
if ! grep -q "$NOME_SISTEMA" /etc/motd; then
    configurar_mensagem_boas_vindas
    configurar_alias_wp
fi

# Execução do menu inicial
while true; do
    menu_wp
done
