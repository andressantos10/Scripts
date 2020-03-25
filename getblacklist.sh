#!/bin/bash

# Source function library.
. /etc/init.d/functions

#Setup inicial para o ambiente
DIR="$(dirname "$0")"

#TODO - tornar o script indepente do path
cd $DIR

USER="ambweb"
SERVER="spobrpcdlog1"
LOG_PATH="/opt/logs/biometrics"
CPF_PATH="/home/ambweb/httpd/docroot/logs1/blacklist"

function sendtodest(){
  scp $TAR_FILE ${USER}@${SERVER}:${LOG_PATH}
  rm -f $TAR_FILE
}

function getremotecpfs(){
  scp ${USER}@${SERVER}:${CPF_PATH}/${CPFS_FILE} .
  ssh ${USER}@${SERVER} -q "> ${CPF_PATH}/${CPFS_FILE}"
}

function getcpf(){
  if [ ! -f coleta-${DATE}.txt ]
  then
    touch coleta-${DATE}.txt
  fi

  if [ ! -f $TAR_FILE ]
  then
    tar -cvf $TAR_FILE coleta-${DATE}.txt
  fi

  for FILE in $(find /coletas/coletas/2019-*-* -maxdepth 1 -type d -name $CPF)
  do
    tar -rf $TAR_FILE $FILE
  done

  sendtodest
}

function getcpfs(){
  if [ ! -s ${CPFS_FILE} ]
  then
    echo "Arquivo de CPFs aparentemente está vazio"
    exit 15
  fi
  
  if [ ! -f coleta-${DATE}.txt ]
  then
    touch coleta-${DATE}.txt
    echo "CPFs dessa coleta" > coleta-${DATE}.txt
    cat ${CPFS_FILE} >> coleta-${DATE}.txt
  fi

  if [ ! -f $TAR_FILE ]
  then
    tar -cvf $TAR_FILE coleta-${DATE}.txt
  fi
  
  for CPF in $(cat $CPFS_FILE)
  do
    for FILE in $(find /coletas/coletas/2019-*-* -maxdepth 1 -type d -name $CPF)
    do
      tar -rf $TAR_FILE $FILE
    done
  done

  sendtodest
}

function help(){
  echo
  echo "Uso:"
  echo
  echo "Para coletar a biometria com suspeita de blacklist"
  echo "`basename $0` -c <CPF>"
  echo
  echo "Para coletar uma lista de biometrias com suspeita de blacklist"
  echo "`basename $0` -f <nome do arquivo com uma lista de cpfs, um por linha>"
  echo
  echo "Automatiza a coleta"
  echo "`basename $0` -a"
  echo  
  echo "Para exibir esse menu:"
  echo "`basename $0` -h"
  echo
}

case "$1" in
  -c)
    CPF=$2
    DATE=$(date +"%Y-%m-%d-%H-%M")
    TAR_FILE=coleta-blacklist-${CPF}-${DATE}.tar
    getcpf
    ;;
  -f)
    CPFS_FILE=$2
    DATE=$(date +"%Y-%m-%d-%H-%M")
    TAR_FILE=coleta-blacklist-${DATE}.tar
    getcpfs
    ;;
  -a)
    CPFS_FILE=cpfs.txt
    DATE=$(date +"%Y-%m-%d-%H-%M")
    TAR_FILE=coleta-blacklist-${DATE}.tar
    getremotecpfs
    getcpfs
    ;;
  -h)
    help
    ;;
  *)
    help
    exit 0
esac
