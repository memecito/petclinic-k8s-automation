#!/bin/bash

# --- 1. Configuración de Rutas y Prefijos ---
SCRIPT_DIR="/home/vagrant/provisioning_files/scripts"
cd "$SCRIPT_DIR" || exit

PRE="spring-petclinic-" # Prefijo que usamos para buscar imágenes y carpetas
VERSION="0.0.1" 
IP_VM=$(hostname -I | awk '{print $1}')
mkdir -p k8s-generated

# Definicion de Oleadas (Waves) de despliegues

WAVE_1=("config-server")
WAVE_2=("discovery-server")
WAVE_3=("customers-service" "vets-service" "visits-service" "genai-service")
WAVE_4=("api-gateway" "admin-server")
WAVE_5=("prometheus" "grafana")

# Función para desplegar una oleada
deploy_wave() {
    local WAVE=("$@")
    for SERVICE in "${WAVE[@]}"
    do
        export SERVICE_NAME=$SERVICE 
        export IMAGE_NAME="$IP_VM:5000/${PRE}${SERVICE}:${VERSION}"    

        case $SERVICE in
            "api-gateway") 
                export CONTAINER_PORT=8080 && export SERVICE_TYPE="LoadBalancer" && export EXTERNAL_PORT=80 ;;
            "config-server") 
                export CONTAINER_PORT=8888 && export SERVICE_TYPE="ClusterIP" && export EXTERNAL_PORT=8888 ;;
            "discovery-server") 
                export CONTAINER_PORT=8761 && export SERVICE_TYPE="ClusterIP" && export EXTERNAL_PORT=8761 ;;
            "admin-server") 
                export CONTAINER_PORT=9090 && export SERVICE_TYPE="ClusterIP" && export EXTERNAL_PORT=9090 ;;
            # Puertos reales de cada servicio (los mismos a los que apunta prometheus.yml)
            "customers-service")
                export CONTAINER_PORT=8081 && export SERVICE_TYPE="ClusterIP" && export EXTERNAL_PORT=8081 ;;
            "visits-service")
                export CONTAINER_PORT=8082 && export SERVICE_TYPE="ClusterIP" && export EXTERNAL_PORT=8082 ;;
            "vets-service")
                export CONTAINER_PORT=8083 && export SERVICE_TYPE="ClusterIP" && export EXTERNAL_PORT=8083 ;;
            "genai-service")
                export CONTAINER_PORT=8084 && export SERVICE_TYPE="ClusterIP" && export EXTERNAL_PORT=8084 ;;
            *) 
                export CONTAINER_PORT=8080 && export SERVICE_TYPE="ClusterIP" && export EXTERNAL_PORT=8080 ;;
        esac

        echo "⚙️  Generando YAML para: $SERVICE_NAME"
        envsubst < k8s-template.yaml > k8s-generated/$SERVICE.yaml
        
        echo "📦 Aplicando $SERVICE_NAME..."
        kubectl apply -f k8s-generated/$SERVICE.yaml
    done
}

deploy_monitoring() {
    local TOOLS=("$@")
    for TOOL in "${TOOLS[@]}"
    do
        export SERVICE_NAME=$TOOL
        export IMAGE_NAME="$IP_VM:5000/${TOOL}:${VERSION}"

        echo "📊 Configurando herramienta de monitoreo: $TOOL"

        if [[ "$TOOL" == "prometheus" ]]; then
            # Prometheus suele ser interno, pero si lo quieres externo cambia a LoadBalancer
            export CONTAINER_PORT=9090 && export SERVICE_TYPE="ClusterIP" && export EXTERNAL_PORT=9090
        elif [[ "$TOOL" == "grafana" ]]; then
            # CAMBIO CRUCIAL: Usamos LoadBalancer para que K3s lo exponga en el puerto 3000 de la IP de la VM
            export CONTAINER_PORT=3000 && export SERVICE_TYPE="LoadBalancer" && export EXTERNAL_PORT=3000
        fi

        echo "⚙️  Generando YAML: k8s-generated/$TOOL.yaml"
        envsubst < k8s-template.yaml > k8s-generated/$TOOL.yaml
        
        echo "📦 Aplicando en k3s: $TOOL..."
        kubectl apply -f k8s-generated/$TOOL.yaml
    done
}


# Desplegar oleadas en orden
echo "🚀 Desplegando Microservicios en Oleadas..."

deploy_wave "${WAVE_1[@]}"
sleep 20

deploy_wave "${WAVE_2[@]}"
sleep 15

deploy_wave "${WAVE_3[@]}"
deploy_wave "${WAVE_4[@]}"
deploy_monitoring "${WAVE_5[@]}"


# Ahora los nombres son los "reales" que espera Spring Cloud
MICROSERVICIOS=(
    "admin-server"
    "api-gateway"
    "config-server"
    "customers-service"
    "discovery-server"
    "genai-service"
    "vets-service"
    "visits-service"
)


echo "---"
echo "✅ Proceso completado. Los microservicios ahora se ven por sus nombres reales."