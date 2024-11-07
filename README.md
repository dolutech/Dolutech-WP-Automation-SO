# Dolutech WP Automation SO

## Visão Geral
O **Dolutech WP Automation SO** é um script de automação completo projetado para a instalação e gestão de ambientes WordPress com Apache, MariaDB, PHP, phpMyAdmin, Redis, Nginx, Varnish, e mod_pagespeed, incluindo SSL com Certbot. Desenvolvido por **Lucas Catão de Moraes**, este script permite configurar um ambiente robusto e otimizado para WordPress, facilitando o processo de instalação e manutenção de várias instâncias.

## Versão e Atualização Automática
- **Versão 0.1* O Sistema está na versão 0.1, está preparado para atualizações automáticas mesmo depois de instalado na sua máquina.

## Pré-requisitos
- **Ubuntu 24.04** (até o momento, o script é compatível apenas com esta versão do sistema operacional).
- Execute o comando a seguir para garantir que o sistema esteja atualizado:
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```

## Instalação
Para instalar e executar o script, copie e cole o seguinte comando no terminal SSH:

```bash
sudo apt update && sudo apt upgrade -y && curl -o /usr/local/bin/Dolutech-WP-Automation-SO.sh https://raw.githubusercontent.com/dolutech/Dolutech-WP-Automation-SO/main/Dolutech-WP-Automation-SO.sh && sudo chmod +x /usr/local/bin/Dolutech-WP-Automation-SO.sh && sudo /usr/local/bin/Dolutech-WP-Automation-SO.sh
```

## Recursos do Script
O **Dolutech WP Automation SO** oferece as seguintes funcionalidades:

### 1. **Configuração Inicial Completa**
- Instalação e configuração de Apache, MariaDB, PHP, Redis, Nginx, Varnish, mod_pagespeed, phpMyAdmin e Certbot.
- Otimizações de configuração do Apache, MariaDB e PHP para melhor desempenho.
- Configuração de mensagens de boas-vindas e alias no sistema.

### 2. **Instalação de WordPress Automatizada**
- Criação de banco de dados e usuário no MariaDB.
- Otimização de Cache no WordPress.
- Sincronização do SSL com Varnish Cache.
- .htaccess configurado e otimizado.
- Configuração de diretórios e permissões adequadas.
- Instalação e configuração do WordPress via WP-CLI.
- Configuração automática de plugins de segurança e cache Redis.

### 3. **Gerenciamento de Instalações**
- Listagem de todas as instalações de WordPress.
- Remoção completa de instalações, incluindo bancos de dados e certificados SSL.

## Estrutura do Script
O script está dividido em funções que realizam as seguintes tarefas:
- **instalar_dependencias_iniciais**: Instala e configura todos os componentes necessários.
- **instalar_wordpress**: Automatiza a instalação de novas instâncias de WordPress.
- **remover_instalacao**: Remove uma instalação de WordPress e suas dependências.
- **menu_wp**: Interface de menu para o gerenciamento das instalações.

## Exemplo de Uso
Após a execução do comando de instalação, você pode iniciar o script digitando:

```bash
dolutech
```

O menu interativo permite:
1. Instalar uma nova configuração de WordPress.
2. Listar todas as instalações existentes.
3. Remover uma instalação.
4. Sair do sistema.

## Contribuição
Este projeto é de código aberto e está disponível no GitHub. Para contribuir, sinta-se à vontade para abrir issues ou fazer pull requests:

[Repositório no GitHub](https://github.com/dolutech/Dolutech-WP-Automation-SO)

## Licença
Este projeto está licenciado sob a [Licença MIT](https://opensource.org/licenses/MIT).

---

**Desenvolvido por Lucas Catão de Moraes**  
Site: [Dolutech](https://dolutech.com)
