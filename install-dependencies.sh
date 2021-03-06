#!/bin/bash

# check script was called correctly
INI=$1
if [ -z $INI ]; then
  echo "Usage: './install-dependencies.sh <filename.ini>'\n";
  exit 1
fi

# accept Microsoft EULA agreement without prompting
# view EULA at http://wwww.microsoft.com/typography/fontpack/eula.htm
debconf-set-selections <<< 'ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true'

# install most required packages using apt-get install
apt-get install -y \
           mysql-server \
           mysql-common \
           mysql-client \
           libmysqlclient*-dev \
           libgdbm-dev \
           libperl-dev \
           libxml2-dev \
           memcachedb \
           libmemcached-dev \
           libevent1-dev \
           acedb-other-dotter \
           make \
           curl \
           gcc \
           php-gd \
           freetype* \
           libgd2-xpm-dev \
           openssl \
           libssl-dev \
           graphviz \
           libcurl4-openssl-dev \
           ttf-mscorefonts-installer \
           default-jre \
           cpanminus \
           vcftools

# install most required perl modules using cpanminus
cpanm  Archive::Zip \
       CGI::Session \
       Class::Accessor \
       CSS::Minifier \
       DBI \
       HTTP::Date \
       Image::Size \
       Inline IO::Scalar \
       IO::Socket \
       IO::Socket::INET \
       IO::Socket::UNIX \
       IO::String \
       List::MoreUtils \
       Mail::Mailer \
       Math::Bezier \
       MIME::Types \
       PDF::API2 \
       RTF::Writer \
       Spreadsheet::WriteExcel \
       Sys::Hostname::Long \
       Text::ParseWords \
       URI \
       URI::Escape \
       HTML::Template \
       Clone \
       Hash::Merge \
       Class::DBI::Sweet \
       Compress::Bzip2 \
       Digest::MD5 \
       File::Spec::Functions \
       HTML::Entities \
       IO::Uncompress::Bunzip2 \
       XML::Parser \
       XML::Simple \
       XML::Writer \
       SOAP::Lite \
       GD \
       GraphViz \
       String::CRC32 \
       Cache::Memcached::GetParser \
       Inline::C \
       XML::Atom \
       LWP \
       BSD::Resource \
       WWW::Curl::Multi \
       JSON \
       Linux::Pid \
       Readonly \
       Module::Build \
       Bio::Root::Build \
       Lingua::EN::Inflect \
       YAML \
       Math::Round \
       Rose::DB::Object::Manager \
       Tree::DAG_Node \
       Encode::Escape::ASCII \
       IO::Unread \
       Text::LevenshteinXS \
       Math::SigFigs

# force install DBD::mysql as it will fail tests with default dbuser and password
cpanm --force DBD::mysql

# install the latest mod_perl-compatible version of apache2 (2.2 branch)
CURRENTDIR=`pwd`
cd /tmp
wget -q http://apache.mirror.anlx.net/httpd/CHANGES_2.2
APACHEVERSION=`grep "Changes with" CHANGES_2.2 | head -n 1 | cut -d" " -f 4`
wget -q http://apache.mirror.anlx.net/httpd/httpd-$APACHEVERSION.tar.gz
tar xzf httpd-$APACHEVERSION.tar.gz
cd httpd-$APACHEVERSION
./configure --with-included-apr --enable-deflate --enable-headers --enable-expires --enable-rewrite --enable-proxy
make
make install
cd $CURRENTDIR

# install the latest version of mod_perl
cd /tmp
wget -q -O tmp.html http://www.cpan.org/modules/by-module/Apache2/
MODPERLTAR=`grep -oP "mod_perl.*?tar" tmp.html | sort -Vr | head -n 1`
MODPERLVERSION=${MODPERLTAR%.*}
wget http://www.cpan.org/modules/by-module/Apache2/$MODPERLVERSION.tar.gz
tar xzf $MODPERLVERSION.tar.gz
cd $MODPERLVERSION/
perl Makefile.PL MP_APXS=/usr/local/apache2/bin/apxs
make
make install
cd $CURRENTDIR

# install Tabix.pm
cd /tmp
git clone https://github.com/samtools/tabix
cd tabix/perl
perl Makefile.PL
make
make install
cd $CURRENTDIR

# install Htslib.pm
cd /tmp
git clone https://github.com/samtools/htslib
cd htslib
make
make install
cd $CURRENTDIR

# install Bio::DB::HTS::Tabix using cpanminus
cpanm  Bio::DB::HTS::Tabix

# create symbolic link to perl binary in location referenced by ensembl scripts
ln -s /usr/bin/perl /usr/local/bin/perl

# create a directory for the ensembl code
SERVER_ROOT=$(awk -F "=" '/SERVER_ROOT/ {print $2}' $INI | tr -d ' ')
mkdir -p $SERVER_ROOT

# create user $WEB_USER_NAME if set
WEB_USER_NAME=$(awk -F "=" '/WEB_USER_NAME/ {print $2}' $INI | tr -d ' ')
WEB_USER_PASS=$(awk -F "=" '/WEB_USER_PASS/ {print $2}' $INI | tr -d ' ')
if ! [ -z $WEB_USER_NAME ]; then
  addgroup $WEB_USER_NAME
  adduser $WEB_USER_NAME \
          --ingroup $WEB_USER_NAME \
          --gecos "First Last,RoomNumber,WorkPhone,HomePhone" \
          --disabled-password
  echo "$WEB_USER_NAME:$WEB_USER_PASS" | chpasswd

  # change ownership of $SERVER_ROOT to $WEB_USER_NAME
  chown $WEB_USER_NAME:$WEB_USER_NAME $SERVER_ROOT
else
  # change ownership of $SERVER_ROOT to $USER
  ORIG_NAME=$(who am i | awk '{print $1}')
  chown $ORIG_NAME:$ORIG_NAME $SERVER_ROOT
fi
