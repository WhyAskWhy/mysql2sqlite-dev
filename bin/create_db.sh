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

# Attempt to emulate approach that would be used to pass in a dir path
# to the main script.
cmdline_dir_value=$1

config_file_dirs=(
    "${cmdline_dir_value}"
    "/etc/mysql2sqlite"
    "~/.config/mysql2sqlite"
    "/tmp/${MAIN_PROJECT_GIT_REPO_BASENAME}"
)


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

config_files_found="false"
config_files_path=""
# Deploy template config files locally if not already present elsewhere
for config_file_dir in "${config_file_dirs[@]}"
do
    echo "Checking $config_file_dir for config files ..."
    if [[ -f "${config_file_dir}/${general_config_file}" ]] && \
       [[ -f "${config_file_dir}/${query_config_file}" ]]; then
        config_files_found="true"
        config_files_path="${config_file_dir}"
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
