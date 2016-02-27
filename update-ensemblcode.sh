#!/bin/bash

INI=$1

function usage(){
  echo "Usage: './update-ensemblcode.sh <filename.ini> </path/to/install>'\n";
}

if [ -z $2 ]; then
  usage
  exit 1
fi

function git_update(){
  # git_update <name-of-local-folder> <repository-on-remote-host> <branch>

  # clone repository if not exist
  if [ ! -d $1 ]; then
    mkdir $1
    echo "git clone -b $3 $2 $1"
    git clone -b $3 $2 $1
  fi

  # pull changes from appropriate branch
  cd $1
  git fetch origin $3
  git reset --hard origin/$3
  cd $CWD
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
   LOCALDIR=$2 # absolute path
else
   LOCALDIR=$CWD/$2 # relative path
fi

# create directories if not exist
if [ ! -d $LOCALDIR ]; then
  mkdir "$LOCALDIR"
else
  # stop server if running
  $LOCALDIR/ensembl-webcode/ctrl_scripts/stop_server
fi

# link to apache in ensembl directory
ln -s /usr/local/apache2 $LOCALDIR/

# call git update for each Ensembl repository:
ENSEMBL_REPO=$(awk -F "=" '/ENSEMBL_REPO/ {print $2}' $INI | tr -d ' ')
ENSEMBL_BRANCH=$(awk -F "=" '/ENSEMBL_BRANCH/ {print $2}' $INI | tr -d ' ')
git_update $LOCALDIR/ensembl $ENSEMBL_REPO/ensembl.git $ENSEMBL_BRANCH
git_update $LOCALDIR/ensembl-compara $ENSEMBL_REPO/ensembl-compara.git $ENSEMBL_BRANCH
git_update $LOCALDIR/ensembl-funcgen $ENSEMBL_REPO/ensembl-funcgen.git $ENSEMBL_BRANCH
git_update $LOCALDIR/ensembl-orm $ENSEMBL_REPO/ensembl-orm.git $ENSEMBL_BRANCH
git_update $LOCALDIR/ensembl-variation $ENSEMBL_REPO/ensembl-variation.git $ENSEMBL_BRANCH
git_update $LOCALDIR/ensembl-webcode $ENSEMBL_REPO/ensembl-webcode.git $ENSEMBL_BRANCH
git_update $LOCALDIR/ensembl-io $ENSEMBL_REPO/ensembl-io.git $ENSEMBL_BRANCH
git_update $LOCALDIR/public-plugins $ENSEMBL_REPO/public-plugins.git $ENSEMBL_BRANCH

EG_REPO=$(awk -F "=" '/EG_REPO/ {print $2}' $INI | tr -d ' ')
if ! [ -z $EG_REPO ]; then
  # call git update for each EnsemblGenomes repository:
  EG_BRANCH=$(awk -F "=" '/EG_BRANCH/ {print $2}' $INI | tr -d ' ')
  EG_UNIT=$(awk -F "=" '/EG_UNIT/ {print $2}' $INI | tr -d ' ')
  git_update $LOCALDIR/eg-web-common $EG_REPO/eg-web-common.git $EG_BRANCH
  git_update $LOCALDIR/eg-web-search $EG_REPO/eg-web-search.git $EG_BRANCH
  git_update $LOCALDIR/eg-web-metazoa $EG_REPO/$EG_UNIT.git $EG_BRANCH
fi

# call git update for bioperl-live
BIOPERL_REPO=$(awk -F "=" '/BIOPERL_REPO/ {print $2}' $INI | tr -d ' ')
BIOPERL_BRANCH=$(awk -F "=" '/BIOPERL_BRANCH/ {print $2}' $INI | tr -d ' ')
git_update $LOCALDIR/bioperl-live $BIOPERL_REPO/bioperl-live.git $BIOPERL_BRANCH

if [ ! -d $LOCALDIR/logs ]; then
  mkdir "$LOCALDIR/logs"
fi
if [ ! -d $LOCALDIR/tmp ]; then
  mkdir "$LOCALDIR/tmp"
fi

# move some files ready for editing
cp $LOCALDIR/public-plugins/mirror/conf/SiteDefs.pm-dist $LOCALDIR/public-plugins/mirror/conf/SiteDefs.pm
HTTP_PORT=$(awk -F "=" '/HTTP_PORT/ {print $2}' $INI | tr -d ' ')
DEBUG_JS="  \\\$SiteDefs::ENSEMBL_DEBUG_JS = 1;"
DEBUG_CSS="  \\\$SiteDefs::ENSEMBL_DEBUG_CSS = 1;"
DEBUG_IMAGES="  \\\$SiteDefs::ENSEMBL_DEBUG_IMAGES = 1;"
SKIP_RSS="  \\\$SiteDefs::ENSEMBL_SKIP_RSS = 1;"
perl -p -i -e "s/.*\\\$SiteDefs::ENSEMBL_PORT.*/  \\\$SiteDefs::ENSEMBL_PORT = $HTTP_PORT;\n$DEBUG_JS\n$DEBUG_CSS\n$DEBUG_IMAGES\n$SKIP_RSS/" $LOCALDIR/public-plugins/mirror/conf/SiteDefs.pm

DB_SESSION_HOST=$(awk -F "=" '/DB_SESSION_HOST/ {print $2}' $INI | tr -d ' ')
DB_SESSION_PORT=$(awk -F "=" '/DB_SESSION_PORT/ {print $2}' $INI | tr -d ' ')
RW_USER=$(awk -F "=" '/RW_USER/ {print $2}' $INI | tr -d ' ')
RW_PASS=$(awk -F "=" '/RW_PASS/ {print $2}' $INI | tr -d ' ')
printf "[DATABASE_SESSION]\n  USER = $RW_USER \n  HOST = $DB_HOST\n  PORT = $DB_PORT\n  PASS = $RW_PASS" > $LOCALDIR/public-plugins/mirror/conf/ini-files/MULTI.ini

DB_HOST=$(awk -F "=" '/DB_HOST/ {print $2}' $INI | tr -d ' ')
DB_PORT=$(awk -F "=" '/DB_PORT/ {print $2}' $INI | tr -d ' ')
RO_USER=$(awk -F "=" '/RO_USER/ {print $2}' $INI | tr -d ' ')
RO_PASS=$(awk -F "=" '/RO_PASS/ {print $2}' $INI | tr -d ' ')
perl -p -i -e "s/^\s*DATABASE_HOST\s*=.*/DATABASE_HOST = $DB_HOST/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_HOST_PORT\s*=.*/DATABASE_HOST_PORT = $DB_PORT/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_WRITE_USER\s*=.*/DATABASE_WRITE_USER = $RW_USER/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_WRITE_PASS\s*=.*/DATABASE_WRITE_PASS = $RW_PASS/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_DBUSER\s*=.*/DATABASE_DBUSER = $RO_USER/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_DBPASS\s*=.*/DATABASE_DBPASS = $RO_PASS/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini

perl -p -i -e "s/^.GRAPHIC_TTF_PATH.*=.*/GRAPHIC_TTF_PATH = \/usr\/share\/fonts\/truetype\/msttcorefonts\//" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini

perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $LOCALDIR/ensembl-webcode/modules/EnsEMBL/Web/Apache/Handlers.pm;

perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $LOCALDIR/eg-web-common/modules/EnsEMBL/Web/Apache/Handlers.pm;

perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $LOCALDIR/ensembl-webcode/modules/EnsEMBL/Web/CDBI.pm;

perl -0777 -p -i -e 's/while \(my \@T = caller.+?\s}/\# Removed caller /sg' $LOCALDIR/ensembl-webcode/modules/EnsEMBL/Web/SpeciesDefs.pm

# add plugins if this is an ensemblgenomes site
if ! [ -z $EG_UNIT ]; then
  EG_UNIT_NAME=`echo $EG_UNIT | cut -d"-" -f 3`
  EG_UNIT_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${EG_UNIT_NAME:0:1})${EG_UNIT_NAME:1}"
  EG_UNIT_PLUGIN="  'EG::$EG_UNIT_NAME' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/$EG_UNIT',"
  EG_COMMON_PLUGIN="  'EG::Common' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/eg-web-common',"
  echo "s/(.*EnsEMBL::Mirror.*)/\$1\n$EG_UNIT_PLUGIN\n$EG_COMMON_PLUGIN/"
  perl -p -i -e "s/(.*EnsEMBL::Mirror.*)/\$1\n$EG_UNIT_PLUGIN\n$EG_COMMON_PLUGIN/" $LOCALDIR/ensembl-webcode/conf/Plugins.pm;
fi
