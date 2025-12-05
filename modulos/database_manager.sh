#!/bin/bash

source "$(dirname "$0")/modulos/config.sh"
source "$(dirname "$0")/modulos/utils.sh"

function assistente_data_base {
    read -p "Nome do DB: " DB_NAME
    read -p "Usuário do DB: " DB_USER
    DB_PASS=$(generate_password 12)

    log "Criando DB $DB_NAME e user $DB_USER..." "INFO"
    mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
    mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"

    echo "Senha: $DB_PASS"

    read -p "Importar SQL? (s/n): " IMP
    if [ "$IMP" == "s" ]; then
        read -p "Caminho do arquivo: " FILE
        if [ -f "$FILE" ]; then
            mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$FILE"
            log "Importado." "INFO"
        else
            log "Arquivo não encontrado." "ERROR"
        fi
    fi
}

function gerenciar_bancos_de_dados {
    mysql -e "SHOW DATABASES;" | grep -Ev "Database|information_schema|performance_schema|mysql|sys"
    # Lógica de remoção seria similar ao script original
}
