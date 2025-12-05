#!/bin/bash

source "$(dirname "$0")/modulos/config.sh"
source "$(dirname "$0")/modulos/utils.sh"

function atualizar_certificados_ssl {
    certbot renew --nginx
    log "Certificados renovados." "INFO"
}
