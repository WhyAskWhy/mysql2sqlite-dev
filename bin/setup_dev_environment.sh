#!/bin/bash

# https://github.com/WhyAskWhy/mysql2sqlite
# https://github.com/WhyAskWhy/mysql2sqlite-dev


# Purpose: Help setup new Ubuntu 16.04 VM for testing mysql2sqlite project


# Do not allow use of unitilized variables
set -u

# errtrace
#         Same as -E.
#
# -E      If set, any trap on ERR is inherited by shell functions,
#         command substitutions, and commands executed in a sub‐
#         shell environment.  The ERR trap is normally not inher‐
#         ited in such cases.
set -o errtrace

# Exit if any statement returns a non-true value
# set -e

# Exit if ANY command in a pipeline fails instead of allowing the exit code
# of later commands in the pipeline to determine overall success
set -o pipefail

trap 'echo "Error occurred on line $LINENO."' ERR


if [[ "$UID" -eq 0 ]]; then
  echo "Run this script without sudo or as root, sudo will be called as needed."
  exit 1
fi

#MAIN_PROJECT_GIT_REPO_URL="https://github.com/deoren/mysql2sqlite"
MAIN_PROJECT_GIT_REPO_URL="https://github.com/WhyAskWhy/mysql2sqlite"
#MAIN_PROJECT_GIT_REPO_URL="http://local-mirror:3000/mirror/mysql2sqlite"
MAIN_PROJECT_GIT_REPO_BASENAME="$(basename ${MAIN_PROJECT_GIT_REPO_URL})"
MAIN_PROJECT_GIT_REPO_BRANCH="master"

# THIS_DEV_ENV_GIT_REPO_URL="https://github.com/deoren/mysql2sqlite-dev"
THIS_DEV_ENV_GIT_REPO_URL="https://github.com/WhyAskWhy/mysql2sqlite-dev"
# THIS_DEV_ENV_GIT_REPO_URL="http://local-mirror:3000/mirror/mysql2sqlite-dev"
THIS_DEV_ENV_GIT_REPO_BASENAME="$(basename ${THIS_DEV_ENV_GIT_REPO_URL})"
THIS_DEV_ENV_GIT_REPO_BRANCH="master"

# TODO: Find a safe way to automatically use 'tee' for all commands without
# unintentionally muting error codes. Until then, we do not actually use
# this file.
SETUP_LOG_FILE="$HOME/mysql2sqlite_dev_env_setup_output.txt"

# Create empty log file so that later tee commands can append to it
touch ${SETUP_LOG_FILE}

echo "* Performing initial refresh of package lists ..."
sudo apt-get update ||
    { echo "Another apt operation is probably in progress. Try again."; exit 1; }

echo "* Installing git in order to fetch repos ..."
sudo apt-get install -y git ||
    { echo "Failed to install git packages. Aborting!"; exit 1; }


cd /tmp

echo "* Removing old clone of ${THIS_DEV_ENV_GIT_REPO_URL} ..."
sudo rm -rf ${THIS_DEV_ENV_GIT_REPO_BASENAME}

echo "* Removing old clone of ${MAIN_PROJECT_GIT_REPO_URL} ..."
sudo rm -rf ${MAIN_PROJECT_GIT_REPO_BASENAME}

echo "* Cloning ${THIS_DEV_ENV_GIT_REPO_URL} ..."
git clone ${THIS_DEV_ENV_GIT_REPO_URL} ||
    { echo "Failed to clone ${THIS_DEV_ENV_GIT_REPO_URL}. Aborting!"; exit 1; }

cd ${THIS_DEV_ENV_GIT_REPO_BASENAME}
git checkout ${THIS_DEV_ENV_GIT_REPO_BRANCH}

cd /tmp
echo "* Cloning ${MAIN_PROJECT_GIT_REPO_URL} ..."
git clone ${MAIN_PROJECT_GIT_REPO_URL} ||
    { echo "Failed to clone ${MAIN_PROJECT_GIT_REPO_URL}. Aborting!"; exit 1; }
cd ${MAIN_PROJECT_GIT_REPO_BASENAME}
git checkout ${MAIN_PROJECT_GIT_REPO_BRANCH}

#
# Deploy rsyslog config fragment to catch/redirect mysql2sqlite messages
#

