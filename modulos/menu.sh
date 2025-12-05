#!/bin/bash

source "$(dirname "$0")/modulos/config.sh"
source "$(dirname "$0")/modulos/wordpress_manager.sh"
source "$(dirname "$0")/modulos/backup_manager.sh"
source "$(dirname "$0")/modulos/database_manager.sh"
source "$(dirname "$0")/modulos/security.sh"
source "$(dirname "$0")/modulos/docker_manager.sh"
source "$(dirname "$0")/modulos/ssl_manager.sh"

function menu_wp {
    while true; do
        echo -e "${BLUE}================= Menu Dolutech WP Automation SO =================${NC}"
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
        echo "11. Configurar Segurança"
        echo "12. Isolar Website (Docker)"
        echo "13. Remover Isolamento de Website"
        echo "14. Sair"
        echo "=================================================================="
        read -p "Escolha uma opção: " OPCAO

        case $OPCAO in
            1) instalar_wordpress ;;
            2) listar_instalacoes ;;
            3) fazer_backup ;;
            4) remover_instalacao ;;
            5) gerenciar_backups_automaticos ;;
            6) restaurar_backup ;;
            7) atualizar_certificados_ssl ;;
            8) dominio_instalacao_manual ;;
            9) assistente_data_base ;;
            10) gerenciar_bancos_de_dados ;;
            11) configurar_seguranca ;;
            12) isolar_website ;;
            13) remover_isolamento_website ;;
            14) echo "Saindo..."; exit 0 ;;
            *) echo "Opção inválida!" ;;
        esac

        echo
        read -p "Pressione Enter para continuar..."
    done
}
