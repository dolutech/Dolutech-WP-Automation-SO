# Dolutech WP Automation SO

## Visão Geral
O **Dolutech WP Automation SO** é um script de automação modular e completo projetado para a instalação e gestão de ambientes WordPress com Apache, MariaDB, PHP, phpMyAdmin, Redis, Nginx, Varnish, e mod_pagespeed, incluindo SSL com Certbot. Desenvolvido por **Lucas Catão de Moraes**, este script permite configurar um ambiente robusto e otimizado para WordPress, facilitando o processo de instalação e manutenção de várias instâncias.

## Versão e Atualização
- **Versão 0.2** (Refatorada e Modularizada)

## Pré-requisitos
- **Ubuntu 24.04**

## Instalação

Recomendamos clonar o repositório para obter todos os módulos:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/dolutech/Dolutech-WP-Automation-SO.git /usr/local/src/Dolutech-WP-Automation-SO
cd /usr/local/src/Dolutech-WP-Automation-SO
sudo chmod +x Dolutech-WP-Automation-SO.sh
sudo ./Dolutech-WP-Automation-SO.sh
```

## Recursos
- Stack completa: Apache (Backend), Nginx (Proxy), Varnish (Cache), Redis (Object Cache), ModPagespeed (Otimização).
- Segurança: Fail2Ban, ModSecurity, SSL (Let's Encrypt).
- Gestão: Instalar/Remover WP, Backups, Banco de Dados.

## Estrutura
O sistema agora é modular, localizado na pasta `modulos/`.

- `install_stack.sh`: Instalação dos serviços.
- `wordpress_manager.sh`: Gestão de sites WP.
- `security.sh`: Configuração de segurança.
- `backup_manager.sh`: Gestão de backups.

## Uso
Após a instalação, execute:
```bash
dolutech
```
(Pode ser necessário reiniciar o terminal ou fazer `source ~/.bashrc` na primeira vez)

## Licença
Este projeto está licenciado sob a [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).

---

**Desenvolvido por Lucas Catão de Moraes**  
- Site: [Dolutech](https://dolutech.com)
- Sou apaixonado por Café que tal me pagar um?: [Pagar um café para o Luquinhas!](https://www.paypal.com/paypalme/cataodemoraes)
