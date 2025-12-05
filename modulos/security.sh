#!/bin/bash

source "$(dirname "$0")/modulos/config.sh"
source "$(dirname "$0")/modulos/utils.sh"

function configurar_seguranca {
    log "Configurando segurança..." "INFO"

    # ModSecurity
    apt install -y libapache2-mod-security2
    a2enmod security2
    if [ -f "/etc/modsecurity/modsecurity.conf-recommended" ]; then
        cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
        sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
    fi

    apt install -y modsecurity-crs
    cp /usr/share/modsecurity-crs/crs-setup.conf.example /etc/modsecurity/crs-setup.conf

    echo "IncludeOptional /usr/share/modsecurity-crs/*.conf" >> /etc/apache2/mods-enabled/security2.conf

    systemctl restart apache2

    # Fail2Ban
    apt install -y fail2ban
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

    cat >> /etc/fail2ban/jail.local <<EOL
[wordpress]
enabled = true
port = http,https
filter = wordpress-auth
logpath = /var/log/nginx/*access.log
maxretry = 5
bantime = 3600
EOL

    cat > /etc/fail2ban/filter.d/wordpress-auth.conf <<EOL
[Definition]
failregex = ^<HOST> .*POST .*wp-login.php HTTP.* 200
ignoreregex =
EOL

    systemctl restart fail2ban
    log "Segurança configurada." "INFO"
}
