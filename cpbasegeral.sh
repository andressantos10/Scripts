#!/bin/bash

#DATA=`date --utc +%Y%m`
DATA=`date --date="$(date +%Y-%m-15) -1 month" +'%Y%m'`

cd /coletas/data-finger-batch/

pgrep -F cpbasegeral-pid.file
RETURN=`echo $?`
if [ $RETURN -ne 0 ]
then
  exit 10
fi

pgrep -F getbasegeral-pid.file
RETURN=`echo $?`

tar -czf coletas-${DATA}.tar coletas/
rm -rf coletas/
scp coletas-${DATA}.tar ambweb@spobrpcdlog1:/opt/logs/biometrics/

gzip data-finger-batch-${DATA}.log
scp data-finger-batch-${DATA}.log.gz ambweb@spobrpcdlog1:/opt/logs/biometrics/

rm -f getbasegeral-pid.file
rm -f cpbasegeral-pid.file
