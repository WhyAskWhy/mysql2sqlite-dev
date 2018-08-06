#!/bin/bash

# https://github.com/WhyAskWhy/mysql2sqlite
# https://github.com/WhyAskWhy/mysql2sqlite-dev

# Purpose:
#
#   Perform identicalmysql_query_result=$(sudo postalias queries against both databases to confirm
#   both databases provide matching results.

# Do not allow use of unitilized variables
set -u

# errtrace
#         Same as -E.
#
# -E      If set, any trap on ERR is inherited by shell functions,
#         command substitutions, and commands executed in a sub‐
#         shell environment.  The ERR trap is normally not inher‐
#         ited in such cases.
# set -o errtrace

# Exit if any statement returns a non-true value
# http://mywiki.wooledge.org/BashFAQ/105
# set -e

# Exit if ANY command in a pipeline fails instead of allowing the exit code
# of later commands in the pipeline to determine overall success
#set -o pipefail

trap 'echo "Error occurred on line $LINENO."; exit 1' ERR

database="mailserver"
sqlite_db_file="/var/cache/mysql2sqlite/mailserver.db"

compare_table_entries() {

  table=$1
  column=$2

  # Allow filename suffix to be overridden if needed, otherwise if 3rd
  # positional argument is not passed then use table name as the default.
  # https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
  if [[ -z "${3+x}" ]]; then
    filename_suffix="$table"
    function_intro_message="\n* Checking $table table ..."
  else
    filename_suffix="$3"
    function_intro_message="\n* Checking $table table (${3}) ..."
  fi

  echo -e "${function_intro_message}"
  mysql -u root --batch --skip-column-names \
    -e "select $column from ${database}.${table}" | \
    while read -r value
    do
      echo -n "  [i] Searching for $value ... "
      mysql_query_result=$(sudo postalias -q $value mysql:/etc/postfix/mysql/mysql-${filename_suffix}.cf)
      sqlite_query_result=$(sudo postalias -q $value sqlite:/etc/postfix/sqlite/sqlite-${filename_suffix}.cf)

      if [[ ! "${mysql_query_result+x}" == "${sqlite_query_result+x}" ]]; then
        echo "[!] Mismatch between MySQL and SQLite table entries! Aborting."
        echo "MySQL query result: ${mysql_query_result}"
        echo "SQLite query result: ${sqlite_query_result}"
        exit 1
      else

        if [[ -z "${mysql_query_result}" ]] || [[ -z "${sqlite_query_result}" ]]; then
          mysql_field_enabled_value=$(mysql -u root --batch --skip-column-names -e "select enabled from ${database}.${table} where $column = '$value'")
          sqlite_field_enabled_value=$(sqlite3 -noheader -separator '' ${sqlite_db_file} "select enabled from virtual_aliases where source = '$value'")

          if [[ "${mysql_field_enabled_value}" -eq 0 ]] && [[ "${sqlite_field_enabled_value}" -eq 0 ]]; then
            echo "[-] No result for postalias query; confirmed db entry is disabled"
          else
            echo "[-] No result for postalias query, alias is likely disabled, results inconclusive"
          fi

        else
          echo "[OK] Match found"
        fi

      fi
    done

}

compare_table_entries "virtual_domains" "name"
compare_table_entries "access_check_clients" "client"
compare_table_entries "access_check_recipients" "recipient"
compare_table_entries "access_check_senders" "sender"
compare_table_entries "local_aliases" "source"
compare_table_entries "mail_relay_whitelist" "client"
compare_table_entries "recipient_bcc_maps" "original_recipient"
compare_table_entries "sender_bcc_maps" "sender"
compare_table_entries "sender_dependent_default_transport_maps" "sender"
compare_table_entries "transport_maps" "recipient"
compare_table_entries "virtual_aliases" "source"
compare_table_entries "virtual_users" "email"

# TODO: Is this really needed?
compare_table_entries "virtual_users" "email" "email2email"
