# Função para remover o isolamento de um site WordPress
function remover_isolamento_website {
    # Definir o PATH para garantir que os comandos sejam encontrados
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Listar os sites isolados
    ISOLATED_SITES=(/var/www/*/ISOLATED)
    if [ ${#ISOLATED_SITES[@]} -eq 0 ]; then
        echo "Nenhum site isolado encontrado."
        return
    fi

    echo "Sites isolados:"
    for i in "${!ISOLATED_SITES[@]}"; do
        ISOLATED_FILE="${ISOLATED_SITES[$i]}"
        DOMAIN_DIR=$(dirname "$ISOLATED_FILE")      # /var/www/dominio
        DOMAIN_NAME=$(basename "$DOMAIN_DIR")       # Extrai 'dominio' de /var/www/dominio
        echo "$((i+1)). $DOMAIN_NAME"
    done

    read -p "Digite o número do site que deseja remover o isolamento: " OPCAO

    if ! [[ "$OPCAO" =~ ^[0-9]+$ ]] || [ "$OPCAO" -lt 1 ] || [ "$OPCAO" -gt ${#ISOLATED_SITES[@]} ]; then
        echo "Opção inválida."
        return
    fi

    SITE_INDEX=$((OPCAO - 1))
    ISOLATED_FILE="${ISOLATED_SITES[$SITE_INDEX]}"
    DOMAIN_DIR=$(dirname "$ISOLATED_FILE")
    DOMAIN_NAME=$(basename "$DOMAIN_DIR")

    SITE_PUBLIC_HTML="$DOMAIN_DIR/public_html"

    echo "Você selecionou o site: $DOMAIN_NAME"

    # **NOVO:** Copiar os arquivos atualizados do volume Docker para um local temporário
    TEMP_DIR="/tmp/${DOMAIN_NAME}_public_html_$(date +%s)"
    mkdir "$TEMP_DIR"
    sudo cp -r "$SITE_PUBLIC_HTML/." "$TEMP_DIR/"

    # Desmontar o volume Docker
    sudo umount "$SITE_PUBLIC_HTML"

    # Remover o diretório public_html
    sudo rm -rf "$SITE_PUBLIC_HTML"

    # Restaurar os arquivos atualizados do local temporário para public_html
    sudo mv "$TEMP_DIR" "$SITE_PUBLIC_HTML"
    sudo chown -R www-data:www-data "$SITE_PUBLIC_HTML"
    sudo chmod -R 755 "$SITE_PUBLIC_HTML"

    # Remover o contêiner e o volume Docker
    sudo docker rm "${DOMAIN_NAME}_container"
    sudo docker volume rm "${DOMAIN_NAME}_volume"
    sudo docker rmi "${DOMAIN_NAME}_image"

    # Remover o arquivo de marcação
    sudo rm "$DOMAIN_DIR/ISOLATED"

    echo "Isolamento removido do site $DOMAIN_NAME com sucesso. As alterações feitas durante o isolamento foram preservadas."
}
