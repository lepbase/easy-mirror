#!/bin/bash

INI=$1

function usage(){
  echo "Usage: './setup-databases.sh <filename.ini>'\n";
}

if [ -z $INI ]; then
  usage
  exit 1
fi

# set database host and user variables from ini file
DB_ROOT_PASSWORD=$(awk -F "=" '/DB_ROOT_PASSWORD/ {print $2}' $INI | tr -d ' ')
DB_HOST=$(awk -F "=" '/DB_HOST/ {print $2}' $INI | tr -d ' ')
DB_PORT=$(awk -F "=" '/DB_PORT/ {print $2}' $INI | tr -d ' ')
RW_USER=$(awk -F "=" '/RW_USER/ {print $2}' $INI | tr -d ' ')
RW_PASS=$(awk -F "=" '/RW_PASS/ {print $2}' $INI | tr -d ' ')
RO_USER=$(awk -F "=" '/RO_USER/ {print $2}' $INI | tr -d ' ')
RO_PASS=$(awk -F "=" '/RO_PASS/ {print $2}' $INI | tr -d ' ')

# ! NEED AN ENSEMBL_ACCOUNTS DATABASE

if ! [ -z $DB_ROOT_PASSWORD ]; then
  # we have a root password so assume we need to set up databases and users
  if ! [ $DB_HOST == "localhost" ]; then
    # this machine is a database server
    apt-get -y install mysql-server
  fi

  ROOT_CONNECT="mysql -uroot -p$DB_ROOT_PASSWORD -P$DB_PORT -h$DB_HOST"
  RW_CREATE="CREATE USER '$RW_USER'@'localhost' IDENTIFIED BY '$RW_PASS';"
  if [ -z "$RO_PASS" ]; then
    RO_CREATE="CREATE USER '$RO_USER'@'localhost';"
  else
    RO_CREATE="CREATE USER '$RO_USER'@'localhost' IDENTIFIED BY '$RO_PASS';"
  fi
  $ROOT_CONNECT -e "$RW_CREATE$RO_CREATE"

fi
