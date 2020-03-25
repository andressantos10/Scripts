#!/bin/bash


#DATA=2018-1-31

#BACKUP=`grep coletas/${DATA} /BACKUP/coletas.txt|wc -l`
#ORIGINAL=`find /coletas/coletas/${DATA} | wc -l`

for DATA in `awk -F/ '{print $2}' /BACKUP/coletas.txt  | sort | uniq`
do
  BACKUP=`grep coletas/${DATA} /BACKUP/coletas.txt|wc -l`
  ORIGINAL=`find /coletas/coletas/${DATA} | wc -l`
  if [ $ORIGINAL -eq $BACKUP ]
  then
    echo "Serão excluidos os arquivos da data $DATA! Original=$ORIGINAL e Backup=$BACKUP"
    rm -rf /coletas/coletas/${DATA}
  else
    echo "Não serão excluidos os arquivos da data $DATA! Original=$ORIGINAL e Backup=$BACKUP"
  fi
done
