#!/bin/bash

INI=$1

function usage(){
  echo "Usage: './reload-ensemblcode.sh <filename.ini> </path/to/install>'\n";
}

# check script was called correctly
if [ -z $2 ]; then
  usage
  exit 1
fi

# set directory names
CWD=$(pwd)
if [[ "$2" = /* ]]
then
   LOCALDIR=$2 # Absolute path
else
   LOCALDIR=$CWD/$2 # Relative path
fi

# stop server
$LOCALDIR/ensembl-webcode/ctrl_scripts/stop_server

if [ -e $LOCALDIR/ensembl-webcode/conf/config.packed ]; then
  rm $LOCALDIR/ensembl-webcode/conf/config.packed
  rm -r $LOCALDIR/ensembl-webcode/conf/packed
fi

if [ ! -d $LOCALDIR/logs ]; then
  mkdir "$LOCALDIR/logs"
fi
if [ ! -d $LOCALDIR/tmp ]; then
  mkdir "$LOCALDIR/tmp"
fi

# start server
$LOCALDIR/ensembl-webcode/ctrl_scripts/start_server

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
      $LOCALDIR/ensembl-webcode/ctrl_scripts/restart_server
    else
      echo "ERROR: failed to start server in 5 attempts."
    fi
  fi
  let COUNT=COUNT+1
done
