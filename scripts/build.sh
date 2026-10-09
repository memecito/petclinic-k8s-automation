#!/bin/bash

DOCKER_VERSION="0.0.1"
MAVEN_VERSION="3.4.1"
REGISTRY="localhost:5000"
IP_VM=$(hostname -I | awk '{print $1}')

cd /home/vagrant/app/

MICROSERVICIOS=(
  "spring-petclinic-admin-server"
  "spring-petclinic-api-gateway"
  "spring-petclinic-config-server"
  "spring-petclinic-customers-service"
  "spring-petclinic-discovery-server"
  "spring-petclinic-genai-service"
  "spring-petclinic-vets-service"
  "spring-petclinic-visits-service"
)

for SERVICE in "${MICROSERVICIOS[@]}"
do
    echo "--------------------------------------------"
    echo "🏗️  Procesando: $SERVICE"
    
    # 1. Asignación de Puertos
    case $SERVICE in
        "spring-petclinic-config-server") export CONTAINER_PORT=8888 ;;
        "spring-petclinic-discovery-server") export CONTAINER_PORT=8761 ;;
        "spring-petclinic-admin-server") export CONTAINER_PORT=9090 ;;
        "spring-petclinic-customers-service") export CONTAINER_PORT=8081 ;;
        "spring-petclinic-visits-service") export CONTAINER_PORT=8082 ;;
        "spring-petclinic-vets-service") export CONTAINER_PORT=8083 ;;
        "spring-petclinic-genai-service") export CONTAINER_PORT=8084 ;;
        *) export CONTAINER_PORT=8080 ;;
    esac

    JAR_NAME="$SERVICE-$MAVEN_VERSION"
    # IMPORTANTE: Definimos el nombre con el registro incluido
    FULL_IMAGE_NAME="$IP_VM:5000/$SERVICE:$DOCKER_VERSION"
    # 2. Construcción (Eliminamos --cpus para evitar el error 'unknown flag')
    echo "📦 Construyendo imagen: $FULL_IMAGE_NAME"
    docker build --no-cache -f ./docker/Dockerfile \
      --build-arg ARTIFACT_NAME=target/$JAR_NAME \
      --build-arg EXPOSED_PORT=$CONTAINER_PORT \
      -t $FULL_IMAGE_NAME ./$SERVICE

    # 3. Subida inmediata al registro
    echo "🚀 Subiendo a registro local..."
    docker push $FULL_IMAGE_NAME

    # 4. Limpieza de imagen local para ahorrar RAM/Disco
    docker rmi $FULL_IMAGE_NAME
    sync
done

# --- Grafana y Prometheus ---
echo "📊 Construyendo herramientas de monitoreo..."

for EXTRA in "grafana" "prometheus"
do
    FULL_EXTRA_NAME="$REGISTRY/$EXTRA:$DOCKER_VERSION"
    echo "🏗️  Construyendo: $FULL_EXTRA_NAME"
    
    docker build -f ./docker/$EXTRA/Dockerfile -t $FULL_EXTRA_NAME ./docker/$EXTRA/
    docker push $FULL_EXTRA_NAME
    docker rmi $FULL_EXTRA_NAME
done

echo "🧹 Limpieza final..."
docker image prune -f
echo "🧹 Limpieza de sistema..."
docker system prune -f
echo "🏁 Proceso completado exitosamente."
echo "$IP_VM"