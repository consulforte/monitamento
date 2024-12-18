#!/bin/bash

# Script de Integração Avançada de Tíquetes e Alertas
BASE_PATH="/opt/monitoramento-redes"
CONFIG_PATH="${BASE_PATH}/config/alertas_config.json"

# Configuração de Alertas Centralizados
configurar_alertas_prometheus() {
    mkdir -p "${BASE_PATH}/config/prometheus/alerts"
    
    cat > "${BASE_PATH}/config/prometheus/alerts/regras_principais.yml" << 'EOL'
groups:
- name: exemplo_alertas
  rules:
  - alert: ServidorIndisponivel
    expr: up == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Servidor {{ $labels.instance }} está fora do ar"
      description: "O servidor {{ $labels.instance }} não responde há 5 minutos"
  
  - alert: AltoUsoCPU
    expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Alto uso de CPU no servidor {{ $labels.instance }}"
      description: "Uso de CPU acima de 85% por 10 minutos"
  
  - alert: BaixoEspaçoDisco
    expr: node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100 < 10
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Espaço em disco baixo"
      description: "Menos de 10% de espaço livre no disco"
EOL
}

# Configuração de Alertmanager
configurar_alertmanager() {
    cat > "${BASE_PATH}/config/prometheus/alertmanager.yml" << 'EOL'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: 'slack-notifications'

receivers:
- name: 'slack-notifications'
  slack_configs:
  - api_url: 'https://hooks.slack.com/services/SEU_WEBHOOK'
    channel: '#monitoramento'
    text: "{{ range .Alerts }}Alerta: {{ .Annotations.summary }}\nDescrição: {{ .Annotations.description }}\nSeveridade: {{ .Labels.severity }}\n{{ end }}"

- name: 'email-notifications'
  email_configs:
  - to: 'equipe@empresa.com'
    from: 'monitoramento@empresa.com'
    smarthost: 'smtp.empresa.com:587'
    auth_username: 'usuario'
    auth_password: 'senha'
EOL
}

# Configuração de Tíquetes no GLPI
configurar_glpi_integracao() {
    cat > "${BASE_PATH}/integracao/glpi_integracao.py" << 'EOL'
#!/usr/bin/env python3
import requests
import json
import os

class GLPIIntegrador:
    def __init__(self, url, token):
        self.url = url
        self.token = token
        self.headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Basic {token}'
        }
    
    def criar_ticket(self, titulo, descricao, categoria, prioridade=3):
        payload = {
            'input': {
                'name': titulo,
                'content': descricao,
                'status': 1,  # Novo
                'urgency': prioridade,
                '_users_id_requester': 1  # ID do usuário
            }
        }
        
        response = requests.post(
            f'{self.url}/Ticket',
            headers=self.headers,
            data=json.dumps(payload)
        )
        
        return response.json()

def processar_alerta(alerta):
    glpi = GLPIIntegrador(
        url='http://glpi.empresa.local/apirest.php',
        token='token_de_autenticacao'
    )
    
    ticket = glpi.criar_ticket(
        titulo=f"Alerta: {alerta['nome']}",
        descricao=f"Detalhes do Alerta:\n{json.dumps(alerta, indent=2)}",
        categoria="Monitoramento",
        prioridade=alerta.get('prioridade', 3)
    )
    
    print(f"Ticket criado: {ticket}")

# Exemplo de uso
if __name__ == "__main__":
    alerta_exemplo = {
        'nome': 'ServidorIndisponivel',
        'descricao': 'Servidor principal fora do ar',
        'prioridade': 5
    }
    processar_alerta(alerta_exemplo)
EOL

    chmod +x "${BASE_PATH}/integracao/glpi_integracao.py"
}

# Integração de Logs Wazuh
configurar_wazuh_logs() {
    cat > "${BASE_PATH}/config/wazuh/custom_rules.xml" << 'EOL'
<group name="local,syslog,">
    <rule id="100100" level="10">
        <if_sid>5700</if_sid>
        <match>high_severity_event</match>
        <description>Evento de alta severidade detectado</description>
        <action>alert</action>
    </rule>

    <rule id="100101" level="7">
        <if_sid>5500</if_sid>
        <match>potential_security_issue</match>
        <description>Possível problema de segurança identificado</description>
        <action>log</action>
    </rule>
</group>
EOL
}

# Função Principal
main() {
    configurar_alertas_prometheus
    configurar_alertmanager
    configurar_glpi_integracao
    configurar_wazuh_logs

    echo "Configurações de alertas e tíquetes concluídas!"
}

# Executar
main
