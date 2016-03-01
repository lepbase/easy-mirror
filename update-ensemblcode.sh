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
  EG_DIVISION=$(awk -F "=" '/EG_DIVISION/ {print $2}' $INI | tr -d ' ')
  git_update $LOCALDIR/eg-web-common $EG_REPO/eg-web-common.git $EG_BRANCH
  git_update $LOCALDIR/ensemblgenomes-api $EG_REPO/ensemblgenomes-api.git $EG_BRANCH
  git_update $LOCALDIR/eg-web-search $EG_REPO/eg-web-search.git $EG_BRANCH
  git_update $LOCALDIR/eg-web-metazoa $EG_REPO/$EG_DIVISION.git $EG_BRANCH
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
cp $LOCALDIR/ensembl-webcode/conf/Plugins.pm-dist $LOCALDIR/ensembl-webcode/conf/Plugins.pm
HTTP_PORT=$(awk -F "=" '/HTTP_PORT/ {print $2}' $INI | tr -d ' ')
DEBUG_JS="  \\\$SiteDefs::ENSEMBL_DEBUG_JS = 1;"
DEBUG_CSS="  \\\$SiteDefs::ENSEMBL_DEBUG_CSS = 1;"
DEBUG_IMAGES="  \\\$SiteDefs::ENSEMBL_DEBUG_IMAGES = 1;"
SKIP_RSS="  \\\$SiteDefs::ENSEMBL_SKIP_RSS = 1;"
APACHE_DIR="  \\\$SiteDefs::APACHE_DIR   = '\/usr\/local\/apache2';"
APACHE_BIN="  \\\$SiteDefs::APACHE_BIN   = '\/usr\/local\/apache2\/bin\/httpd';"
perl -p -i -e "s/.*\\\$SiteDefs::ENSEMBL_PORT.*/  \\\$SiteDefs::ENSEMBL_PORT = $HTTP_PORT;\n$DEBUG_JS\n$DEBUG_CSS\n$DEBUG_IMAGES\n$SKIP_RSS\n$APACHE_BIN\n$APACHE_DIR/" $LOCALDIR/public-plugins/mirror/conf/SiteDefs.pm

printf "[DATABASES]\n  DATABASE_SESSION = ensembl_session\n  DATABASE_ACCOUNTS = ensembl_accounts\n  DATABASE_ARCHIVE = ensembl_archive\n  DATABASE_WEBSITE = ensembl_website\n" > $LOCALDIR/public-plugins/mirror/conf/ini-files/MULTI.ini

DB_SESSION_HOST=$(awk -F "=" '/DB_SESSION_HOST/ {print $2}' $INI | tr -d ' ')
DB_SESSION_PORT=$(awk -F "=" '/DB_SESSION_PORT/ {print $2}' $INI | tr -d ' ')
DB_SESSION_USER=$(awk -F "=" '/DB_SESSION_USER/ {print $2}' $INI | tr -d ' ')
DB_SESSION_PASS=$(awk -F "=" '/DB_SESSION_PASS/ {print $2}' $INI | tr -d ' ')
printf "[DATABASE_SESSION]\n  USER = $DB_SESSION_USER \n  HOST = $DB_SESSION_HOST\n  PORT = $DB_SESSION_PORT\n  PASS = $DB_SESSION_PASS\n" >> $LOCALDIR/public-plugins/mirror/conf/ini-files/MULTI.ini
printf "[DATABASE_ACCOUNTS]\n  USER = $DB_SESSION_USER \n  HOST = $DB_SESSION_HOST\n  PORT = $DB_SESSION_PORT\n  PASS = $DB_SESSION_PASS\n" >> $LOCALDIR/public-plugins/mirror/conf/ini-files/MULTI.ini

