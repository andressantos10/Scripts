#!/bin/sh
set -o errexit
set -o nounset

# Kubernetes Namespace to deploy application
K8S_NAMESPACE="fw2"

# Docker Registry
DOCKER_REGISTRY_URL="registry.bry.com.br"
DOCKER_REGISTRY_SECRET="bry-docker-registry-secret"
DOCKER_REGISTRY_USER="registry.serasa"
DOCKER_REGISTRY_PASSWORD="6XdG1JCjf19da4Zm"

# REDIS 
REDIS_HOST="bry-fw2-redis-ha"
REDIS_PORT="26379"
REDIS_SECRET="Cah2cieReehie3p"

setup(){
  echo 
  echo " Setup credencial do docker registry "
  kubectl create secret docker-registry $DOCKER_REGISTRY_SECRET --docker-server=$DOCKER_REGISTRY_URL --docker-username=$DOCKER_REGISTRY_USER --docker-password=$DOCKER_REGISTRY_PASSWORD --docker-email=infra@bry.com.br -n $K8S_NAMESPACE
  echo 
  echo " Setup configmap "
  kubectl apply -f configmap/configmap.yaml --namespace $K8S_NAMESPACE
}

redis(){
  echo
  echo " Instalando e configurando o Helm "
#  ./redis-ha/helm.sh
  echo
  echo " Redis secret "
  kubectl apply -f redis-ha/secret.yaml --namespace $K8S_NAMESPACE
  echo
  echo " Redis deployment "
  helm install stable/redis-ha --name bry-fw2-redis-ha --version 3.1.3 --namespace $K8S_NAMESPACE -f redis-ha/values-chart-3x.yaml --set redisPassword=$REDIS_SECRET
#  helm install stable/redis-ha --name bry-fw2-redis-ha --namespace $K8S_NAMESPACE -f redis-ha/values-chart-3x.yaml --set redisPassword=$REDIS_SECRET
}

monitor(){
  echo
  echo " Setup svc monitor "
  kubectl apply -f service-monitor/service-monitor.yaml --namespace $K8S_NAMESPACE
}

gluster(){
  YAMLS="gluster-endpoint.yml gluster-service.yml"
  for YAML in $YAMLS
  do
    FULLPATH="glusterfs/$YAML"
    if [ -f $FULLPATH ]
    then
      echo " Applying $YAML "
      kubectl apply -f $FULLPATH --namespace $K8S_NAMESPACE
    fi
  done
}

deployment(){
  YAMLS="configmap.yaml secret.yaml deployment.yaml service.yaml ingress.yaml ingress-internal.yaml"
  for YAML in $YAMLS
  do
    FULLPATH="workloads/${WORKLOAD}/$YAML"
    if [ -f $FULLPATH ]
    then
      echo " Applying $YAML "
      kubectl apply -f $FULLPATH --namespace $K8S_NAMESPACE
    fi
  done
}

workloads(){
  for WORKLOAD in $( ls workloads/)
  do
    echo
    echo " $WORKLOAD deployment "
    deployment $WORKLOAD
  done
}

echo " SETUP INICIALIZACAO "
#setup
redis
monitor
gluster
workloads
echo " FINALIZADO "
