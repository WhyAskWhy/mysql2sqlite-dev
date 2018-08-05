# mysql2sqlite-dev

Development environment for
[mysql2sqlite](https://github.com/WhyAskWhy/mysql2sqlite) work. This repo may
be folded into that repo at a later time.

## Requirements

In order to reduce setup requirements on the part of the developer, the scripts
used by this project make multiple assumptions that the main project does not:

- Ubuntu 16.04
  - clean, without any packages already installed aside from OS and
      integration tools (e.g., Hyper-V, VirtualBox, VMware Tools)
- Internet access (needed for installation and setup of packages)

## Repo layout

File/Path | Purpose | Notes
--------- | ------- | -----
`bin` | Scripts meant to be used directly by developer| Most are used directly within the guest/VM, but some from Host system
`bin/create_db.sh` | Run after the `bin/setup_dev_environment.sh` script in order to create SQLite database file | Usually run once
`bin/rebuild_test_db.sh` | Run as-needed to reset db state after tinkering with the content. Convenience script only
`bin/setup_dev_environment.sh` | Main setup script to kickstart a new dev environment | Usually run just once per new dev env
`bin/sync_files.ps1` | Copy files from Hyper-V Host to Hyper-V guest | Alternative to first cloning this repo to get access to `bin/setup_dev_environment.sh` script
`bin/validate_dbs.py` | Run after the `bin/create_db.sh` script to perform basic validation of newly created SQLite db. | WIP, future script that I hope to refactor and use as pre and post CI tools to confirm valid conversion results. This script may be moved to the main project in the near future.
`bin/validate_dbs.sh` | Run after the `bin/create_db.sh` script to perform basic validation of newly created SQLite db. | DEPRECATED. This script will probably be removed in the near future as most of the functionality has been replicated by the `bin/validate_dbs.py` script
`etc` | Configuration files for various dependencies/tools used within dev environment | Deployed as part of running the `bin/setup_dev_environment.sh` script
`keys` | Local copy of upstream repo package signing keys | May be phased out if not proven useful
`sql` | Import files used to setup database used by main project | Imported as part of running the `bin/setup_dev_environment.sh` script
`LICENSE` | License for this collection of content | Intended to match the license used for main project
`README.md` | Main doc file for this project | Please submit a PR or bug report for any missing or incorrect coverage

## Dependencies

### Gitea (or similar local Git mirror)

To keep from abusing GitHub, VSTS and other Git "remotes", I run a local Gitea
instance. This is entirely optional and can be overriden by adjusting the
`MAIN_PROJECT_GIT_REPO_URL` and `THIS_DEV_ENV_GIT_REPO_URL` variables
within the various build scripts to reference a different Git remote.
Alternatives are provided, but commented out in case you wish to use them.

You will find evidence of Gitea specified by the `local-mirror:3000` Git repo
URLs in the various build scripts.

### Squid proxy server

Used much for the same reason as with the local Gitea instance, I run a local
Squid VM to cache remote content for local rebuilds.

Not yet included here, this proxy has been enabled by way of the
`/etc/environment` and `/etc/apt/apt.conf` conf files. Those files were
modified by way of the `Network proxy` configuration UI within the test VM.
See the link below in the References section for details.

Using this UI (or directly modifying the files mentioned) allows our Ubuntu
16.04 test box to use the Squid proxy server for system-wide
proxy use. This is of particular help with speeding up package installation
for repeat builds. I like to also think that using local mirrors for builds
is appreciated by upstream package mirror maintainers/owners.

### Postfix

As part of the setup work, Postfix is installed and configured to use local
MySQL and SQLite databases for many of its lookup tables. This is intended
to serve as a means of verifying that mysql2sqlite was successful in exporting
entries from the MySQL tables to the local SQLite database.

The idea is that if we get consistent, duplicate results when running
postmap queries against both the MySQL and SQLite database tables then
mysql2sqlite is working as intended.

Listens on localhost only.

### MariaDB

The latest upstream version of MariaDB 10.0.x is installed and configured in an
insecure manner for production purposes, but sufficient for our local testing
needs. No password is set for the `root` account.

Listens on localhost only.

## Tools

The following list of tools are installed as part of running the
`bin/setup_dev_environment.sh` script during the initial test VM setup:

- DB Browser GUI application
- MySQL Workbench (or an alternative)

These tools are meant to assist with taking a "hands-on" approach to
troubleshooting issues with source and destination databases.

## References

- the local [docs/references.md](docs/references.md) file.
- the main project [docs/references.md](https://github.com/WhyAskWhy/mysql2sqlite/blob/master/docs/references.md) file.
