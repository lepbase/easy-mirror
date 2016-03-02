#!/bin/bash

# check script was called correctly
INI=$1
if [ -z $INI ]; then
  echo "Usage: './setup-databases.sh <filename.ini>'\n";
  exit 1
fi

# install mysql-server
apt-get -y install mysql-server mysql-common mysql-client

# set database port, user and password variables from ini file
DB_ROOT_PASSWORD=$(awk -F "=" '/DB_ROOT_PASSWORD/ {print $2}' $INI | tr -d ' ')
DB_PORT=$(awk -F "=" '/DB_PORT/ {print $2}' $INI | tr -d ' ')
DB_USER=$(awk -F "=" '/DB_USER/ {print $2}' $INI | tr -d ' ')
DB_PASS=$(awk -F "=" '/DB_PASS/ {print $2}' $INI | tr -d ' ')
DB_WEBSITE_USER=$(awk -F "=" '/DB_WEBSITE_USER/ {print $2}' $INI | tr -d ' ')
DB_WEBSITE_PASS=$(awk -F "=" '/DB_WEBSITE_PASS/ {print $2}' $INI | tr -d ' ')
DB_SESSION_USER=$(awk -F "=" '/DB_SESSION_USER/ {print $2}' $INI | tr -d ' ')
DB_SESSION_PASS=$(awk -F "=" '/DB_SESSION_PASS/ {print $2}' $INI | tr -d ' ')

ROOT_CONNECT="mysql -uroot -p$DB_ROOT_PASSWORD -P$DB_PORT"

# if DB_PORT is not 3306 test whether we can connect and throw error if not
if ! [ $? -eq 0 ]; then
    echo "ERROR: unable to connect to mysql server"
    exit 1;
fi

# set website host variable to determine where the db will be accessed from
ENSEMBL_WEBSITE_HOST=$(awk -F "=" '/ENSEMBL_WEBSITE_HOST/ {print $2}' $INI | tr -d ' ')
if [ -z $ENSEMBL_WEBSITE_HOST ]; then
  # no host set, assume access allowed from anywhere
  ENSEMBL_WEBSITE_HOST=%
fi

# create database users and grant privileges
SESSION_USER_CREATE="GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON ensembl_accounts.* TO '$DB_SESSION_USER'@'$ENSEMBL_WEBSITE_HOST' IDENTIFIED BY '$DB_SESSION_PASS';"
SESSION_USER_CREATE="$SESSION_USER_CREATE GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON ensembl_session.* TO '$DB_SESSION_USER'@'$ENSEMBL_WEBSITE_HOST';"
DB_USER_CREATE="GRANT SELECT ON *.* TO '$DB_USER'@'$ENSEMBL_WEBSITE_HOST'"
if ! [ -z $DB_PASS ]; then
  DB_USER_CREATE="$DB_USER_CREATE IDENTIFIED BY '$DB_PASS'"
fi
DB_USER_CREATE="$DB_USER_CREATE;"
if ! [ -z $DB_WEBSITE_USER  ]; then
  WEBSITE_USER_CREATE="GRANT SELECT ON \`ensembl\\_%\`.* TO '$DB_WEBSITE_USER'@'$ENSEMBL_WEBSITE_HOST'"
  if ! [ -z $DB_WEBSITE_PASS ]; then
    WEBSITE_USER_CREATE="$WEBSITE_USER_CREATE IDENTIFIED BY '$DB_WEBSITE_PASS'"
  fi
  WEBSITE_USER_CREATE="$WEBSITE_USER_CREATE;"
fi
$ROOT_CONNECT -e "$SESSION_USER_CREATE$DB_USER_CREATE$WEBSITE_USER_CREATE"

# fetch and load ensembl website databases
ENSEMBL_DB_URL=$(awk -F "=" '/ENSEMBL_DB_URL/ {print $2}' $INI | tr -d ' ')
ENSEMBL_DBS=$(awk -F "=" '/ENSEMBL_DBS/ {print $2}' $INI | tr -d '[' | tr -d ']')
if ! [ -z $ENSEMBL_DB_URL ]; then
  CURRENTDIR=`pwd`
  cd /tmp
  for DB in $ENSEMBL_DBS
  do
    # create local database
    $ROOT_CONNECT -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB;"

    # fetch and unzip sql
    PROTOCOL="$(echo $ENSEMBL_DB_URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    URL="$(echo ${ENSEMBL_DB_URL/$PROTOCOL/})"
    wget -r $ENSEMBL_DB_URL/$DB
    mv $URL/* ./
    rm -r $URL*
    gunzip $DB/*.gz

    # load sql into database

  done
  cd $CURRENTDIR
fi

# ! todo fetch and load databases from remote urls
#  ENSEMBL_DB_URL = ftp://ftp.ensembl.org/pub/current_mysql/
#  ENSEMBL_DBS = [ ensembl_accounts ensembl_archive_83 ensembl_website_83 ]

#  SPECIES_DB_URL = ftp://ftp.ensembl.org/pub/current_mysql/
#  SPECIES_DBS = [ homo_sapiens_core_83_38 mus_musculus_core_83_38 ]
