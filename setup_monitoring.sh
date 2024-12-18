#!/bin/bash

# Script de Configuração do Sistema de Monitoramento de Redes
# Versão: 1.0
# Compatibilidade: Ubuntu 20.04+

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Diretório base do projeto
BASE_DIR="/opt/monitoramento"

# Função de log
log() {
    echo -e "${GREEN}[LOG]${NC} $1"
}

# Função de erro
error() {
    echo -e "${RED}[ERRO]${NC} $1"
    exit 1
}

# Verificar se o script está sendo executado como root
if [[ $EUID -ne 0 ]]; then
   error "Este script deve ser executado como root. Use: sudo $0"
fi

# Função para instalar pré-requisitos
instalar_prerequisitos() {
    log "Instalando pré-requisitos..."
    apt-get update
    apt-get install -y \
        docker.io \
        docker-compose \
        git \
        curl \
        wget \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release
    
    # Adicionar usuário atual ao grupo docker
    usermod -aG docker $SUDO_USER
}

# Criar estrutura de diretórios
criar_estrutura() {
    log "Criando estrutura de diretórios..."
    mkdir -p ${BASE_DIR}/{docker,scripts,config,integracao,docs,relatorios}
    mkdir -p ${BASE_DIR}/docker/{prometheus,grafana,wazuh,zabbix,netbox,glpi}
    mkdir -p ${BASE_DIR}/logs
    
    # Definir permissões
    chown -R $SUDO_USER:$SUDO_USER ${BASE_DIR}
}

# Criar arquivo de configuração centralizado
criar_config() {
    log "Criando arquivo de configuração config.cfg..."
    cat > ${BASE_DIR}/config/config.cfg << EOL
# Configuração Centralizada do Sistema de Monitoramento

# Credenciais Gerais
ADMIN_USERNAME=admin
ADMIN_PASSWORD=mudarsenha123!

# Configurações de Rede
NETWORK_SUBNET=192.168.1.0/24
GATEWAY=192.168.1.1

# Limites de Alertas
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90

# Configurações de Ferramentas
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
WAZUH_PORT=1515
ZABBIX_PORT=10051
GLPI_PORT=80
NETBOX_PORT=8000

# Configurações de Integração
LDAP_SERVER=ldap.empresa.com
LDAP_BASE_DN=DC=empresa,DC=com
EOL
}

# Criar scripts utilitários básicos
criar_scripts_utilitarios() {
    log "Criando scripts utilitários..."
    
    # Script de backup
    cat > ${BASE_DIR}/scripts/backup.sh << 'EOB'
#!/bin/bash
BACKUP_DIR="/opt/monitoramento/backups"
DATE=$(date +"%Y%m%d_%H%M%S")

mkdir -p $BACKUP_DIR

# Backup das configurações
cp -R /opt/monitoramento/config $BACKUP_DIR/config_$DATE
docker-compose ps > $BACKUP_DIR/docker_status_$DATE.txt

echo "Backup concluído em $BACKUP_DIR/config_$DATE"
EOB

    # Script de verificação de saúde
    cat > ${BASE_DIR}/scripts/health_check.sh << 'EOH'
#!/bin/bash
# Verificar status dos serviços

docker-compose ps
docker-compose logs --tail=50
EOH

    chmod +x ${BASE_DIR}/scripts/*.sh
}

# Preparar docker-compose inicial
criar_docker_compose() {
    log "Criando docker-compose inicial..."
    cat > ${BASE_DIR}/docker-compose.yml << 'EOD'
version: '3.8'
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./config/prometheus:/etc/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"

  wazuh:
    image: wazuh/wazuh-manager
    ports:
      - "1515:1515"

  zabbix:
    image: zabbix/zabbix-server-mysql
    ports:
      - "10051:10051"

  netbox:
    image: netbox/netbox
    ports:
      - "8000:8000"
EOD
}

# Função principal
main() {
    log "Iniciando configuração do Sistema de Monitoramento"
    
    instalar_prerequisitos
    criar_estrutura
    criar_config
    criar_scripts_utilitarios
    criar_docker_compose
    
    log "Configuração concluída com sucesso!"
    log "Diretório base: ${BASE_DIR}"
    log "Próximos passos: revisar config.cfg e iniciar os containers"
}

# Executar script
main
