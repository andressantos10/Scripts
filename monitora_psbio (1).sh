#!/bin/bash

DATA=`date +%Y%m%d`

RESPONSE=$(curl --request POST -k -s https://psbio.griaulebiometrics.com/gbs-psbio-server/service/directory --key /home/griaule/scripts/monitora_psbio/spobravpbio_key.pem --cert /home/griaule/scripts/monitora_psbio/spobravpbio_cert.pem)

echo $RESPONSE | grep -q "Unsupported Media Type"

if [ $? -ne 0 ]
then
  #sistema indisponível
  #curl "http://spobrmon02:4001/CertAVPBio?griaulebiometrics:Status=0"
  #echo "sistema indisponível"
  echo "`date`;psbio.griaulebiometrics.com indisponível" >> /home/griaule/scripts/monitora_psbio/logs/monitora_psbio-$DATA.log
else
  #sistema disponível
  #curl "http://spobrmon02:4001/CertAVPBio?griaulebiometrics:Status=1"
  #echo "sistema disponível"
  echo "`date`;psbio.griaulebiometrics.com disponível" >> /home/griaule/scripts/monitora_psbio/logs/monitora_psbio-$DATA.log
fi

