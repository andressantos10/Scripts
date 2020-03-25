#!/bin/bash

DATA=`date +%Y%m%d`

RESPONSE=$(curl localhost:8082/gbs-spid-server/service/cluster)

echo $RESPONSE | grep -q "Cluster Proxy is running"

if [ $? -ne 0 ]
then
  #cluster indisponível
  #curl "curl localhost:8082/gbs-spid-server/service/cluster:Status=0"
  echo "cluster indisponível"
  echo "`date`;:8082/gbs-spid-server/service/cluster indisponível" >> /home/griaule/scripts/monitora_psbio/logs/monitora_cluster_psbio-$DATA.log
else
  #sistema disponível
  #curl "http://spobrmon02:4001/CertAVPBio?griaulebiometrics:Status=1"
  echo "cluster disponível"
  echo "`date`;:8082/gbs-spid-server/service/cluster disponível" >> /home/griaule/scripts/monitora_psbio/logs/monitora_cluster_psbio-$DATA.log
fi

