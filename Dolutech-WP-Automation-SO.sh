#!/bin/bash

# Nome do Sistema
NOME_SISTEMA="Dolutech WP Automation SO"

# Função para exibir mensagem de boas-vindas
function mensagem_boas_vindas {
    echo "=========================================="
    echo "Bem-vindo ao $NOME_SISTEMA"
    echo "=========================================="
}

# Função para instalar o ambiente completo
function instalar_ambiente {
    mensagem_boas_vindas
    
    # Variáveis de entrada do usuário
    read -p "Digite a porta para o PhpMyAdmin: " PHPMYADMIN_PORT
    read -p "Digite o caminho customizado para o wp-admin: " WP_ADMIN_PATH
    read -p "Digite o nome do banco de dados: " DB_NAME
    read -p "Digite o usuário do banco de dados: " DB_USER
    read -sp "Digite a senha do banco de dados: " DB_PASS
    echo ""
    read -p "Digite o nome do domínio para o WordPress: " DOMAIN_NAME
    read -p "Digite o usuário FTP: " FTP_USER
    read -sp "Digite a senha do usuário FTP: " FTP_PASS
    echo ""
    read -p "Digite o caminho da instalação do WordPress (/var/www/$DOMAIN_NAME/public_html): " WP_PATH
    read -p "Digite o usuário administrador do WordPress: " WP_ADMIN_USER
    read -sp "Digite a senha do administrador do WordPress: " WP_ADMIN_PASS
    echo ""

    # Atualização de pacotes e instalação de dependências
    apt update && apt upgrade -y
    apt install -y apache2 nginx mariadb-server php8.3 php8.3-fpm php8.3-mysql php8.3-curl php8.3-xml php8.3-redis redis-server pure-ftpd phpmyadmin varnish composer wget unzip ufw fail2ban

    # Configuração de MariaDB
    systemctl start mariadb
    mysql -e "CREATE DATABASE $DB_NAME;"
    mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    # Configuração do Apache e Nginx
    mkdir -p /var/www/$DOMAIN_NAME/public_html
    chown -R www-data:www-data /var/www/$DOMAIN_NAME/public_html

    # Configuração do PhpMyAdmin para a porta customizada
    sed -i "s/Listen 80/Listen $PHPMYADMIN_PORT/" /etc/apache2/ports.conf
    echo "<VirtualHost *:$PHPMYADMIN_PORT>
        ServerAdmin webmaster@localhost
        DocumentRoot /usr/share/phpmyadmin
    </VirtualHost>" > /etc/apache2/sites-available/phpmyadmin.conf
    a2ensite phpmyadmin.conf
    systemctl reload apache2

    # Configuração de FTP
    useradd -d /var/www/$DOMAIN_NAME/public_html -s /usr/sbin/nologin $FTP_USER
    echo "$FTP_USER:$FTP_PASS" | chpasswd
    pure-pw useradd $FTP_USER -u www-data -d /var/www/$DOMAIN_NAME/public_html
    pure-pw mkdb

    # Configuração do Varnish
    sed -i 's/.Port = "8080"/.Port = "80"/' /etc/varnish/default.vcl
    systemctl restart varnish

    # Instalação do WordPress CLI e do Composer
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp

    cd /var/www/$DOMAIN_NAME/public_html
    composer create-project johnpbloch/wordpress
    chown -R www-data:www-data /var/www/$DOMAIN_NAME/public_html

    # Configuração do WordPress via WP-CLI
    wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS --path=/var/www/$DOMAIN_NAME/public_html
    wp core install --url="http://$DOMAIN_NAME" --title="Site $DOMAIN_NAME" --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASS --admin_email="admin@$DOMAIN_NAME" --path=/var/www/$DOMAIN_NAME/public_html
    wp plugin install all-in-one-wp-security-and-firewall headers-security-advanced-hsts-wp ninja-firewall sucuri-scanner --activate --path=/var/www/$DOMAIN_NAME/public_html

    # Configuração de diretórios e permissões
    mkdir -p /var/www/$DOMAIN_NAME/public_html/$WP_ADMIN_PATH
    chown -R www-data:www-data /var/www/$DOMAIN_NAME/public_html/$WP_ADMIN_PATH

    echo "Instalação do WordPress concluída para o domínio $DOMAIN_NAME"
}

# Função para gerenciar o UFW (Firewall)
function configurar_ufw {
    echo "================= Configuração do UFW ================="
    echo "1. Liberar uma porta"
    echo "2. Bloquear uma porta"
    echo "3. Voltar ao menu principal"
    read -p "Escolha uma opção: " OPCAO_UFW

    case $OPCAO_UFW in
        1)
            read -p "Digite a porta a ser liberada: " PORTA_LIBERAR
            ufw allow $PORTA_LIBERAR
            echo "Porta $PORTA_LIBERAR liberada com sucesso."
            ;;
        2)
            read -p "Digite a porta a ser bloqueada: " PORTA_BLOQUEAR
            ufw deny $PORTA_BLOQUEAR
            echo "Porta $PORTA_BLOQUEAR bloqueada com sucesso."
            ;;
        3)
            ;;
        *)
            echo "Opção inválida!"
            configurar_ufw
            ;;
    esac
}

# Função para instalar e configurar o Fail2ban com proteção para WordPress
function configurar_fail2ban {
    echo "================= Configuração do Fail2ban ================="
    echo "1. Instalar Fail2ban com proteção para WordPress"
    echo "2. Desativar Fail2ban"
    echo "3. Voltar ao menu principal"
    read -p "Escolha uma opção: " OPCAO_FAIL2BAN

    case $OPCAO_FAIL2BAN in
        1)
            # Instala e ativa o Fail2ban
            systemctl enable fail2ban
            systemctl start fail2ban

            # Criação de configuração customizada para proteger wp-login.php
            cat <<EOL > /etc/fail2ban/jail.local
[wordpress]
enabled = true
filter = wordpress
logpath = /var/log/apache2/*error.log
maxretry = 5
bantime = 3600
findtime = 600
EOL

            # Filtro personalizado para WordPress
            cat <<EOL > /etc/fail2ban/filter.d/wordpress.conf
[Definition]
failregex = ^<HOST> -.*POST /wp-login.php
ignoreregex =
EOL

            # Reinicia o Fail2ban para aplicar as configurações
            systemctl restart fail2ban
            echo "Fail2ban instalado e configurado com proteção para WordPress."
            ;;
        2)
            # Desativa o Fail2ban
            systemctl stop fail2ban
            systemctl disable fail2ban
            echo "Fail2ban desativado com sucesso."
            ;;
        3)
            ;;
        *)
            echo "Opção inválida!"
            configurar_fail2ban
            ;;
    esac
}

# Função para gerenciar instalações existentes de WordPress
function menu_wp {
    echo "================= Menu Dolutech WP Automation SO ================="
    echo "1. Instalar nova configuração do WordPress"
    echo "2. Listar todas as instalações do WordPress"
    echo "3. Remover instalação do WordPress"
    echo "4. Configurar UFW (Firewall)"
    echo "5. Configurar Fail2ban"
    echo "6. Sair"
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
            configurar_ufw
            ;;
        5)
            configurar_fail2ban
            ;;
        6)
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
