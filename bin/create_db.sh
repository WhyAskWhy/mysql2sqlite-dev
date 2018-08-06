#!/bin/bash

# https://github.com/WhyAskWhy/mysql2sqlite
# https://github.com/WhyAskWhy/mysql2sqlite-dev

# Purpose:
#
#   Run primary script to generate output SQLite db file for testing

#MAIN_PROJECT_GIT_REPO_URL="https://github.com/deoren/mysql2sqlite"
#MAIN_PROJECT_GIT_REPO_URL="https://github.com/WhyAskWhy/mysql2sqlite"
MAIN_PROJECT_GIT_REPO_URL="http://local-mirror:3000/mirror/mysql2sqlite"
MAIN_PROJECT_GIT_REPO_BASENAME="$(basename ${MAIN_PROJECT_GIT_REPO_URL})"
MAIN_PROJECT_GIT_REPO_BRANCH="master"

# THIS_DEV_ENV_GIT_REPO_URL="https://github.com/deoren/mysql2sqlite-dev"
# THIS_DEV_ENV_GIT_REPO_URL="https://github.com/WhyAskWhy/mysql2sqlite-dev"
THIS_DEV_ENV_GIT_REPO_URL="http://local-mirror:3000/mirror/mysql2sqlite-dev"
THIS_DEV_ENV_GIT_REPO_BASENAME="$(basename ${THIS_DEV_ENV_GIT_REPO_URL})"
THIS_DEV_ENV_GIT_REPO_BRANCH="master"


# Get updated repo contents
if [[ ! -d /tmp/${MAIN_PROJECT_GIT_REPO_BASENAME} ]]; then
    cd /tmp
    git clone ${MAIN_PROJECT_GIT_REPO_URL}
    cd ${MAIN_PROJECT_GIT_REPO_BASENAME}
    git checkout ${MAIN_PROJECT_GIT_REPO_BRANCH}
else
    cd /tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}
    git reset HEAD --hard
    git checkout ${MAIN_PROJECT_GIT_REPO_BRANCH}
    git pull --ff-only
fi

# Check for required modules
if ! python3 -c "import mysql.connector"
then
    # Looks like we're missing some modules: install them
    pip3 install -r /tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}/requirements.txt --user
fi

# Go ahead and pre-create the output dir for SQLite database
sudo mkdir -vp /var/cache/mysql2sqlite
sudo chown -vR ${USER}: /var/cache/mysql2sqlite


# TODO: What command-line options are needed?
#   - path to main config file?
#   - path to output db file?
python3 /tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}/mysql2sqlite.py

if [[ $? -eq 0 ]]; then
    echo "Successfully generated SQLite db file."
    echo "Run python3 /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/bin/validate_dbs.py next to confirm db was created properly."
else
    echo "FAILURE to generate SQLite db file!"
    exit 1
fi
