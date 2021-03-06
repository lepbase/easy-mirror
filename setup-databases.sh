#!/bin/bash

# check script was called correctly
INI=$1
if [ -z $INI ]; then
  echo "Usage: './setup-databases.sh <filename.ini>'\n";
  exit 1
fi

# set database users and passwords from ini file
DB_ROOT_USER=$(awk -F "=" '/DB_ROOT_USER/ {print $2}' $INI | tr -d ' ')
DB_ROOT_PASSWORD=$(awk -F "=" '/DB_ROOT_PASSWORD/ {print $2}' $INI | tr -d ' ')
DB_HOST=$(awk -F "=" '/DB_HOST/ {print $2}' $INI | tr -d ' ')
DB_PORT=$(awk -F "=" '/DB_PORT/ {print $2}' $INI | tr -d ' ')
DB_USER=$(awk -F "=" '/DB_USER/ {print $2}' $INI | tr -d ' ')
DB_PASS=$(awk -F "=" '/DB_PASS/ {print $2}' $INI | tr -d ' ')
DB_SESSION_USER=$(awk -F "=" '/DB_SESSION_USER/ {print $2}' $INI | tr -d ' ')
DB_SESSION_PASS=$(awk -F "=" '/DB_SESSION_PASS/ {print $2}' $INI | tr -d ' ')
DB_IMPORT_USER=$(awk -F "=" '/DB_IMPORT_USER/ {print $2}' $INI | tr -d ' ')
DB_IMPORT_PASS=$(awk -F "=" '/DB_IMPORT_PASS/ {print $2}' $INI | tr -d ' ')

ROOT_CONNECT="mysql -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -P$DB_PORT"
IMPORT_CONNECT="mysqlimport -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -P$DB_PORT"

# test whether we can connect and throw error if not
$ROOT_CONNECT -e "" &> /dev/null;
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
if [ -z $DB_SESSION_USER  ]; then
  printf "ERROR: No DB_SESSION_USER specified.\n       Unable to create ensembl_session/ensembl_accounts database\n"
  exit 1;
fi
if ! [ -z $DB_IMPORT_USER ]; then
  IMPORT_USER_CREATE="GRANT ALL ON *.* TO '$DB_IMPORT_USER'@'$ENSEMBL_WEBSITE_HOST' IDENTIFIED BY '$DB_IMPORT_PASS';"
fi
SESSION_USER_CREATE="GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON ensembl_accounts.* TO '$DB_SESSION_USER'@'$ENSEMBL_WEBSITE_HOST' IDENTIFIED BY '$DB_SESSION_PASS';"
SESSION_USER_CREATE="$SESSION_USER_CREATE GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON ensembl_session.* TO '$DB_SESSION_USER'@'$ENSEMBL_WEBSITE_HOST';"
if ! [ -z $DB_USER  ]; then
  DB_USER_CREATE="GRANT SELECT ON *.* TO '$DB_USER'@'$ENSEMBL_WEBSITE_HOST'"
  if ! [ -z $DB_PASS ]; then
    DB_USER_CREATE="$DB_USER_CREATE IDENTIFIED BY '$DB_PASS'"
  fi
  DB_USER_CREATE="$DB_USER_CREATE;"
fi
$ROOT_CONNECT -e "$IMPORT_USER_CREATE$SESSION_USER_CREATE$DB_USER_CREATE"

