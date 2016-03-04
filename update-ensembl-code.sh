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

function db_connection_test(){
  # species_db_fallback <db-name> <host> <port> <user> <pass>
  DB_CONNECT="mysql -h$2 -P$3 -u$4 $1"
  if ! [ -z $5 ]; then
    DB_CONNECT="$DB_CONNECT -p "
  fi
  $DB_CONNECT -e "" &> /dev/null;
  DB_CONNECT_RESULT=$?
}

function species_db_fallback(){
  # species_db_fallback <db-name>
  TEST_HOST=$DB_HOST
  TEST_PORT=$DB_PORT
  TEST_USER=$DB_USER
  TEST_PASS=$DB_PASS
  db_connection_test $1 $TEST_HOST $TEST_PORT $TEST_USER $TEST_PASS
  if ! [ $DB_CONNECT_RESULT -eq 0 ]; then
    if ! [ -z $DB_FALLBACK_HOST ]; then
      TEST_HOST=$DB_FALLBACK_HOST
      TEST_PORT=$DB_FALLBACK_PORT
      TEST_USER=$DB_FALLBACK_USER
      TEST_PASS=$DB_FALLBACK_PASS
      db_connection_test $1 $TEST_HOST $TEST_PORT $TEST_USER $TEST_PASS
      if ! [ $DB_CONNECT_RESULT -eq 0 ]; then
        if ! [ -z $DB_FALLBACK2_HOST ]; then
          TEST_HOST=$DB_FALLBACK2_HOST
          TEST_PORT=$DB_FALLBACK2_PORT
          TEST_USER=$DB_FALLBACK2_USER
          TEST_PASS=$DB_FALLBACK2_PASS
          db_connection_test $1 $TEST_HOST $TEST_PORT $TEST_USER $TEST_PASS
        fi
      fi
    fi
  fi
}

