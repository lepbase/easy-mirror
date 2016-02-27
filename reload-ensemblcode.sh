#!/bin/bash

function usage(){
  echo "Usage: './reload-ensemblcode.sh </path/to/install>'\n";
}

# check script was called correctly
if [ -z $1 ]; then
  usage
  exit 1
fi

# set directory names
CWD=$(pwd)
if [[ "$1" = /* ]]
then
   LOCALDIR=$1 # Absolute path
else
   LOCALDIR=$CWD/$1 # Relative path
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

# start lepbase
$LOCALDIR/ensembl-webcode/ctrl_scripts/start_server
