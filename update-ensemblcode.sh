#!/bin/bash

# check script was called correctly
INI=$1
if [ -z $INI ]; then
  echo "Usage: './update-ensemblcode.sh <filename.ini>'\n";
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
SERVER_ROOT=$(awk -F "=" '/SERVER_ROOT/ {print $2}' $INI | tr -d ' ')
if [[ "$SERVER_ROOT" = /* ]]
then
   # absolute path, nothing to do
else
   SERVER_ROOT=$CWD/$SERVER_ROOT # relative path
fi

if [ -d $SERVER_ROOT ]; then
  # stop server in case already running
  $SERVER_ROOT/ensembl-webcode/ctrl_scripts/stop_server
fi

# call git update for each Ensembl repository:
ENSEMBL_REPO=$(awk -F "=" '/ENSEMBL_REPO/ {print $2}' $INI | tr -d ' ')
ENSEMBL_BRANCH=$(awk -F "=" '/ENSEMBL_BRANCH/ {print $2}' $INI | tr -d ' ')
git_update $SERVER_ROOT/ensembl $ENSEMBL_REPO/ensembl.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-compara $ENSEMBL_REPO/ensembl-compara.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-funcgen $ENSEMBL_REPO/ensembl-funcgen.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-orm $ENSEMBL_REPO/ensembl-orm.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-variation $ENSEMBL_REPO/ensembl-variation.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-webcode $ENSEMBL_REPO/ensembl-webcode.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-io $ENSEMBL_REPO/ensembl-io.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/public-plugins $ENSEMBL_REPO/public-plugins.git $ENSEMBL_BRANCH

EG_REPO=$(awk -F "=" '/EG_REPO/ {print $2}' $INI | tr -d ' ')
if ! [ -z $EG_REPO ]; then
  # call git update for each EnsemblGenomes repository:
  EG_BRANCH=$(awk -F "=" '/EG_BRANCH/ {print $2}' $INI | tr -d ' ')
  EG_DIVISION=$(awk -F "=" '/EG_DIVISION/ {print $2}' $INI | tr -d ' ')
  git_update $SERVER_ROOT/eg-web-common $EG_REPO/eg-web-common.git $EG_BRANCH
  git_update $SERVER_ROOT/ensemblgenomes-api $EG_REPO/ensemblgenomes-api.git $EG_BRANCH
  git_update $SERVER_ROOT/eg-web-search $EG_REPO/eg-web-search.git $EG_BRANCH
  git_update $SERVER_ROOT/eg-web-metazoa $EG_REPO/$EG_DIVISION.git $EG_BRANCH
fi

# call git update for bioperl-live
BIOPERL_REPO=$(awk -F "=" '/BIOPERL_REPO/ {print $2}' $INI | tr -d ' ')
BIOPERL_BRANCH=$(awk -F "=" '/BIOPERL_BRANCH/ {print $2}' $INI | tr -d ' ')
git_update $SERVER_ROOT/bioperl-live $BIOPERL_REPO/bioperl-live.git $BIOPERL_BRANCH

# create logs and tmp directories
if [ ! -d $SERVER_ROOT/logs ]; then
  mkdir "$SERVER_ROOT/logs"
fi
if [ ! -d $SERVER_ROOT/tmp ]; then
  mkdir "$SERVER_ROOT/tmp"
fi

# move some *-dist files ready for editing
cp $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm-dist $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm
cp $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini-dist $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
cp $SERVER_ROOT/ensembl-webcode/conf/Plugins.pm-dist $SERVER_ROOT/ensembl-webcode/conf/Plugins.pm

# set webserver parameters
HTTP_PORT=$(awk -F "=" '/HTTP_PORT/ {print $2}' $INI | tr -d ' ')
APACHE_DIR="  \\\$SiteDefs::APACHE_DIR   = '\/usr\/local\/apache2';"
APACHE_BIN="  \\\$SiteDefs::APACHE_BIN   = '\/usr\/local\/apache2\/bin\/httpd';"
perl -p -i -e "s/.*\\\$SiteDefs::ENSEMBL_PORT.*/  \\\$SiteDefs::ENSEMBL_PORT = $HTTP_PORT;\n$APACHE_BIN\n$APACHE_DIR/" $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm

# set multi-species database connection parameters
printf "[DATABASES]\n  DATABASE_SESSION = ensembl_session\n  DATABASE_ACCOUNTS = ensembl_accounts\n  DATABASE_ARCHIVE = ensembl_archive\n  DATABASE_WEBSITE = ensembl_website\n" > $SERVER_ROOT/public-plugins/mirror/conf/ini-files/MULTI.ini

DB_SESSION_HOST=$(awk -F "=" '/DB_SESSION_HOST/ {print $2}' $INI | tr -d ' ')
DB_SESSION_PORT=$(awk -F "=" '/DB_SESSION_PORT/ {print $2}' $INI | tr -d ' ')
DB_SESSION_USER=$(awk -F "=" '/DB_SESSION_USER/ {print $2}' $INI | tr -d ' ')
DB_SESSION_PASS=$(awk -F "=" '/DB_SESSION_PASS/ {print $2}' $INI | tr -d ' ')
printf "[DATABASE_SESSION]\n  USER = $DB_SESSION_USER \n  HOST = $DB_SESSION_HOST\n  PORT = $DB_SESSION_PORT\n  PASS = $DB_SESSION_PASS\n" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/MULTI.ini
printf "[DATABASE_ACCOUNTS]\n  USER = $DB_SESSION_USER \n  HOST = $DB_SESSION_HOST\n  PORT = $DB_SESSION_PORT\n  PASS = $DB_SESSION_PASS\n" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/MULTI.ini

DB_WEBSITE_HOST=$(awk -F "=" '/DB_WEBSITE_HOST/ {print $2}' $INI | tr -d ' ')
DB_WEBSITE_PORT=$(awk -F "=" '/DB_WEBSITE_PORT/ {print $2}' $INI | tr -d ' ')
DB_WEBSITE_USER=$(awk -F "=" '/DB_WEBSITE_USER/ {print $2}' $INI | tr -d ' ')
DB_WEBSITE_PASS=$(awk -F "=" '/RDB_WEBSITE_PASS/ {print $2}' $INI | tr -d ' ')
printf "[DATABASE_WEBSITE]\n  USER = $DB_WEBSITE_USER \n  HOST = $DB_WEBSITE_HOST\n  PORT = $DB_WEBSITE_PORT\n  PASS = $DB_WEBSITE_PASS\n" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/MULTI.ini
printf "[DATABASE_WEBSITE]\n  USER = $DB_WEBSITE_USER \n  HOST = $DB_WEBSITE_HOST\n  PORT = $DB_WEBSITE_PORT\n  PASS = $DB_WEBSITE_PASS\n" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/MULTI.ini

perl -p -i -e "s/^\s*DATABASE_WRITE_USER\s*=.*/DATABASE_WRITE_USER = $DB_SESSION_USER/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_WRITE_PASS\s*=.*/DATABASE_WRITE_PASS = $DB_SESSION_PASS/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini

# set species core database connection parameters
DB_HOST=$(awk -F "=" '/DB_HOST/ {print $2}' $INI | tr -d ' ')
DB_PORT=$(awk -F "=" '/DB_PORT/ {print $2}' $INI | tr -d ' ')
DB_USER=$(awk -F "=" '/DB_USER/ {print $2}' $INI | tr -d ' ')
DB_PASS=$(awk -F "=" '/DB_PASS/ {print $2}' $INI | tr -d ' ')
perl -p -i -e "s/^\s*DATABASE_HOST\s*=.*/DATABASE_HOST = $DB_HOST/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_HOST_PORT\s*=.*/DATABASE_HOST_PORT = $DB_PORT/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_DBUSER\s*=.*/DATABASE_DBUSER = $DB_USER/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_DBPASS\s*=.*/DATABASE_DBPASS = $DB_PASS/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini

# set path to Microsoft truetype fonts
perl -p -i -e "s/^.*GRAPHIC_TTF_PATH.*=.*/GRAPHIC_TTF_PATH = \/usr\/share\/fonts\/truetype\/msttcorefonts\//" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini

# ! hack:
# comment out debugging code that is not compatible with Ubuntu/Perl
perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $SERVER_ROOT/ensembl-webcode/modules/EnsEMBL/Web/Apache/Handlers.pm;
perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $SERVER_ROOT/eg-web-common/modules/EnsEMBL/Web/Apache/Handlers.pm;
perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $SERVER_ROOT/ensembl-webcode/modules/EnsEMBL/Web/CDBI.pm;
perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $SERVER_ROOT/ensembl/ensembl/modules/Bio/EnsEMBL/Utils/Exception.pm
perl -0777 -p -i -e 's/while \(my \@T = caller.+?\s}/\# Removed caller /sg' $SERVER_ROOT/ensembl-webcode/modules/EnsEMBL/Web/SpeciesDefs.pm

# add plugins if this is an ensemblgenomes site
if ! [ -z $EG_DIVISION ]; then
  EG_DIVISION_NAME=`echo $EG_DIVISION | cut -d"-" -f 3`
  EG_DIVISION_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${EG_DIVISION_NAME:0:1})${EG_DIVISION_NAME:1}"
  EG_DIVISION_PLUGIN="  'EG::$EG_DIVISION_NAME' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/$EG_DIVISION',"
  EG_API_PLUGIN="  'EG::API' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/ensemblgenomes-api',"
  EG_COMMON_PLUGIN="  'EG::Common' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/eg-web-common',"
  perl -p -i -e "s/(.*EnsEMBL::Mirror.*)/\$1\n$EG_DIVISION_PLUGIN\n$EG_API_PLUGIN\n$EG_COMMON_PLUGIN/" $SERVER_ROOT/ensembl-webcode/conf/Plugins.pm;
fi

# ! todo:
# use SPECIES_CORE_DBS to populate Primary/Secondary species, modify DEFAULTS.ini
# and generate Genus_species.ini files
