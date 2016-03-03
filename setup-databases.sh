#!/bin/bash

# check script was called correctly
INI=$1
if [ -z $INI ]; then
  echo "Usage: './setup-databases.sh <filename.ini>'\n";
  exit 1
fi

# set database port, user and password variables from ini file
DB_ROOT_PASSWORD=$(awk -F "=" '/DB_ROOT_PASSWORD/ {print $2}' $INI | tr -d ' ')
DB_PORT=$(awk -F "=" '/DB_PORT/ {print $2}' $INI | tr -d ' ')
DB_USER=$(awk -F "=" '/DB_USER/ {print $2}' $INI | tr -d ' ')
DB_PASS=$(awk -F "=" '/DB_PASS/ {print $2}' $INI | tr -d ' ')
DB_WEBSITE_USER=$(awk -F "=" '/DB_WEBSITE_USER/ {print $2}' $INI | tr -d ' ')
DB_WEBSITE_PASS=$(awk -F "=" '/DB_WEBSITE_PASS/ {print $2}' $INI | tr -d ' ')
DB_SESSION_USER=$(awk -F "=" '/DB_SESSION_USER/ {print $2}' $INI | tr -d ' ')
DB_SESSION_PASS=$(awk -F "=" '/DB_SESSION_PASS/ {print $2}' $INI | tr -d ' ')

ROOT_CONNECT="mysql -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -P$DB_PORT"
IMPORT_CONNECT="mysqlimport -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -P$DB_PORT"

# test whether we can connect and throw error if not
$ROOT_CONNECT -e "SHOW DATABASES";
if ! [ $? -eq 0 ]; then
    printf "ERROR: Unable to connect to mysql server as root.\n       Check connection settings in $INI\n"
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

# ! todo: move db loading into function
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

    # fetch and unzip sql/data
    PROTOCOL="$(echo $ENSEMBL_DB_URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    URL="$(echo ${ENSEMBL_DB_URL/$PROTOCOL/})"
    wget -r $ENSEMBL_DB_URL/$DB
    mv $URL/* ./
    gunzip $DB/*sql.gz

    # load sql into database
    $ROOT_CONNECT $DB < $DB/$DB.sql

    if [ "$DB" = "ensembl_accounts" ]; then
      # make a copy of ensembl_accounts called ensembl_session to match ensembl default
      $ROOT_CONNECT -e "DROP DATABASE IF EXISTS ensembl_session; CREATE DATABASE ensembl_session;"
      $ROOT_CONNECT ensembl_session < $DB/$DB.sql
    else
      # load data into database one file at a time to reduce disk space used
      for ZIPPED_FILE in $DB/*.txt.gz
      do
        gunzip $ZIPPED_FILE
        FILE=${ZIPPED_FILE%.*}
        $IMPORT_CONNECT --fields_escaped_by=\\\\ $DB -L $FILE
        rm $FILE
      done
    fi

    # remove remaining downloaded data
    rm -r $DB
  done
  cd $CURRENTDIR
fi

# fetch and load species databases
SPECIES_DB_URL=$(awk -F "=" '/SPECIES_DB_URL/ {print $2}' $INI | tr -d ' ')
SPECIES_DBS=$(awk -F "=" '/SPECIES_DBS/ {print $2}' $INI | tr -d '[' | tr -d ']')
if ! [ -z $SPECIES_DB_URL ]; then
  CURRENTDIR=`pwd`
  cd /tmp
  for DB in $SPECIES_DBS
  do
    # create local database
    $ROOT_CONNECT -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB;"

    # fetch and unzip sql/data
    PROTOCOL="$(echo $SPECIES_DB_URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    URL="$(echo ${SPECIES_DB_URL/$PROTOCOL/})"
    wget -r $SPECIES_DB_URL/$DB
    mv $URL/* ./
    gunzip $DB/*sql.gz

    # load sql into database
    $ROOT_CONNECT $DB < $DB/$DB.sql

    # load data into database one file at a time to reduce disk space used
    for ZIPPED_FILE in $DB/*.txt.gz
    do
      gunzip $ZIPPED_FILE
      FILE=${ZIPPED_FILE%.*}
      $IMPORT_CONNECT --fields_escaped_by=\\\\ $DB -L $FILE
      rm $FILE
    done

    # remove remaining downloaded data
    rm -r $DB
  done
  cd $CURRENTDIR
fi

# fetch and load any other databases
MISC_DB_URL=$(awk -F "=" '/MISC_DB_URL/ {print $2}' $INI | tr -d ' ')
MISC_DBS=$(awk -F "=" '/MISC_DBS/ {print $2}' $INI | tr -d '[' | tr -d ']')
if ! [ -z $MISC_DB_URL ]; then
  CURRENTDIR=`pwd`
  cd /tmp
  for DB in $MISC_DBS
  do
    # create local database
    $ROOT_CONNECT -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB;"

    # fetch and unzip sql/data
    PROTOCOL="$(echo $MISC_DB_URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    URL="$(echo ${MISC_DB_URL/$PROTOCOL/})"
    wget -r $MISC_DB_URL/$DB
    mv $URL/* ./
    gunzip $DB/*sql.gz

    # load sql into database
    $ROOT_CONNECT $DB < $DB/$DB.sql

    # load data into database one file at a time to reduce disk space used
    for ZIPPED_FILE in $DB/*.txt.gz
    do
      gunzip $ZIPPED_FILE
      FILE=${ZIPPED_FILE%.*}
      $IMPORT_CONNECT --fields_escaped_by=\\\\ $DB -L $FILE
      rm $FILE
    done

    # remove remaining downloaded data
    rm -r $DB
  done
  cd $CURRENTDIR
fi
