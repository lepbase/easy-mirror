# EnsEMBL Easy

Code to make it easy to install an [EnsEMBL](http://ensembl.org) webserver on a
  fresh install of Ubuntu 14.04. The scripts in this repository will fetch
  dependencies and configure a local mirror of Ensembl/EnsemblGenomes with any
  combination of existing species using entirely remotely hosted data for
  minimum footprint, entirely locally hosted data for maximum performance or
  anywhere in between.

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
