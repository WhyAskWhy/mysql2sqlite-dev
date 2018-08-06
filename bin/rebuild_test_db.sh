#!/bin/bash

# https://github.com/WhyAskWhy/mysql2sqlite
# https://github.com/WhyAskWhy/mysql2sqlite-dev

# Purpose: Quickly/easily drop and recreate test MySQL database

if [[ ! -d "$PWD/sql" ]]
then
  echo "Incorrect working directory. Move into mysql2sqlite-dev repo and try again."
else

  echo "* Dropping MySQL mailserver database ..."
  mysql -u root -e "drop database mailserver;"

  echo "* Recreating MySQL mailserver database ..."
  mysql -u root < $PWD/sql/mysql_db_schema.sql ||
    { echo "Failed to import db schema database. Aborting!"; exit 1; }

  echo "* Setting up MySQL mailserver database user, access ..."
  mysql -u root < $PWD/sql/setup_mysql_database.sql ||
    { echo "Failed to setup database. Aborting!"; exit 1; }

  echo "* Importing MySQL mailserver database test data ..."
  mysql -u root < $PWD/sql/mysql_test_data.sql ||
    { echo "Failed to import test data. Aborting!"; exit 1; }

fi
