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

general_config_file="mysql2sqlite_general.ini"
query_config_file="mysql2sqlite_queries.ini"

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

# Array of directory paths to check for existing config files. If not found,
# this script will deploy the provided templates. Entries are added to the
# array based on the same precedence set by the main script.
declare -a CONFIG_FILE_DIRS

# Attempt to source the same environment variable that the main script will
# attempt to use for evaluating config files
if [[ ! -z "${MYSQL2SQLITE_CONFIG_DIR+x}" ]]; then
    echo "Environment variable for specifying config files dir found: ${MYSQL2SQLITE_CONFIG_DIR}"
    CONFIG_FILE_DIRS+=("${MYSQL2SQLITE_CONFIG_DIR}")
else
    echo "SKIPPED: Environment variable for specifying config files dir not found"
fi

# Attempt to emulate approach that would be used to pass in a dir path
# to the main script.
if [[ ! -z "${1+x}" ]]; then
    echo "Command-line config files dir path specified: ${1}"
    CONFIG_FILE_DIRS+=("${1}")
else
    echo "SKIPPED: Command-line config files dir path not provided"
fi

CONFIG_FILE_DIRS+=("/tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}")
CONFIG_FILE_DIRS+=("$HOME/.config/mysql2sqlite")
CONFIG_FILE_DIRS+=("/etc/mysql2sqlite")

config_files_found="false"
config_files_path=""
# Deploy template config files locally if not already present elsewhere
for CONFIG_FILE_DIR in "${CONFIG_FILE_DIRS[@]}"
do
    echo "Checking $CONFIG_FILE_DIR for config files ..."
    if [[ -f "${CONFIG_FILE_DIR}/${general_config_file}" ]] && \
       [[ -f "${CONFIG_FILE_DIR}/${query_config_file}" ]]; then
        config_files_found="true"
        config_files_path="${CONFIG_FILE_DIR}"
        break
    fi
done

if [[ "${config_files_found}" == "false" ]]; then
    echo "Exiting config files not found. Deploying template config files ..."
    cp -v \
        /tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}/mysql2sqlite_general.ini.tmpl \
        /tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}/mysql2sqlite_general.ini

    cp -v \
        /tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}/mysql2sqlite_queries.ini.tmpl \
        /tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}/mysql2sqlite_queries.ini
else
    echo "Configuration files found in ${config_files_path}. Using those files."
fi


# TODO: What command-line options are needed?
#   - path to main config file?
#   - path to output db file?
python3 /tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}/mysql2sqlite.py \
    --config_file_dir "${cmdline_dir_value}"

if [[ $? -eq 0 ]]; then
    echo "Successfully generated SQLite db file."
    echo "Run python3 /tmp/${THIS_DEV_ENV_GIT_REPO_BASENAME}/bin/validate_dbs.py next to confirm db was created properly."
else
    echo "FAILURE to generate SQLite db file!"
    exit 1
fi
