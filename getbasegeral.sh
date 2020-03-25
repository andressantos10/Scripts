#!/bin/bash

DATA=`date +%Y%m%d`
DATA_START_WEEK=`date +'%Y-%m-%d'`
DATA_END_WEEK=`date --date="$(date +%Y-%m-%d) -1 week" +'%Y-%m-%d'`
#DATA=20190814
FULLPATH="/var/Serasa/monitores/monitorBaseGeral/logs/BaseGeral_${DATA}.csv"
WEEK=

cd /coletas/data-finger-batch/

if [ -f getbasegeral.lock ]
then
  echo "Em execução..."
  exit 10
fi

touch getbasegeral.lock

#copiando do servidor de batch
#scp -q ambweb@spobrpcdlog1:/opt/logs/docroot/DomA/monitores/spobreidbatch/monitorBaseGeral/logs/BaseGeral_20191007.csv BaseGeral_20191007.csv
scp -q  userbatch@spobreidbatch:$FULLPATH .

#java -jar data-finger-batch.jar BASEGERAL 2019-08-19 2019-08-31 > data-finger-batch.log
#java -jar data-finger-batch.jar BASEGERAL $DATA_END_WEEK $DATA_START_WEEK > data-finger-batch-${DATA_START_WEEK}_to_${DATA_END_WEEK}.log
java -jar data-finger-batch.jar > logs/data-finger-batch-${DATA}${WEEK}.log

tar -czf data-finger-batch-coletas-${DATA}${WEEK}.tar coletas/
#ssh ambweb@spobrpcdlog1 -q "rm -f /opt/logs/biometrics/coletas/data-finger-batch-coletas-*.tar"
scp data-finger-batch-coletas-${DATA}${WEEK}.tar ambweb@spobrpcdlog1:/opt/logs/biometrics/coletas/
if [ $? -eq 0 ]
then
  rm data-finger-batch-coletas-${DATA}${WEEK}.tar
fi
rm -rf coletas/

#tar -czf data-finger-batch-blacklist-${DATA}.tar blacklist/
#scp data-finger-batch-blacklist-${DATA}.tar ambweb@spobrpcdlog1:/opt/logs/biometrics/coletas/
rm -rf blacklist/

#gzip data-finger-batch-${DATA}${WEEK}.log
#scp data-finger-batch-${DATA}${WEEK}.log.gz ambweb@spobrpcdlog1:/opt/logs/biometrics/logs/

gzip report-*.csv
scp report-*.csv.gz ambweb@spobrpcdlog1:/opt/logs/biometrics/reports/
rm report-*.csv.gz

#rm BaseGeral_${DATA}.csv
rm getbasegeral.lock
