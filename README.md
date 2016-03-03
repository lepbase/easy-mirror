# EnsEMBL Easy

Code to install an ensembl webserver on a fresh install of Ubuntu 14.04

## Quick instructions

### Step 1: Install dependencies

```bash
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install git
cd ~
git clone https://bitbucket.org/lepbase/ensembl-easy ee
cd ee
cp example.ini my.ini # Ensembl
# cp eg.ini my.ini # EnsemblGenomes
nano my.ini
```

edit ``[ENSEMBL_USER]`` and ``[WEBSITE]`` stanzas in ``my.ini``

* all ensembl-specific code in subsequent steps will be installed into the
  ``/SERVER_ROOT`` directory
* use ``WEB_USER_NAME`` to create a non-admin user to own the ``/SERVER_ROOT``
  directory or leave blank to skip adding a new user
* to use an ``HTTP_PORT`` < 1024 (e.g. port 80), step 4 must be run by an admin
  user

```bash
sudo ./install-dependencies.sh my.ini
```

Subsequent steps do not require sudo, if running these as a different user:

```bash
su eguser
cd ~
git clone https://bitbucket.org/lepbase/ensembl-easy ee
```

and copy/edit ``my.ini`` to match earlier changes

### Step 2: Setup databases

At least one local database (actually two, to match the different naming
  conventions of Ensembl and EnSemblGenomes) must be created with write access.
  These instructions assume that both the webserver and database are on
  ``localhost``. Use of separate hosts is supported but will require changes to
  ``/etc/mysql/my.cnf`` to allow external connections.

```bash
cp databases.ini my-db.ini # Ensembl
# cp eg-databases.ini my.ini # EnsemblGenomes
nano my.ini
```

edit ``[DATABASE]`` and ``[DATA_SOURCE]`` stanzas in ``my.ini``. Any variables
  not included in the list below are required

* ``DB_USER`` and ``DB_WEBSITE_USER`` are optional, as are passwords for these
  users, however if species and/or website databases are to be hosted locally
  these values must be set so the appropriate users can be created
* ``DB_SESSION_USER`` is required and must have read/write access to a local
  ``ensembl_session``/``ensembl_accounts`` database so ``DB_SESSION_PASS`` is
  also required
* ``ENSEMBL_DB_URL`` is required as it contains the path to a downloadable
  version of the ``ensembl_accounts`` database
* to create local copies of additional Ensembl website databases such as
  ``ensembl_archive_83`` and ``ensembl_website_83``, add these to the list of
  databases in ``ENSEMBL_DBS``
* ``EG_DB_URL`` is optional. If set, local copies of any databases listed in
  ``EG_DBS`` will be created
* ``SPECIES_DB_URL`` is optional. If set, local copies of any species/compara
  databases listed in ``SPECIES_DBS`` will be created
* ``MISC_DB_URL`` is also optional and allows local copies of additional
  databases to be created from an alternative source

```bash
./setup-databases.sh my.ini
```

### Step 3: Update Ensembl code

edit ``[DATABASE]``, ``[REPOSITORIES]`` and ``[DATA_SOURCE]`` stanzas in
  ``my.ini``. Only species databases listed in ``SPECIES_DBS`` will be included
  in the site.

```bash
./update-ensembl-code.sh my.ini
```

### Step 4: Reload Ensembl site

Edit the generated configuration files in ``$SERVER_ROOT/public-plugins/mirror/conf``
  and html/image files in ``$SERVER_ROOT/public-plugins/mirror/htdocs`` if
  required then (re)load the website.

```bash
./reload-ensembl-site.sh my.ini
```
