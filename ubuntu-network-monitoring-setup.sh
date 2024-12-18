#!/bin/bash

# Script de Integração Automatizada de Monitoramento de Redes
# Versão: 1.0
# Objetivo: Instalação e Integração Completa de Ferramentas de Monitoramento

# Variáveis Globais
VERSAO="1.0"
BASE_PATH="/opt/monitoramento-redes"
CONFIG_PATH="${BASE_PATH}/configuracao.json"
LOG_FILE="/var/log/monitoramento_integracao.log"

# Cores para saída
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Função de Log Centralizada
log_eventos() {
    local tipo=$1
    local mensagem=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $tipo in
        "info")
            echo -e "${GREEN}[INFO ${timestamp}]${NC} $mensagem" | tee -a "$LOG_FILE"
            ;;
        "aviso")
            echo -e "${YELLOW}[AVISO ${timestamp}]${NC} $mensagem" | tee -a "$LOG_FILE"
            ;;
        "erro")
            echo -e "${RED}[ERRO ${timestamp}]${NC} $mensagem" | tee -a "$LOG_FILE"
            exit 1
            ;;
    esac
}

# Verificar Pré-Requisitos
verificar_prerequisitos() {
    log_eventos "info" "Verificando pré-requisitos do sistema"
    
    # Lista de pacotes necessários
    local pacotes=(
        "curl" "wget" "git" "jq"
        "software-properties-common"
        "docker.io" "docker-compose"
    )
    
    for pacote in "${pacotes[@]}"; do
        if ! dpkg -s "$pacote" >/dev/null 2>&1; then
            log_eventos "aviso" "Instalando $pacote"
            apt-get update
            apt-get install -y "$pacote"
        fi
    done

    # Verificar versões Docker
    docker version >/dev/null 2>&1 || {
        log_eventos "erro" "Falha na instalação do Docker"
    }
}

# Gerar Configuração Centralizada
gerar_configuracao_central() {
    log_eventos "info" "Gerando configuração centralizada"
    
    mkdir -p "${BASE_PATH}/config"
    
    jq -n '{
        "ambiente": {
            "nome": "Producao",
            "versao": "1.0"
        },
        "ferramentas": {
            "prometheus": {
                "porta": 9090,
                "status": "ativo"
            },
            "grafana": {
                "porta": 3000,
                "status": "ativo"
            },
            "wazuh": {
                "porta": 1514,
                "status": "ativo"
            },
            "zabbix": {
                "porta": 10051,
                "status": "ativo"
            }
        },
        "limites_monitoramento": {
            "cpu": 85,
            "memoria": 90,
            "disco": 80
        },
        "integracao": {
            "metodo": "docker_network",
            "tipo": "bridge"
        }
    }' > "$CONFIG_PATH"
}

# Configurar Rede Docker
configurar_rede_docker() {
    log_eventos "info" "Configurando rede Docker para integração"
    
    docker network create --driver bridge monitoramento_network || {
        log_eventos "erro" "Falha ao criar rede Docker"
    }
}

# Criar Docker Compose Integrado
criar_docker_compose() {
    log_eventos "info" "Criando configuração Docker Compose"
    
    cat > "${BASE_PATH}/docker-compose.yml" << EOL
version: '3.8'
networks:
  monitoramento:
    external: true

services:
  prometheus:
    image: prom/prometheus
    container_name: prometheus
    networks:
      - monitoramento
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus:/etc/prometheus

  grafana:
    image: grafana/grafana
    container_name: grafana
    networks:
      - monitoramento
    ports:
      - "3000:3000"
    depends_on:
      - prometheus

  wazuh:
    image: wazuh/wazuh-manager
    container_name: wazuh
    networks:
      - monitoramento
    ports:
      - "1514:1514"
      - "1515:1515"

  zabbix:
    image: zabbix/zabbix-server-mysql
    container_name: zabbix-server
    networks:
      - monitoramento
    ports:
      - "10051:10051"
EOL
}

# Script de Integração Automatizada
criar_script_integracao() {
    log_eventos "info" "Criando script de integração entre ferramentas"
    
    cat > "${BASE_PATH}/integracao/verificar_conectividade.sh" << 'EOL'
#!/bin/bash

# Verificar status dos serviços
verificar_servico() {
    local servico=$1
    local porta=$2
    
    if nc -z localhost "$porta"; then
        echo "Serviço $servico disponível na porta $porta"
        return 0
    else
        echo "Falha: $servico não disponível na porta $porta"
        return 1
    fi
}

# Lista de verificação
servicos=(
    "prometheus:9090"
    "grafana:3000"
    "wazuh:1514"
    "zabbix:10051"
)

# Executar verificações
for servico_info in "${servicos[@]}"; do
    IFS=':' read -r nome porta <<< "$servico_info"
    verificar_servico "$nome" "$porta"
done
EOL

    chmod +x "${BASE_PATH}/integracao/verificar_conectividade.sh"
}

# Função Principal de Execução
main() {
    clear
    log_eventos "info" "Iniciando Instalação Automatizada v${VERSAO}"
    
    # Verificações e configurações
    verificar_prerequisitos
    gerar_configuracao_central
    configurar_rede_docker
    criar_docker_compose
    criar_script_integracao
    
    # Iniciar serviços
    cd "${BASE_PATH}" && docker-compose up -d
    
    log_eventos "info" "Instalação concluída com sucesso!"
    log_eventos "info" "Execute ./integracao/verificar_conectividade.sh para validar"
}

# Iniciar script
main