echo "* Deploying rsyslog conf file for mysql2sqlite log messages ..."
sudo cp -vf /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/etc/rsyslog.d/*.conf /etc/rsyslog.d/ ||
    { echo "Failed to deploy rsyslog conf file for mysql2sqlite log messages. Aborting!"; exit 1; }

echo "* Restarting rsyslog to apply conf changes ..."
sudo systemctl restart rsyslog ||
    { echo "Failed to restart rsyslog to apply conf changes. Aborting!"; exit 1; }

######################################################
# Setup upstream apt repos
######################################################

echo "* Deploying apt repo config files ..."

# Repo conf files
for apt_repo_conf_file in mariadb-server.list
do
    sudo cp -vf /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/etc/apt/sources.list.d/${apt_repo_conf_file} /etc/apt/sources.list.d/ ||
        { echo "[!] Failed to deploy ${apt_repo_conf_file} ... aborting"; exit 1; }
done

######################################################
# Install package signing keys
######################################################

echo "* Installing apt repo package signing keys ..."

# MariaDB
if [[ ! -f /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/keys/mariadb_signing.key ]]; then
    sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8 ||
        { echo "[!] Failed to retrieve MariaDB signing key ... aborting"; exit 1; }
else
    sudo apt-key add /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/keys/mariadb_signing.key ||
        { echo "[!] Failed to install local repo copy of MariaDB signing key ... aborting"; exit 1; }
fi


######################################################
# Install packages
######################################################


echo "* Refreshing package lists ..."
sudo apt-get update ||
    { echo "Another apt operation is probably in progress. Try again."; exit 1; }

echo "* Installing primary packages ..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    sqlite3 \
    python3-pip \
    sqlitebrowser \
    ||
        { echo "Failed to install required pacakges. Try again."; exit 1; }

# Install MariaDB without prompts, relying on default behavior of no password
echo "* Installing MariaDB ..."
sudo DEBIAN_FRONTEND=noninteractive apt-get -q -y install mariadb-server ||
    { echo "Failed to install MariaDB packages. Aborting!"; exit 1; }


# Install this AFTER MariaDB in an attempt to prevent a conflict between
# the MariaDB packages and the Ubuntu-provied MySQL-related package deps for
# MySQL Workbench
sudo apt-get install -y \
    mysql-workbench

# Install Postfix without prompts
echo "* Installing Postfix ..."
sudo bash -c "echo 'postfix postfix/mailname string localhost' | debconf-set-selections"
sudo bash -c "echo 'postfix postfix/main_mailer_type select No configuration' | debconf-set-selections"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq -y \
    postfix \
    postfix-mysql \
    mailutils ||
    { echo "Failed to install Postfix package. Aborting!"; exit 1; }


echo "* Deploying Postfix config files ..."
sudo cp -Rvf /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/etc/postfix/* /etc/postfix/ ||
    { echo "Failed to deploy Postfix config files. Aborting!"; exit 1; }

echo "* Running newaliases to update Postfix aliases db ..."
sudo newaliases ||
    { echo "Failed to update Postfix aliases db. Aborting!"; exit 1; }

sudo systemctl enable postfix ||
    { echo "Failed to enable Postfix unit. Aborting!"; exit 1; }

sudo systemctl restart postfix ||
    { echo "Failed to start Postfix. Aborting!"; exit 1; }


######################################################
# SeUse SQL files to setup database, create account
# and grant permissions to db
######################################################

database_name="mailserver"

echo "* Importing MySQL db schema file for '${database_name}' database ..."
mysql -u root < /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/sql/mysql_db_schema.sql ||
    { echo "Failed to import schema for '${database_name}' database. Aborting!"; exit 1; }

echo "* Setting up '${database_name}' database user, access ..."
mysql -u root < /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/sql/setup_mysql_database.sql ||
    { echo "Failed to setup '${database_name}' database. Aborting!"; exit 1; }

# Import mailserver database test data
mysql_import_file="mysql_test_data.sql"
echo "* Importing MySQL test data from  '${mysql_import_file}' data ..."
mysql -u root < /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/sql/${mysql_import_file} ||
    { echo "Failed to import ${mysql_import_file}. Aborting!"; exit 1; }


echo "* Installing Python modules via pip for current user ..."
pip3 install \
    --requirement /tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}/requirements.txt \
    --user
