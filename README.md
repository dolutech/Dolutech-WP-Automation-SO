
# Dolutech WP Automation SO

**Dolutech WP Automation SO** é um script de automação para instalação e configuração completa de ambientes WordPress otimizados com Apache em sistemas Debian. Este script instala todas as dependências necessárias, configura o ambiente de Apache e PHP para WordPress, e possibilita a instalação de múltiplas instâncias de WordPress com suporte para SSL via Let's Encrypt, além de outras opções para gerenciamento do ambiente.

## Descrição do Projeto

Este script facilita a instalação de ambientes WordPress, permitindo ao usuário configurar rapidamente o servidor com Apache, MariaDB, PHP 8.3, phpMyAdmin, UFW, Fail2ban, e otimizações adicionais para desempenho e segurança. Além disso, possui uma interface de menu para gerenciar instalações, listar e remover instâncias de WordPress.

### Recursos

- **Instalação de ambiente WordPress completo**: Apache, MariaDB, PHP 8.3, phpMyAdmin, Certificados SSL via Let's Encrypt.
- **Configuração de Alias `wp`**: Atalho para iniciar o menu do script.
- **Configuração de Segurança**: Fail2ban e UFW para proteção de firewall.
- **Instalação de Plugins de Segurança**: Plugins populares de segurança para o WordPress.
- **Gerenciamento via Menu**: Instalar, listar e remover instâncias de WordPress diretamente no terminal.

## Requisitos

- **Sistema Operacional**: Debian 12 ou superior.
- **Permissões**: Usuário root ou com privilégios de `sudo`.

## Como Instalar

1. Clone o repositório para o seu servidor:
   ```bash
   git clone https://github.com/dolutech/Dolutech-WP-Automation-SO.git
   cd Dolutech-WP-Automation-SO
   ```

2. Dê permissão de execução ao script:
   ```bash
   chmod +x Dolutech-WP-Automation-SO.sh
   ```

3. Execute o script para iniciar o menu de instalação:
   ```bash
   sudo ./Dolutech-WP-Automation-SO.sh
   ```

4. **Primeira Execução**: O script irá configurar uma mensagem de boas-vindas e um alias `wp` para simplificar a execução do menu.

## Opções do Menu

1. **Instalar nova configuração do WordPress**: Instala uma nova instância do WordPress, solicitando informações como domínio, banco de dados e configurações de administrador.
2. **Listar todas as instalações do WordPress**: Exibe uma lista de todas as instalações de WordPress no servidor.
3. **Remover instalação do WordPress**: Remove uma instalação específica do WordPress, apagando os arquivos do domínio especificado.
4. **Sair**: Encerra o menu.

## Estrutura do Script

- **Configuração Inicial**: O script configura uma mensagem de boas-vindas em `/etc/motd` e cria o alias `wp` para facilitar o acesso ao menu.
- **Instalação do Ambiente**: Configura Apache, MariaDB, PHP, phpMyAdmin e otimizações para WordPress, além de instalar e ativar plugins de segurança.
- **Configuração do Apache**: Cria configurações personalizadas, otimizando cache e compressão.
- **Configuração do PHP**: Ajusta limites de memória e outros parâmetros para um desempenho otimizado.
- **Certificados SSL**: Configura automaticamente SSL usando Let's Encrypt para garantir a segurança das conexões.
- **Segurança**: Instala e configura UFW e Fail2ban, aumentando a proteção contra ataques.

## Como Usar

Após a instalação, use o alias `wp` para acessar o menu sempre que necessário:
```bash
wp
```

O menu permitirá a instalação de novas instâncias de WordPress, listagem e remoção de instalações, além de fornecer um controle completo do ambiente.

## Estrutura do Projeto

- `Dolutech-WP-Automation-SO.sh`: Script principal para instalação e gerenciamento do WordPress.
- `README.md`: Documentação detalhada do projeto.

## Créditos

Desenvolvido por: **Lucas Catão de Moraes**  
Website: [Dolutech](https://dolutech.com)

## Licença

Este projeto é licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## Contribuição

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues e pull requests para melhorias no script ou na documentação.

## Palavras-chave e Hashtags

- Automação WordPress
- Script Bash WordPress
- Apache e PHP WordPress
- Automação Servidor Web
- Segurança WordPress
- UFW e Fail2ban

**Hashtags**: #WordPress #Automacao #Seguranca #Dolutech #Apache #BashScript
