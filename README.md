# EnsEMBL Easy

Code to make it easy to install an [EnsEMBL](http://ensembl.org) webserver on a
  fresh install of Ubuntu 14.04. The scripts in this repository will fetch
  dependencies and configure a local mirror of Ensembl/EnsemblGenomes with any
  combination of existing species using entirely remotely hosted data for
  minimum footprint, entirely locally hosted data for maximum performance or
  anywhere in between.

[![DOI](https://zenodo.org/badge/20772/lepbase/ensembl-easy.svg)](https://zenodo.org/badge/latestdoi/20772/lepbase/ensembl-easy)

## Quick instructions

These instructions will get you started with an Ensembl mirror of human and
  mouse using locally hosted core databases with the remaining data loaded
  from the ensembl public mysql servers.

### Step 1: Install dependencies

This is the only step that requires sudo. If you wish to run the subsequent
  steps as a different user, add a ``WEB_USER_NAME`` and ``WEB_USER_PASS`` to
  the ``ini`` file to create this user and transfer ownership of the
  ``SERVER_ROOT`` directory

```bash
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install git
cd ~
git clone https://bitbucket.org/lepbase/ensembl-easy ee
cd ee
sudo ./install-dependencies.sh example.ini
```

### Step 2: Setup databases

At least one local database must be created with write access.
  These instructions assume that both the webserver and database are on
  ``localhost``. Use of separate hosts is supported but will require changes to
  ``/etc/mysql/my.cnf`` to allow external connections.


```bash
./setup-databases.sh databases.ini
```

### Step 3: Update Ensembl code

This step fetches/updates the ensembl code repositories and sets up
  configuration files in ``$SERVER_ROOT/public-plugins/mirror/conf``.

```bash
./update-ensembl-code.sh example.ini
```

### Step 4: Reload Ensembl site

The last step starts the webserver and, if necessary, restarts it up to 5 times.
  Usually this will be enough but sometimes you may need to run this script
  again before your  Ensembl mirror site becomes available at
  ``http://localhost:$HTTP_PORT/``

```bash
./reload-ensembl-site.sh my.ini
```

## Changing the defaults

To set up an ensembl genomes mirror with four locally hosted Lepidopteran
  species simply use the provided ``eg.ini`` file in place of ``example.ini``
  and ``eg-databases.ini`` in place of ``databases.ini``.  You will need to run
  steps 2 and 3 again after any changes to the database locations.

### Hosting more data locally

Provided the relevant dumps are available at ftp://ftp.ensembl.org/pub/ or
  ftp://ftp.ensemblgenomes.org/pub/ any database on the Ensembl sites can be
  specified in a ``databases.ini`` file to be hosted locally.  
  using ``databases-extra.ini`` or ``eg-databases-extra.ini`` in step 2 will
  fetch more for local hosting by using the ``SPECIES_DB_AUTO_EXPAND`` variable
  to list database types to attempt to retrieve in addition to the core
  database, or listing additional databases (e.g. compara) to host locally.

### Using a separate database host

Using separate webserver and database hosts is supported by changing the
  ``ENSEMBL_WEBSITE_HOST`` variable in ``databases.ini`` to something other than
  ``localhost``, however you will need to update your ``/etc/mysql/my.cnf`` file
  to allow database connections from another server.  Leaving the
  ``ENSEMBL_WEBSITE_HOST`` variable empty will set up users allowed to connect
  from any host.

## Editing the .ini files

### example.ini

Configuration options for steps 1, 3 and 4.

#### [DATABASE]

Four subsections with ``DB_[*_]HOST``, ``DB_[*_]PORT``, ``DB_[*_]USER`` and
  ``DB_[*_]PASS`` variables specify connection settings for:

* ``DB_HOST`` etc. - the primary database host with species/multi-species
  databases.
* ``DB_SESSION_HOST`` etc. - user-specific information, typically the only
  database to require read-write access and therefore a password protected
  connection.
* ``DB_FALLBACK_HOST`` etc. - to reduce the amount of locally hosted data, it is
  often desirable to use alternate sources for some databases, the
  ``DB_FALLBACK_HOST`` host will be queried to find any required databases that
  are not available on ``DB_HOST``
* ``DB_FALLBACK2_HOST`` etc. - especially with EnsemblGenomes sites, remote
  databases may be found on more than one host, the ``DB_FALLBACK2_HOST`` host
  will be queried to find any required databases that are not available on
  ``DB_HOST`` or ``DB_FALLBACK_HOST``

#### [ENSEMBL_USER]

To set up a non-admin user to run steps 2, 3 and 4, specify ``WEB_USER_NAME``
  and ``WEB_USER_PASS`` to create a new user with ownership of the
  ``SERVER_ROOT`` directory

#### [REPOSITORIES]

Connection/branch information for the Github repositories to be cloned

* ``ENSEMBL_URL``/``ENSEMBL_BRANCH`` - Ensembl code
* ``EG_URL``/``EG_BRANCH`` - (optional) EnsemblGenomes code
* ``BIOPERL_URL``/``BIOPERL_BRANCH`` - BioPerl code

#### [WEBSITE]

* ``HTTP_PORT`` - port to run the apache webserver on
  (``reload-ensembl-site.sh``) will need to be run with root privileges if this
  is set to a value below 1024
* ``SERVER_ROOT`` - the directory into which all ensembl code will be cloned and
  from which the site will be run

#### [DATA_SOURCE]

Database names to set up config files for/connect to

* ``SPECIES_DBS`` - a space separated list of ensembl core dbs in square braces
* ``SPECIES_DB_AUTO_EXPAND`` - to save listing all dbs for a given species this
  variable may be used to specify a set of replacement strings to attempt to
  connect to (e.g. specify  ``SPECIES_DBS = [ homo_sapiens_core_84_38 ]`` and ``SPECIES_DB_AUTO_EXPAND = [ variation ]`` to also load the database
  ``homo_sapiens_variation_84_38``, if it exists on ``DB_HOST`` or a
  ``DB_FALLBACK_HOST``
* ``MULTI_DBS`` - a space separated list of multispecies databases in square
  braces

### database.ini

configuration options for step 2.

#### [DATABASE]

Root user connection details and user names (and passwords) for database users to be created

#### [WEBSITE]

The name of the ``ENSEMBL_WEBSITE_HOST`` host (on which steps 1, 3 and 4 are
  run) is used when setting up the database users. If this is anything other
  than ``localhost`` then changes will be required to ``/etc/mysql/my.cnf`` to
  support external connections

#### [DATA_SOURCE]

Locations and names of database dumps to fetch and load locally.

* ``ENSEMBL_DB_URL`` - the URL containing the Ensembl database dumps
* ``ENSEMBL_DB_REPLACE`` - a flag to specify whether to overwrite databases that
  already exist on the ``DB_HOST``
* ``ENSEMBL_DBS`` - a space separated list of database dump names in square
  braces. ``ensembl_accounts`` is required, all others are optional

The equivalent variables may be set for ``EG_DB_URL`` to fetch and download
  EnsemblGenomes database dumps and for ``MISC_DB_URL`` to support situations
  where the required databases are spread across multiple hosts.

An additional variable may be set for species databases,  
  ``SPECIES_DB_AUTO_EXPAND`` - a space separated list of database types to use
  as replacement strings for ``core`` to facilitate downloading multiple
  database types for each species in ``SPECIES_DBS``
