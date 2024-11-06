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
    echo "alias wp='sudo ~/Dolutech-WP-Automation-SO.sh menu'" >> ~/.bashrc
    source ~/.bashrc
}

# Função para confirmar senhas
function confirmar_senha {
    local senha1 senha2
    while true; do
        echo "$1:"
        read -sp "Digite a senha: " senha1
        echo
        read -sp "Confirme a senha: " senha2
        echo
        if [ "$senha1" == "$senha2" ]; then
            echo "$senha1"
            break
        else
            echo "As senhas não coincidem. Tente novamente."
        fi
    done
}

# Função para instalar o ambiente completo
function instalar_ambiente {
    # Exibe a mensagem de boas-vindas e configurações
    configurar_mensagem_boas_vindas
    configurar_alias_wp

    # Informações solicitadas ao usuário
    read -p "Digite o nome do domínio para o WordPress (exemplo.com): " DOMAIN_NAME
    read -p "Digite a porta para o PhpMyAdmin (ex: 8080): " PHPMYADMIN_PORT
    read -p "Digite o nome do banco de dados: " DB_NAME
    read -p "Digite o usuário do banco de dados: " DB_USER
    DB_PASS=$(confirmar_senha "Senha do banco de dados")
    read -p "Digite o nome do usuário administrador do WordPress: " WP_ADMIN_USER
    WP_ADMIN_PASS=$(confirmar_senha "Senha do administrador do WordPress")

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
    apt install -y apache2 mariadb-server php8.3 libapache2-mod-php8.3 php8.3-fpm php8.3-mysql php8.3-curl php8.3-xml php8.3-zip php8.3-gd php8.3-mbstring php8.3-soap php8.3-intl php8.3-bcmath php8.3-cli redis-server pure-ftpd phpmyadmin wget unzip ufw fail2ban modsecurity modsecurity-crs clamav certbot python3-certbot-apache apache2-utils

    # Habilitar o módulo PHP no Apache
    sudo a2enmod php8.3

    # Configurações do PHP com otimizações para WordPress
    PHP_INI="/etc/php/8.3/apache2/php.ini"
    sed -i 's/memory_limit = .*/memory_limit = 1024M/' $PHP_INI
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' $PHP_INI
    sed -i 's/post_max_size = .*/post_max_size = 100M/' $PHP_INI
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' $PHP_INI
    systemctl restart apache2

    # Configuração e otimização do Apache com ModSecurity
    a2enmod rewrite headers deflate expires ssl security2
    cp /usr/share/modsecurity-crs/crs-setup.conf.example /etc/modsecurity/crs-setup.conf
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

    # Instalação do WP-CLI
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp

    # Instalação do WordPress e plugins usando WP-CLI
    wp core install --url="http://$DOMAIN_NAME" --title="Site $DOMAIN_NAME" --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASS --admin_email="admin@$DOMAIN_NAME" --path=$WP_PATH --locale=$WP_LANG --allow-root
    wp plugin install all-in-one-wp-security-and-firewall headers-security-advanced-hsts-wp ninja-firewall --activate --path=$WP_PATH --allow-root

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

    # Configuração do PhpMyAdmin para porta customizada com autenticação básica
    echo "Listen $PHPMYADMIN_PORT" | sudo tee /etc/apache2/ports.conf > /dev/null
    echo "<VirtualHost *:$PHPMYADMIN_PORT>
        ServerAdmin webmaster@localhost
        DocumentRoot /usr/share/phpmyadmin
        <Directory /usr/share/phpmyadmin>
            AuthType Basic
            AuthName \"Restricted Access\"
            AuthUserFile /etc/phpmyadmin/.htpasswd
            Require valid-user
        </Directory>
    </VirtualHost>" > /etc/apache2/sites-available/phpmyadmin.conf

    # Configuração da autenticação básica para o PhpMyAdmin
    htpasswd -cb /etc/phpmyadmin/.htpasswd pma_user pma_password
    a2ensite phpmyadmin.conf
    systemctl reload apache2

    # Instalação do Certificado SSL com Let's Encrypt
    certbot --apache -d $DOMAIN_NAME --non-interactive --agree-tos -m admin@$DOMAIN_NAME

    echo "Instalação do WordPress concluída para o domínio $DOMAIN_NAME."
    echo "Acesse o WordPress no endereço: https://$DOMAIN_NAME/wp-admin"
}

# Função do menu principal
function menu_wp {
    echo "================= Menu Dolutech WP Automation SO ================="
    echo "1. Instalar nova configuração do WordPress"
    echo "2. Listar todas as instalações do WordPress"
    echo "3. Remover instalação do WordPress"
    echo "4. Instalar/Configurar Fail2Ban e UFW"
    echo "5. Instalar/Configurar ModSecurity com OWASP CRS"
    echo "6. Instalar ClamAV e realizar scans de segurança"
    echo "7. Renovar Certificados SSL"
    echo "8. Sair"
    echo "=================================================================="
    read -p "Escolha uma opção: " OPCAO

    case $OPCAO in
        1) instalar_ambiente ;;
        2) echo "Instalações de WordPress:"; ls /var/www/*/public_html ;;
        3) 
            read -p "Digite o nome do domínio a ser removido: " REMOVER_DOMINIO
            rm -rf /var/www/$REMOVER_DOMINIO
            echo "Instalação de $REMOVER_DOMINIO removida com sucesso."
            ;;
        4) 
            echo "Configurando Fail2Ban e UFW..."
            # Implementar configuração do Fail2Ban e UFW aqui
            ;;
        5) 
            echo "Configurando ModSecurity com OWASP CRS..."
            # Implementar configuração do ModSecurity aqui
            ;;
        6)
            echo "Instalando ClamAV e realizando scan de segurança..."
            # Implementar ClamAV e escaneamento aqui
            ;;
        7) 
            echo "Renovando certificados SSL..."
            certbot renew --dry-run
            ;;
        8) 
            echo "Saindo do sistema."
            exit 0
            ;;
        *) echo "Opção inválida!" ;;
    esac
}

# Verificar se o argumento para abrir o menu foi passado
if [[ "$1" == "menu" ]]; then
    menu_wp
else
    instalar_ambiente
fi
