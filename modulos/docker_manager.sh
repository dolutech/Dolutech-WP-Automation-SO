#!/bin/bash

source "$(dirname "$0")/modulos/config.sh"
source "$(dirname "$0")/modulos/utils.sh"

function isolar_website {
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        log "Instalando Docker..." "INFO"
        apt-get update
        apt-get install -y docker.io
        systemctl enable --now docker
        usermod -aG docker $USER
        log "Docker instalado." "INFO"
    fi

    # Listar sites
    local INSTALACOES=(/var/www/*/public_html/wp-config.php)
    if [ ${#INSTALACOES[@]} -eq 0 ]; then
        log "Nenhum site encontrado." "WARN"
        return
    fi

    echo "Sites:"
    for i in "${!INSTALACOES[@]}"; do
        local DIR=$(dirname "${INSTALACOES[$i]}") # public_html
        local DOM_DIR=$(dirname "$DIR") # dominio
        echo "$((i+1)). $(basename "$DOM_DIR")"
    done

    read -p "Número do site para isolar: " NUM
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt ${#INSTALACOES[@]} ]; then
        log "Opção inválida." "ERROR"
        return
    fi

    local WP_CONFIG="${INSTALACOES[$((NUM-1))]}"
    local SITE_DIR=$(dirname "$WP_CONFIG")
    local DOMAIN_DIR=$(dirname "$SITE_DIR")
    local DOMAIN_NAME=$(basename "$DOMAIN_DIR")
    local RELATIVE_PATH="${SITE_DIR#/}"

    log "Isolando $DOMAIN_NAME..." "INFO"

    if [ -f "$DOMAIN_DIR/ISOLATED" ]; then
        log "Já isolado." "WARN"
        return
    fi

    # Limpar anterior se existir
    docker rm -f "${DOMAIN_NAME}_container" 2>/dev/null
    docker volume rm "${DOMAIN_NAME}_volume" 2>/dev/null

    # Build Image
    local DOCKERFILE=$(mktemp)
    cat > "$DOCKERFILE" <<EOF
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends apt-utils rsync && \
    rm -rf /var/lib/apt/lists/*
COPY . /${RELATIVE_PATH}
EOF

    log "Construindo imagem..." "INFO"
    docker build -t "${DOMAIN_NAME}_image" -f "$DOCKERFILE" "$SITE_DIR"
    rm "$DOCKERFILE"

    if [ $? -ne 0 ]; then
        log "Erro no build docker." "ERROR"
        return
    fi

    docker volume create "${DOMAIN_NAME}_volume"

    # Run Container
    docker run -d --name "${DOMAIN_NAME}_container" \
        --restart unless-stopped \
        -v "${DOMAIN_NAME}_volume":"/${RELATIVE_PATH}" \
        "${DOMAIN_NAME}_image" tail -f /dev/null

    # Sync
    docker cp "$SITE_DIR/." "${DOMAIN_NAME}_container":"/${RELATIVE_PATH}"

    # Switch to Volume
    docker stop "${DOMAIN_NAME}_container"
    mv "$SITE_DIR" "$DOMAIN_DIR/public_html_backup"
    mkdir -p "$SITE_DIR"
    mount -o bind "/var/lib/docker/volumes/${DOMAIN_NAME}_volume/_data" "$SITE_DIR"
    docker start "${DOMAIN_NAME}_container"

    touch "$DOMAIN_DIR/ISOLATED"
    log "Site isolado." "INFO"
}

function remover_isolamento_website {
    local ISOLATED_SITES=(/var/www/*/ISOLATED)
    if [ ${#ISOLATED_SITES[@]} -eq 0 ]; then
        log "Nenhum site isolado." "WARN"
        return
    fi

    echo "Sites isolados:"
    for i in "${!ISOLATED_SITES[@]}"; do
        echo "$((i+1)). $(basename "$(dirname "${ISOLATED_SITES[$i]}")")"
    done

    read -p "Número para remover isolamento: " NUM
    local FILE="${ISOLATED_SITES[$((NUM-1))]}"
    local DOMAIN_DIR=$(dirname "$FILE")
    local DOMAIN_NAME=$(basename "$DOMAIN_DIR")
    local SITE_PUBLIC_HTML="$DOMAIN_DIR/public_html"

    log "Removendo isolamento de $DOMAIN_NAME..." "INFO"

    docker stop "${DOMAIN_NAME}_container" 2>/dev/null

    # Backup data from container
    local TEMP_DIR="/tmp/${DOMAIN_NAME}_restore"
    mkdir -p "$TEMP_DIR"
    # docker cp syntax: container:path hostpath
    # path inside container is absolute path of public_html. We need to find it.
    # Assuming it mirrors host path as per isolation logic
    local CONTAINER_PATH="${SITE_PUBLIC_HTML#/}"
    docker cp "${DOMAIN_NAME}_container:/$CONTAINER_PATH" "$TEMP_DIR"

    umount "$SITE_PUBLIC_HTML"
    rm -rf "$SITE_PUBLIC_HTML"

    # Restore from container copy
    mv "$TEMP_DIR/$(basename "$SITE_PUBLIC_HTML")" "$SITE_PUBLIC_HTML"
    chown -R www-data:www-data "$SITE_PUBLIC_HTML"
    chmod -R 755 "$SITE_PUBLIC_HTML"
    rm -rf "$TEMP_DIR"

    docker rm "${DOMAIN_NAME}_container"
    docker volume rm "${DOMAIN_NAME}_volume"
    docker rmi "${DOMAIN_NAME}_image"
    rm "$FILE"
    rm -rf "$DOMAIN_DIR/public_html_backup"

    log "Isolamento removido." "INFO"
}