DB_ARCHIVE_HOST=$(awk -F "=" '/DB_ARCHIVE_HOST/ {print $2}' $INI | tr -d ' ')
DB_ARCHIVE_PORT=$(awk -F "=" '/DB_ARCHIVE_PORT/ {print $2}' $INI | tr -d ' ')
DB_ARCHIVE_USER=$(awk -F "=" '/DB_ARCHIVE_USER/ {print $2}' $INI | tr -d ' ')
DB_ARCHIVE_PASS=$(awk -F "=" '/RDB_ARCHIVE_PASS/ {print $2}' $INI | tr -d ' ')
printf "[DATABASE_ARCHIVE]\n  USER = $DB_ARCHIVE_USER \n  HOST = $DB_ARCHIVE_HOST\n  PORT = $DB_ARCHIVE_PORT\n  PASS = $DB_ARCHIVE_PASS\n" >> $LOCALDIR/public-plugins/mirror/conf/ini-files/MULTI.ini
printf "[DATABASE_WEBSITE]\n  USER = $DB_ARCHIVE_USER \n  HOST = $DB_ARCHIVE_HOST\n  PORT = $DB_ARCHIVE_PORT\n  PASS = $DB_ARCHIVE_PASS\n" >> $LOCALDIR/public-plugins/mirror/conf/ini-files/MULTI.ini


DB_HOST=$(awk -F "=" '/DB_HOST/ {print $2}' $INI | tr -d ' ')
DB_PORT=$(awk -F "=" '/DB_PORT/ {print $2}' $INI | tr -d ' ')
DB_USER=$(awk -F "=" '/DB_USER/ {print $2}' $INI | tr -d ' ')
DB_PASS=$(awk -F "=" '/DB_PASS/ {print $2}' $INI | tr -d ' ')
perl -p -i -e "s/^\s*DATABASE_HOST\s*=.*/DATABASE_HOST = $DB_HOST/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_HOST_PORT\s*=.*/DATABASE_HOST_PORT = $DB_PORT/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_WRITE_USER\s*=.*/DATABASE_WRITE_USER = $DB_SESSION_USER/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_WRITE_PASS\s*=.*/DATABASE_WRITE_PASS = $DB_SESSION_PASS/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_DBUSER\s*=.*/DATABASE_DBUSER = $DB_USER/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_DBPASS\s*=.*/DATABASE_DBPASS = $DB_PASS/" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini

perl -p -i -e "s/^.GRAPHIC_TTF_PATH.*=.*/GRAPHIC_TTF_PATH = \/usr\/share\/fonts\/truetype\/msttcorefonts\//" $LOCALDIR/public-plugins/mirror/conf/ini-files/DEFAULTS.ini

perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $LOCALDIR/ensembl-webcode/modules/EnsEMBL/Web/Apache/Handlers.pm;

perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $LOCALDIR/eg-web-common/modules/EnsEMBL/Web/Apache/Handlers.pm;

perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $LOCALDIR/ensembl-webcode/modules/EnsEMBL/Web/CDBI.pm;

perl -0777 -p -i -e 's/while \(my \@T = caller.+?\s}/\# Removed caller /sg' $LOCALDIR/ensembl-webcode/modules/EnsEMBL/Web/SpeciesDefs.pm

# add plugins if this is an ensemblgenomes site
if ! [ -z $EG_DIVISION ]; then
  EG_DIVISION_NAME=`echo $EG_DIVISION | cut -d"-" -f 3`
  EG_DIVISION_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${EG_DIVISION_NAME:0:1})${EG_DIVISION_NAME:1}"
  EG_DIVISION_PLUGIN="  'EG::$EG_DIVISION_NAME' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/$EG_DIVISION',"
  EG_API_PLUGIN="  'EG::API' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/ensemblgenomes-api',"
  EG_COMMON_PLUGIN="  'EG::Common' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/eg-web-common',"
  perl -p -i -e "s/(.*EnsEMBL::Mirror.*)/\$1\n$EG_DIVISION_PLUGIN\n$EG_API_PLUGIN\n$EG_COMMON_PLUGIN/" $LOCALDIR/ensembl-webcode/conf/Plugins.pm;
fi