function load_db(){
  #load_db <remote_url> <db_name> [overwrite_flag]

  URL_EXISTS=1
  echo Working on $1/$2

  if [ -z $3 ]; then
    # don't overwrite database if it already exists
    $ROOT_CONNECT -e "USE $2" &> /dev/null
    if [ $? -eq 0 ]; then
      echo "  $2 exists, not overwriting"
      return
    fi
  fi

  # test whether database dump exists at DB_URL
  wget -q --spider $1/$2/$2.sql.gz
  if ! [ $? -eq 0 ]; then
    URL_EXISTS=
    echo "  no dump available"
    return
  fi

  # create local database
  $ROOT_CONNECT -e "DROP DATABASE IF EXISTS $2; CREATE DATABASE $2;"

  # fetch and unzip sql/data
  PROTOCOL="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  URL="$(echo ${1/$PROTOCOL/})"
  wget -q -r $1/$2
  mv $URL/* ./
  gunzip $2/*sql.gz

  # load sql into database
  $ROOT_CONNECT $2 < $2/$2.sql

  # load data into database
  for ZIPPED_FILE in $2/*.txt.gz
  do
    gunzip $ZIPPED_FILE
    FILE=${ZIPPED_FILE%.*}
    $IMPORT_CONNECT --fields_escaped_by=\\\\ $2 -L $FILE
    rm $FILE
  done

  # remove remaining downloaded data
  rm -r $2
}

# move to /tmp while downloading files
CURRENTDIR=`pwd`
cd /tmp

# fetch and load ensembl website databases
ENSEMBL_DB_REPLACE=$(awk -F "=" '/ENSEMBL_DB_REPLACE/ {print $2}' $CURRENTDIR/$INI | tr -d ' ')
ENSEMBL_DB_URL=$(awk -F "=" '/ENSEMBL_DB_URL/ {print $2}' $CURRENTDIR/$INI | tr -d ' ')
ENSEMBL_DBS=$(perl -lne '$s.=$_;END{if ($s=~m/ENSEMBL_DBS\s*=\s*\[\s*(.+?)\s*\]/){print $1}}' $CURRENTDIR/$INI)
if ! [ -z $ENSEMBL_DB_URL ]; then
  for DB in $ENSEMBL_DBS
  do
    load_db $ENSEMBL_DB_URL $DB $ENSEMBL_DB_REPLACE
    if [ -z $URL_EXISTS ]; then
      echo "ERROR: Unable to find database dump at $ENSEMBL_DB_URL/$DB"
    fi
  done
fi

# fetch and load EnsemblGenomes databases
EG_DB_REPLACE=$(awk -F "=" '/EG_DB_REPLACE/ {print $2}' $CURRENTDIR/$INI | tr -d ' ')
EG_DB_URL=$(awk -F "=" '/EG_DB_URL/ {print $2}' $CURRENTDIR/$INI | tr -d ' ')
EG_DBS=$(perl -lne '$s.=$_;END{if ($s=~m/EG_DBS\s*=\s*\[\s*(.+?)\s*\]/){print $1}}' $CURRENTDIR/$INI)
if ! [ -z $EG_DB_URL ]; then
  for DB in $EG_DBS
  do
    load_db $EG_DB_URL $DB $EG_DB_REPLACE
    if [ -z $URL_EXISTS ]; then
      echo "ERROR: Unable to find database dump at $EG_DB_URL/$DB"
    fi
  done
fi

# fetch and load species databases
SPECIES_DB_REPLACE=$(awk -F "=" '/SPECIES_DB_REPLACE/ {print $2}' $CURRENTDIR/$INI | tr -d ' ')
SPECIES_DB_AUTO_EXPAND=$(awk -F "=" '/SPECIES_DB_AUTO_EXPAND/ {print $2}' $CURRENTDIR/$INI | tr -d '[' | tr -d ']')
SPECIES_DB_URL=$(awk -F "=" '/SPECIES_DB_URL/ {print $2}' $CURRENTDIR/$INI | tr -d ' ')
SPECIES_DBS=$(perl -lne '$s.=$_;END{if ($s=~m/SPECIES_DBS\s*=\s*\[\s*(.+?)\s*\]/){print $1}}' $CURRENTDIR/$INI)
if ! [ -z $SPECIES_DB_URL ]; then
  for DB in $SPECIES_DBS
  do
    load_db $SPECIES_DB_URL $DB $SPECIES_DB_REPLACE
    if [ -z $URL_EXISTS ]; then
      echo "ERROR: Unable to find database dump at $SPECIES_DB_URL/$DB"
    fi
    if ! [ -z "$SPECIES_DB_AUTO_EXPAND" ]; then
      # auto-expand core with DB types in list
      for DB_TYPE in $SPECIES_DB_AUTO_EXPAND
      do
        NEW_DB=${DB/_core_/_${DB_TYPE}_}
        # attempt to fetch and load db
        load_db $SPECIES_DB_URL $NEW_DB $SPECIES_DB_REPLACE
      done
    fi
  done
fi

# fetch and load any other databases
MISC_DB_REPLACE=$(awk -F "=" '/MISC_DB_REPLACE/ {print $2}' $CURRENTDIR/$INI | tr -d ' ')
MISC_DB_URL=$(awk -F "=" '/MISC_DB_URL/ {print $2}' $CURRENTDIR/$INI | tr -d ' ')
MISC_DBS=$(awk -F "=" '/MISC_DBS/ {print $2}' $CURRENTDIR/$INI | tr -d '[' | tr -d ']')
MISC_DBS=$(perl -lne '$s.=$_;END{if ($s=~m/MISC_DBS\s*=\s*\[\s*(.+?)\s*\]/){print $1}}' $CURRENTDIR/$INI)
if ! [ -z $MISC_DB_URL ]; then
  for DB in $MISC_DBS
  do
    load_db $MISC_DB_URL $DB $MISC_DB_REPLACE
    if [ -z $URL_EXISTS ]; then
      echo "ERROR: Unable to find database dump at $MISC_DB_URL/$DB"
    fi
  done
fi

cd $CURRENTDIR
