#!/bin/bash

INI=$1

function usage(){
  echo "Usage: './reload-ensemblcode.sh <filename.ini>'\n";
}

# check script was called correctly
if [ -z $INI ]; then
  usage
  exit 1
fi

# set directory names
CWD=$(pwd)
SERVER_ROOT=$(awk -F "=" '/SERVER_ROOT/ {print $2}' $INI | tr -d ' ')
if [[ "$SERVER_ROOT" = /* ]]
then
   # absolute path, nothing to do
else
   SERVER_ROOT=$CWD/$SERVER_ROOT # relative path
fi

# stop server
$SERVER_ROOT/ensembl-webcode/ctrl_scripts/stop_server

# remove packed config files
if [ -e $SERVER_ROOT/ensembl-webcode/conf/config.packed ]; then
  rm $SERVER_ROOT/ensembl-webcode/conf/config.packed
  rm -r $SERVER_ROOT/ensembl-webcode/conf/packed
fi

# create logs and tmp directories
if [ ! -d $SERVER_ROOT/logs ]; then
  mkdir "$SERVER_ROOT/logs"
fi
if [ ! -d $SERVER_ROOT/tmp ]; then
  mkdir "$SERVER_ROOT/tmp"
fi

# start server
$SERVER_ROOT/ensembl-webcode/ctrl_scripts/start_server

# test whether site is working, restart if not
HTTP_PORT=$(awk -F "=" '/HTTP_PORT/ {print $2}' $INI | tr -d ' ')
COUNT=0
URL=http://localhost:$HTTP_PORT/i/e.png
# ! this only works for EnsemblGenomes
# ! need to use a different test image for Ensembl
while [ $COUNT -lt 5 ]; do
  if curl --output /dev/null --silent --head --fail "$URL"; then
    break
  else
    if [ $COUNT -lt 4 ]; then
      echo "WARNING: unable to resolve URL $URL, restarting server."
      $SERVER_ROOT/ensembl-webcode/ctrl_scripts/restart_server
    else
      echo "ERROR: failed to start server in 5 attempts."
    fi
  fi
  let COUNT=COUNT+1
done
