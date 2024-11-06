#!/bin/bash

# Dolutech WP Automation SO - Instalação Completa do WordPress com Apache otimizado
# Desenvolvido por: Lucas Catão de Moraes
# Site: https://dolutech.com

# Nome do Sistema
NOME_SISTEMA="Dolutech WP Automation SO"

# Função para configurar a mensagem de boas-vindas com créditos no /etc/motd
function configurar_mensagem_boas_vindas {
    echo "Configurando mensagem de boas-vindas com créditos..."
    echo -e "==========================================\nBem-vindo ao Dolutech WP Automation SO\nPara executar nosso menu, digite: wp\nDesenvolvido por: Lucas Catão de Moraes\nSite: https://dolutech.com\n==========================================" | sudo tee /etc/motd > /dev/null
}

# Função para criar o alias 'wp'
function configurar_alias_wp {
    echo "Configurando alias 'wp'..."
    echo "alias wp='sudo ~/Dolutech-WP-Automation-SO.sh'" >> ~/.bashrc
    source ~/.bashrc
}

# Função para instalar o ambiente completo
function instalar_ambiente {
    # Exibe a mensagem de boas-vindas
    configurar_mensagem_boas_vindas
    
    # Informações solicitadas ao usuário
    read -p "Digite o nome do domínio para o WordPress (exemplo.com): " DOMAIN_NAME
    read -p "Digite a porta para o PhpMyAdmin (ex: 8080): " PHPMYADMIN_PORT
    read -p "Digite o nome do banco de dados: " DB_NAME
    read -p "Digite o usuário do banco de dados: " DB_USER
    read -sp "Digite a senha do banco de dados: " DB_PASS
    echo ""
    read -p "Digite o usuário administrador do WordPress: " WP_ADMIN_USER
    read -sp "Digite a senha do administrador do WordPress: " WP_ADMIN_PASS
    echo ""
    echo "Selecione o idioma de instalação do WordPress:"
    echo "1 - Português do Brasil"
    echo "2 - Português de Portugal"
    echo "3 - Inglês"
    read -p "Escolha uma opção (1, 2 ou 3): " LANG_OPTION

    case $LANG_OPTION in
        1) WP_LANG="pt_BR";;
        2) WP_LANG="pt_PT";;
        3) WP_LANG="en_US";;
        *) WP_LANG="en_US"; echo "Opção inválida. Configurando padrão para Inglês.";;
    esac

    # Atualização de pacotes e instalação de dependências
    apt update && apt upgrade -y
    apt install -y apache2 mariadb-server php8.3 libapache2-mod-php8.3 php8.3-fpm php8.3-mysql php8.3-curl php8.3-xml php8.3-zip php8.3-gd php8.3-mbstring php8.3-soap php8.3-intl php8.3-bcmath php8.3-cli redis-server pure-ftpd phpmyadmin wget unzip ufw fail2ban certbot python3-certbot-apache

    # Habilitar o módulo PHP no Apache
    sudo a2enmod php8.3

    # Configurações do PHP com otimizações para WordPress
    PHP_INI="/etc/php/8.3/apache2/php.ini"
    sed -i 's/memory_limit = .*/memory_limit = 1024M/' $PHP_INI
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' $PHP_INI
    sed -i 's/post_max_size = .*/post_max_size = 100M/' $PHP_INI
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' $PHP_INI
    systemctl restart apache2

    # Configuração e otimização do Apache
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
" | sudo tee /etc/apache2/conf-available/optimization.conf > /dev/null
    a2enconf optimization.conf

    # Instalação e configuração do MariaDB
    systemctl start mariadb
    systemctl enable mariadb
    mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    # Configuração do diretório do WordPress
    WP_PATH="/var/www/$DOMAIN_NAME/public_html"
    mkdir -p $WP_PATH
    chown -R www-data:www-data $WP_PATH

    # Download e configuração do WordPress no idioma escolhido
    wget https://$WP_LANG.wordpress.org/latest-$WP_LANG.tar.gz -P /tmp
    tar -xzf /tmp/latest-$WP_LANG.tar.gz -C $WP_PATH --strip-components=1
    chown -R www-data:www-data $WP_PATH
    chmod -R 755 $WP_PATH

    # Configuração do wp-config.php
    cp $WP_PATH/wp-config-sample.php $WP_PATH/wp-config.php
    sed -i "s/database_name_here/$DB_NAME/" $WP_PATH/wp-config.php
    sed -i "s/username_here/$DB_USER/" $WP_PATH/wp-config.php
    sed -i "s/password_here/$DB_PASS/" $WP_PATH/wp-config.php

    # Instalação do WordPress usando WP-CLI e configuração dos plugins
    wp core install --url="http://$DOMAIN_NAME" --title="Site $DOMAIN_NAME" --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASS --admin_email="admin@$DOMAIN_NAME" --path=$WP_PATH --locale=$WP_LANG --allow-root
    wp plugin install all-in-one-wp-security-and-firewall headers-security-advanced-hsts-wp ninja-firewall sucuri-scanner --activate --path=$WP_PATH --allow-root

    # Configuração do Virtual Host no Apache para o domínio com suporte SSL
    echo "<VirtualHost *:80>
        ServerName $DOMAIN_NAME
        DocumentRoot $WP_PATH
        <Directory $WP_PATH>
            AllowOverride All
            Require all granted
        </Directory>
        ErrorLog \${APACHE_LOG_DIR}/$DOMAIN_NAME-error.log
        CustomLog \${APACHE_LOG_DIR}/$DOMAIN_NAME-access.log combined
    </VirtualHost>" > /etc/apache2/sites-available/$DOMAIN_NAME.conf
    a2ensite $DOMAIN_NAME.conf

    # Configuração do PhpMyAdmin para porta customizada sem alterar a porta do Apache
    echo "Listen $PHPMYADMIN_PORT" | sudo tee /etc/apache2/ports.conf > /dev/null
    echo "<VirtualHost *:$PHPMYADMIN_PORT>
        ServerAdmin webmaster@localhost
        DocumentRoot /usr/share/phpmyadmin
    </VirtualHost>" > /etc/apache2/sites-available/phpmyadmin.conf
    a2ensite phpmyadmin.conf
    systemctl reload apache2

    # Instalação do Certificado SSL com Let's Encrypt
    certbot --apache -d $DOMAIN_NAME --non-interactive --agree-tos -m admin@$DOMAIN_NAME

    echo "Instalação do WordPress concluída para o domínio $DOMAIN_NAME."
    echo "Acesse o WordPress no endereço: https://$DOMAIN_NAME/wp-admin"
}

# Verificações de configuração na primeira execução
if ! grep -q "$NOME_SISTEMA" /etc/motd; then
    configurar_mensagem_boas_vindas
    configurar_alias_wp
fi

# Função para gerenciar instalações existentes de WordPress
function menu_wp {
    echo "================= Menu Dolutech WP Automation SO ================="
    echo "1. Instalar nova configuração do WordPress"
    echo "2. Listar todas as instalações do WordPress"
    echo "3. Remover instalação do WordPress"
    echo "4. Sair"
    echo "=================================================================="
    read -p "Escolha uma opção: " OPCAO

    case $OPCAO in
        1)
            instalar_ambiente
            ;;
        2)
            echo "Instalações de WordPress:"
            ls /var/www/*/public_html
            ;;
        3)
            read -p "Digite o nome do domínio a ser removido: " REMOVER_DOMINIO
            rm -rf /var/www/$REMOVER_DOMINIO
            echo "Instalação de $REMOVER_DOMINIO removida com sucesso."
            ;;
        4)
            echo "Saindo do sistema."
            ;;
        *)
            echo "Opção inválida!"
            menu_wp
            ;;
    esac
}

# Execução do menu inicial
menu_wp
