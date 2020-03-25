#!/bin/bash

DATA=`date +%Y%m%d`

RESPONSE=$(curl spobravpbio01:8081/gbscluster-api/rest/services/sc)

echo $RESPONSE | grep -q "{\"status\":\"OK\",\"driver\":\"http://spobravpbio03:6516\",\"brokers\":\[\"http://spobravpbio02:6515\",\"http://spobravpbio01:6515\",\"http://spobravpbio03:6515\"\]}"

if [ $? -ne 0 ]
then
  #cluster indisponível
  #curl "curl localhost:8082/gbs-spid-server/service/cluster:Status=0"
  echo "broker indisponível"
  echo "`date`;spobravpbio01:8081/gbscluster-api/rest/services/sc indisponível" >> /home/griaule/scripts/monitora_psbio/logs/monitora_broker_psbio-$DATA.log
else
  #sistema disponível
  #curl "http://spobrmon02:4001/CertAVPBio?griaulebiometrics:Status=1"
  echo "broker disponível"
  echo "`date`;spobravpbio01:8081/gbscluster-api/rest/services/sc disponível" >> /home/griaule/scripts/monitora_psbio/logs/monitora_broker_psbio-$DATA.log
fi