# set directory names
CWD=$(pwd)
SERVER_ROOT=$(awk -F "=" '/SERVER_ROOT/ {print $2}' $INI | tr -d ' ')
if ! [[ "$SERVER_ROOT" = /* ]]; then
  # convert relative path to absolute
  SERVER_ROOT=$CWD/$SERVER_ROOT
fi

if [ -d $SERVER_ROOT ]; then
  # stop server in case already running
  $SERVER_ROOT/ensembl-webcode/ctrl_scripts/stop_server
fi

# call git update for each Ensembl repository:
ENSEMBL_URL=$(awk -F "=" '/ENSEMBL_URL/ {print $2}' $INI | tr -d ' ')
ENSEMBL_BRANCH=$(awk -F "=" '/ENSEMBL_BRANCH/ {print $2}' $INI | tr -d ' ')
git_update $SERVER_ROOT/ensembl $ENSEMBL_URL/ensembl.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-compara $ENSEMBL_URL/ensembl-compara.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-funcgen $ENSEMBL_URL/ensembl-funcgen.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-orm $ENSEMBL_URL/ensembl-orm.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-variation $ENSEMBL_URL/ensembl-variation.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-webcode $ENSEMBL_URL/ensembl-webcode.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/ensembl-io $ENSEMBL_URL/ensembl-io.git $ENSEMBL_BRANCH
git_update $SERVER_ROOT/public-plugins $ENSEMBL_URL/public-plugins.git $ENSEMBL_BRANCH

EG_URL=$(awk -F "=" '/EG_URL/ {print $2}' $INI | tr -d ' ')
if ! [ -z $EG_URL ]; then
  # call git update for each EnsemblGenomes repository:
  EG_BRANCH=$(awk -F "=" '/EG_BRANCH/ {print $2}' $INI | tr -d ' ')
  EG_DIVISION=$(awk -F "=" '/EG_DIVISION/ {print $2}' $INI | tr -d ' ')
  git_update $SERVER_ROOT/eg-web-common $EG_URL/eg-web-common.git $EG_BRANCH
  git_update $SERVER_ROOT/ensemblgenomes-api $EG_URL/ensemblgenomes-api.git $EG_BRANCH
  git_update $SERVER_ROOT/eg-web-search $EG_URL/eg-web-search.git $EG_BRANCH
  git_update $SERVER_ROOT/eg-web-metazoa $EG_URL/$EG_DIVISION.git $EG_BRANCH
fi

# call git update for bioperl-live
BIOPERL_URL=$(awk -F "=" '/BIOPERL_URL/ {print $2}' $INI | tr -d ' ')
BIOPERL_BRANCH=$(awk -F "=" '/BIOPERL_BRANCH/ {print $2}' $INI | tr -d ' ')
git_update $SERVER_ROOT/bioperl-live $BIOPERL_URL/bioperl-live.git $BIOPERL_BRANCH

# create logs and tmp directories
if [ ! -d $SERVER_ROOT/logs ]; then
  mkdir "$SERVER_ROOT/logs"
fi
if [ ! -d $SERVER_ROOT/tmp ]; then
  mkdir "$SERVER_ROOT/tmp"
fi

# move some *-dist files ready for editing
cp $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini-dist $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
cp $SERVER_ROOT/ensembl-webcode/conf/Plugins.pm-dist $SERVER_ROOT/ensembl-webcode/conf/Plugins.pm

# set species core database connection parameters
DB_HOST=$(awk -F "=" '/DB_HOST/ {print $2}' $INI | tr -d ' ')
DB_PORT=$(awk -F "=" '/DB_PORT/ {print $2}' $INI | tr -d ' ')
DB_USER=$(awk -F "=" '/DB_USER/ {print $2}' $INI | tr -d ' ')
DB_PASS=$(awk -F "=" '/DB_PASS/ {print $2}' $INI | tr -d ' ')
perl -p -i -e "s/^\s*DATABASE_HOST\s*=.*/DATABASE_HOST = $DB_HOST/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_HOST_PORT\s*=.*/DATABASE_HOST_PORT = $DB_PORT/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_DBUSER\s*=.*/DATABASE_DBUSER = $DB_USER/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
perl -p -i -e "s/^\s*DATABASE_DBPASS\s*=.*/DATABASE_DBPASS = $DB_PASS/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
#perl -p -i -e "s/^\s*DATABASE_WRITE_USER\s*=.*/DATABASE_WRITE_USER = $DB_SESSION_USER/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini
#perl -p -i -e "s/^\s*DATABASE_WRITE_PASS\s*=.*/DATABASE_WRITE_PASS = $DB_SESSION_PASS/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini

# set path to Microsoft truetype fonts
perl -p -i -e "s/^.*GRAPHIC_TTF_PATH.*=.*/GRAPHIC_TTF_PATH = \/usr\/share\/fonts\/truetype\/msttcorefonts\//" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini

# ! hack:
# comment out debugging code that is not compatible with Ubuntu/Perl
perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $SERVER_ROOT/ensembl-webcode/modules/EnsEMBL/Web/Apache/Handlers.pm;
perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $SERVER_ROOT/ensembl-webcode/modules/EnsEMBL/Web/CDBI.pm;
perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $SERVER_ROOT/ensembl/modules/Bio/EnsEMBL/Utils/Exception.pm
perl -0777 -p -i -e 's/while \( my \@call = caller.+?\s}/\# Removed caller /sg' $SERVER_ROOT/ensembl/modules/Bio/EnsEMBL/Utils/Exception.pm
perl -0777 -p -i -e 's/while \(my \@T = caller.+?\s}/\# Removed caller /sg' $SERVER_ROOT/ensembl-webcode/modules/EnsEMBL/Web/SpeciesDefs.pm
if ! [ -z $EG_DIVISION ]; then
  perl -p -i -e 's/^(\s*.*CACHE_TAGS.*)/#$1/' $SERVER_ROOT/eg-web-common/modules/EnsEMBL/Web/Apache/Handlers.pm;
fi



# add plugins if this is an ensemblgenomes site
if ! [ -z $EG_DIVISION ]; then
  EG_DIVISION_NAME=`echo $EG_DIVISION | cut -d"-" -f 3`
  EG_DIVISION_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${EG_DIVISION_NAME:0:1})${EG_DIVISION_NAME:1}"
  EG_DIVISION_PLUGIN="  'EG::$EG_DIVISION_NAME' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/$EG_DIVISION',"
  EG_API_PLUGIN="  'EG::API' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/ensemblgenomes-api',"
  EG_COMMON_PLUGIN="  'EG::Common' => \\\$SiteDefs::ENSEMBL_SERVERROOT.'\/eg-web-common',"
  perl -p -i -e "s/(.*EnsEMBL::Mirror.*)/\$1\n$EG_DIVISION_PLUGIN\n$EG_API_PLUGIN\n$EG_COMMON_PLUGIN/" $SERVER_ROOT/ensembl-webcode/conf/Plugins.pm;
fi

# begin writing SiteDefs.pm
printf "package EnsEMBL::Mirror::SiteDefs;\nuse strict;\n\nsub update_conf {" > $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm

# set webserver parameters
HTTP_PORT=$(awk -F "=" '/HTTP_PORT/ {print $2}' $INI | tr -d ' ')
echo "  \$SiteDefs::APACHE_DIR = '/usr/local/apache2';" >> $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm
echo "  \$SiteDefs::APACHE_BIN = '/usr/local/apache2/bin/httpd';" >> $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm
echo "  \$SiteDefs::ENSEMBL_PORT = $HTTP_PORT;" >> $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm

# create directories for species/placeholder images
mkdir -p $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/16
mkdir -p $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/48
mkdir -p $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/64
cp placeholder-64.png $SERVER_ROOT/public-plugins/mirror/htdocs/i/placeholder.png

# set DB_FALLBACK variables
DB_FALLBACK_HOST=$(awk -F "=" '/DB_FALLBACK_HOST/ {print $2}' $INI | tr -d ' ')
DB_FALLBACK_PORT=$(awk -F "=" '/DB_FALLBACK_PORT/ {print $2}' $INI | tr -d ' ')
DB_FALLBACK_USER=$(awk -F "=" '/DB_FALLBACK_USER/ {print $2}' $INI | tr -d ' ')
DB_FALLBACK_PASS=$(awk -F "=" '/DB_FALLBACK_PASS/ {print $2}' $INI | tr -d ' ')
DB_FALLBACK2_HOST=$(awk -F "=" '/DB_FALLBACK2_HOST/ {print $2}' $INI | tr -d ' ')
DB_FALLBACK2_PORT=$(awk -F "=" '/DB_FALLBACK2_PORT/ {print $2}' $INI | tr -d ' ')
DB_FALLBACK2_USER=$(awk -F "=" '/DB_FALLBACK2_USER/ {print $2}' $INI | tr -d ' ')
DB_FALLBACK2_PASS=$(awk -F "=" '/DB_FALLBACK2_PASS/ {print $2}' $INI | tr -d ' ')


# use SPECIES_DBS to populate Primary/Secondary species
SPECIES_DBS=$(awk -F "=" '/SPECIES_DBS/ {print $2}' $INI | tr -d '[' | tr -d ']')
SPECIES_DB_AUTO_EXPAND=$(awk -F "=" '/SPECIES_DB_AUTO_EXPAND/ {print $2}' $INI | tr -d '[' | tr -d ']')
PRIMARY_SP=`echo $SPECIES_DBS | cut -d' ' -f 1 | awk -F'_core_' '{print $1}'`
PRIMARY_SP="$(tr '[:lower:]' '[:upper:]' <<< ${PRIMARY_SP:0:1})${PRIMARY_SP:1}"
SECONDARY_SP=`echo $SPECIES_DBS | cut -d' ' -f 2 | awk -F'_core_' '{print $1}'`
SECONDARY_SP="$(tr '[:lower:]' '[:upper:]' <<< ${SECONDARY_SP:0:1})${SECONDARY_SP:1}"
if [ -z $SECONDARY_SP ]; then
  SECONDARY_SP=$PRIMARY_SP
fi
echo "  map {delete(\$SiteDefs::__species_aliases{\$_}) } keys %SiteDefs::__species_aliases;" >> $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm
echo "  \$SiteDefs::ENSEMBL_PRIMARY_SPECIES    = '$PRIMARY_SP'; # Default species" >> $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm
echo "  \$SiteDefs::ENSEMBL_SECONDARY_SPECIES  = '$SECONDARY_SP'; # Secondary species" >> $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm
DEFAULT_FAVOURITES="DEFAULT_FAVOURITES = ["
# loop through all SPECIES_DBS to test DB connections and generate config files
for DB in $SPECIES_DBS
do
  # test whether we can connect to this DB
  species_db_fallback $DB
  if ! [ $DB_CONNECT_RESULT -eq 0 ]; then
    echo "ERROR: unable to connect to database $DB"
    continue
  else
    echo "Connection to $DB on $TEST_HOST successful"
  fi
  SP_LOWER=`echo $DB | awk -F'_core_' '{print $1}'`
  SP_UC_FIRST="$(tr '[:lower:]' '[:upper:]' <<< ${SP_LOWER:0:1})${SP_LOWER:1}"
  echo "  \$SiteDefs::__species_aliases{ '$SP_UC_FIRST' } = [qw($SP_LOWER)];" >> $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm

  # add to DEFAULT_FAVOURITES
  DEFAULT_FAVOURITES="$DEFAULT_FAVOURITES $SP_UC_FIRST"

  # add/copy species images and about pages
  if [ -z $EG_DIVISION ]; then
    # ensembl mirror so look for existing files
    if [ -e "$SERVER_ROOT/public-plugins/ensembl/htdocs/i/species/64/$SP_UC_FIRST.ini" ]; then
      cp $SERVER_ROOT/public-plugins/ensembl/htdocs/i/species/16/$SP_UC_FIRST.png $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/16/$SP_UC_FIRST.png
      cp $SERVER_ROOT/public-plugins/ensembl/htdocs/i/species/48/$SP_UC_FIRST.png $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/48/$SP_UC_FIRST.png
      cp $SERVER_ROOT/public-plugins/ensembl/htdocs/i/species/64/$SP_UC_FIRST.png $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/64/$SP_UC_FIRST.png
    else
      cp placeholder-16.png $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/16/$SP_UC_FIRST.png
      cp placeholder-48.png $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/48/$SP_UC_FIRST.png
      cp placeholder-64.png $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/64/$SP_UC_FIRST.png
    fi
  else
    cp placeholder-16.png $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/16/$SP_UC_FIRST.png
    cp placeholder-48.png $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/48/$SP_UC_FIRST.png
    cp placeholder-64.png $SERVER_ROOT/public-plugins/mirror/htdocs/i/species/64/$SP_UC_FIRST.png
  fi

  # create a Genus_species.ini file in mirror/conf/ini-files
  printf "[general]\n\n[ENSEMBL_STYLE]\n\n[ENSEMBL_COLOURS]\n\n[databases]\n" > $SERVER_ROOT/public-plugins/mirror/conf/ini-files/$SP_UC_FIRST.ini
  printf "DATABASE_CORE = $DB\n#OTHER_DATABASES\n\n" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/$SP_UC_FIRST.ini
  # !add database connection parameters to Genus_species.ini
  printf "\n[DATABASE_CORE]\nHOST = $TEST_HOST\nPORT = $TEST_PORT\nUSER = $TEST_USER\nPASS = $TEST_PASS\n" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/$SP_UC_FIRST.ini

  # attempt to add additional database types
  for DB_TYPE in $SPECIES_DB_AUTO_EXPAND
  do
    NEW_DB=${DB/_core_/_${DB_TYPE}_}
    species_db_fallback $NEW_DB
    if ! [ $DB_CONNECT_RESULT -eq 0 ]; then
      echo "WARNING: unable to connect to database $NEW_DB"
    else
      echo "Connection to $NEW_DB on $TEST_HOST successful"
      UC_TYPE=${DB_TYPE^^}
      # add database connection parameters to Genus_species.ini
      printf "\n[DATABASE_$UC_TYPE]\nHOST = $TEST_HOST\nPORT = $TEST_PORT\nUSER = $TEST_USER\nPASS = $TEST_PASS\n" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/$SP_UC_FIRST.ini
      perl -p -i -e "s/(.OTHER_DATABASES)/DATABASE_$UC_TYPE = $NEW_DB\n\$1/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/$SP_UC_FIRST.ini
    fi
  done

done
DEFAULT_FAVOURITES="$DEFAULT_FAVOURITES ]"

# finish writing SiteDefs.pm
printf "}\n\n1;\n" >> $SERVER_ROOT/public-plugins/mirror/conf/SiteDefs.pm

# update default favourites list
printf "\n[general]\n$DEFAULT_FAVOURITES" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/DEFAULTS.ini

# set multi-species database connection parameters
printf "[DATABASES]\n  DATABASE_SESSION = ensembl_session\n  DATABASE_ACCOUNTS = ensembl_accounts\n#OTHER_DATABASES\n" > $SERVER_ROOT/public-plugins/mirror/conf/ini-files/MULTI.ini

DB_SESSION_HOST=$(awk -F "=" '/DB_SESSION_HOST/ {print $2}' $INI | tr -d ' ')
DB_SESSION_PORT=$(awk -F "=" '/DB_SESSION_PORT/ {print $2}' $INI | tr -d ' ')
DB_SESSION_USER=$(awk -F "=" '/DB_SESSION_USER/ {print $2}' $INI | tr -d ' ')
DB_SESSION_PASS=$(awk -F "=" '/DB_SESSION_PASS/ {print $2}' $INI | tr -d ' ')
printf "\n[DATABASE_SESSION]\n  USER = $DB_SESSION_USER \n  HOST = $DB_SESSION_HOST\n  PORT = $DB_SESSION_PORT\n  PASS = $DB_SESSION_PASS\n" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/MULTI.ini
printf "\n[DATABASE_ACCOUNTS]\n  USER = $DB_SESSION_USER \n  HOST = $DB_SESSION_HOST\n  PORT = $DB_SESSION_PORT\n  PASS = $DB_SESSION_PASS\n" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/MULTI.ini

# ! todo: test/set connection parameters to each db in MULTI_DBS
MULTI_DBS=$(awk -F "=" '/MULTI_DBS/ {print $2}' $INI | tr -d '[' | tr -d ']')
for DB in $MULTI_DBS
do
  species_db_fallback $DB
  if ! [ $DB_CONNECT_RESULT -eq 0 ]; then
    echo "WARNING: unable to connect to database $DB"
  else
    echo "Connection to $DB on $TEST_HOST successful"
    LC_COLLATE=C
    DB_TYPE=${DB/ensembl_/}
    DB_TYPE=${DB/ensemblgenomes_/}
    DB_TYPE=${DB_TYPE//_[0-9]/}
    DB_TYPE=${DB_TYPE//[0-9]/}
    UC_TYPE=${DB_TYPE^^}
    if [ $UC_TYPE = "ONTOLOGY" ]; then
      UC_TYPE="GO"
    fi
    if [ $UC_TYPE = "ANCESTRAL" ]; then
      UC_TYPE="CORE"
    fi
    if [ $UC_TYPE = "INFO" ]; then
      UC_TYPE="METADATA"
    fi
    if [ $UC_TYPE = "COMPARA_PAN_HOMOLOGY" ]; then
      UC_TYPE="COMPARA_PAN_ENSEMBL"
    fi
    if [ `echo $UC_TYPE | cut -d'_' -f 1` = "COMPARA" ]; then
      UC_TYPE="COMPARA"
    fi
    # add database connection parameters to Genus_species.ini
    printf "\n[DATABASE_$UC_TYPE]\nHOST = $TEST_HOST\nPORT = $TEST_PORT\nUSER = $TEST_USER\nPASS = $TEST_PASS\n" >> $SERVER_ROOT/public-plugins/mirror/conf/ini-files/MULTI.ini
    perl -p -i -e "s/(.OTHER_DATABASES)/DATABASE_$UC_TYPE = $NEW_DB\n\$1/" $SERVER_ROOT/public-plugins/mirror/conf/ini-files/MULTI.ini
  fi
done
