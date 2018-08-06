#!/usr/bin/env python3

# https://github.com/WhyAskWhy/mysql2sqlite
# https://github.com/WhyAskWhy/mysql2sqlite-dev

"""
Query MySQL and SQLite databases, confirm matching entries in each.
"""



#######################################################
# Modules - Standard Library
#######################################################

# parse command line arguments, 'sys.argv'
import argparse
import logging
import logging.handlers
import operator
import os
import os.path
import pprint
import sqlite3
import subprocess
import sys



#######################################################
# Variables - (for now) duplicated from INI file
#######################################################

app_name = 'validate_dbs'

mysql_database = {
    'name': 'mailserver',
    'user': 'mysql2sqlite',
    'pass': 'qwerty',
    'host': 'localhost',
    'port': 3306,

}

sqlite_database = {
    'file': '/var/cache/mysql2sqlite/mailserver.db',
}

# Table names and column pairings; used to retrieve contents for validation
# via postmap.
# TODO: Replace with INI refs?
table_mappings = [
    {
    'name': 'virtual_domains',

    # FIXME: This may need tweaking in order to work with current code
    # and virtual_domains.cf file query.
    'key_column': 'name',
    'value_column': 'name',
    },
    {
    'name': 'access_check_clients',
    'key_column': 'client',
    'value_column': 'action',
    },
    {
    'name': 'access_check_recipients',
    'key_column': 'recipient',
    'value_column': 'action',
    },
    {
    'name': 'access_check_senders',
    'key_column': 'sender',
    'value_column': 'action',
    },
    {
    'name': 'local_aliases',
    'key_column': 'source',
    'value_column': 'destination',
    },
    {
    'name': 'mail_relay_whitelist',
    'key_column': 'client',
    'value_column': 'action',
    },
    {
    'name': 'recipient_bcc_maps',
    'key_column': 'original_recipient',
    'value_column': 'bcc_recipient',
    },
    {
    'name': 'sender_bcc_maps',
    'key_column': 'sender',
    'value_column': 'bcc_recipient',
    },
    {
    'name': 'sender_dependent_default_transport_maps',
    'key_column': 'sender',
    'value_column': 'transport',
    },
    {
    'name': 'transport_maps',
    'key_column': 'recipient',
    'value_column': 'transport',
    },
    {
    'name': 'virtual_aliases',
    'key_column': 'source',
    'value_column': 'destination',
    },
    {
    'name': 'virtual_users',
    'key_column': 'email',
    'value_column': '',
    },
    {
    'name': 'virtual_users',
    'key_column': 'email',
    'value_column': 'email',
    'file_suffix': 'email2email',
    },
]

# Use in warning log messages, reports, etc
validation_concerns = {
    'leading_space': 'Leading space',
    'trailing_space': 'Trailing space',
    # TODO: Flesh this out
}

# https://stackoverflow.com/questions/72899/how-do-i-sort-a-list-of-dictionaries-by-values-of-the-dictionary-in-python
table_mappings.sort(key=operator.itemgetter('name'))

# The only database types that we support at this time
VALID_DB_TYPES = { 'mysql', 'sqlite' }


#######################################################
# Functions
#######################################################

def sqlite_connect(sqlitedb_details):
    """Open connection to SQLite database, return cursor"""

    try:
        sqlite_connection = sqlite3.connect(
            sqlite_database['file'])
    except sqlite3.Error as error:
        log.exception("Failed to connect to the %s database: %s",
            sqlite_database['file'], error)
        sys.exit(1)
    else:
        log.info("Connected to SQLite database ...")


    # Verify that autocommit is turned off
    if sqlite_connection.isolation_level is None:
        log.warning("autocommit mode is enabled. This results in poor "
                    "performance when many updates are required.")
    else:
        log.debug("autocommit mode is disabled. "
                "This should help performance for large batches of updates")

    return sqlite_connection


def mysql_connect(mysqldb_details):
    """Open connection to MySQL database"""

    try:

        mysql_connection = mysql.connect(
            user=mysqldb_details['user'],
            password=mysqldb_details['pass'],
            host=mysqldb_details['host'],
            port=mysqldb_details['port'],
            database=mysqldb_details['name'],
            raise_on_warnings=True
        )

    except mysql.Error as error:
        log.exception("Unable to connect to database: %s", error)
        sys.exit(1)

    else:
        log.info("Connected to MySQL datbase ...")

    return mysql_connection


def postfix_query(db_type, search_string, table):
    """Ask Postfix to perform a lookup against db, capture the result"""

    if db_type not in VALID_DB_TYPES:
        raise ValueError("results: db_Type must be one of %r." % VALID_DB_TYPES)

    if ('file_suffix' in table) and (table['file_suffix'] is not None):

        log.debug("file_suffix is defined, attempting to use that file suffix")

        # Use override file suffix for special cases
        alias_input_file = "{}:/etc/postfix/{}/{}-{}.cf".format(
            db_type, db_type, db_type, table['file_suffix'])
    else:
        # The input files use suffixes that match table names

        log.debug("file_suffix not defined, using table name as file suffix")
        alias_input_file = "{}:/etc/postfix/{}/{}-{}.cf".format(
            db_type, db_type, db_type, table['name'])

    log.debug("Searching %s via postmap for %s", db_type, search_string)

    try:
        # NOTE: Do NOT strip whitespace from results; we will alert on that separately
        # TODO: Merge this check into the main script to help catch input errors
        # NOTE: Official doc does not indicate quoting should be used
        #       http://www.postfix.org/DATABASE_README.html
        # postfix_query_result = subprocess.check_output(
        #     "postmap -q '{}' {}".format(
        #         search_string.strip(), alias_input_file),
        #     stderr=subprocess.STDOUT,
        #     shell=True
        # ).decode("utf-8")

        postfix_query_result = subprocess.check_output(
            "postmap -q {} {}".format(
                search_string.strip(), alias_input_file),
            stderr=subprocess.STDOUT,
            shell=True
        ).decode("utf-8")

    except subprocess.CalledProcessError:
            #log.exception(error)

            raise

    else:
        log.debug("%s postfix_query_result type: %s",
            db_type, type(postfix_query_result))

        log.debug("%s postfix_query_result value: %s",
            db_type, postfix_query_result)

    return postfix_query_result


def validate_column_entry(entry):
    """Evaluate column entry for known issues, return a list"""

    concerns = []
    original_entry_length = len(entry)

    if original_entry_length != len(str(entry).lstrip()):
        concerns.append("leading_space")

    elif original_entry_length != len(str(entry).rstrip()):
        concerns.append('trailing_space')

    # TODO: Extend validation checks

    else:
        concerns = None

    return concerns


def process_concerns(concerns):
    """Receive list of validity concerns, perform actions on each"""

    if concerns is not None:
        for concern in concerns:
            if not concern in validation_concerns:
                log.error("%s is not in the list of validation errors.")
                raise ValueError("Unknown validation_concerns entry")
            else:
                log.warning("%s on %s", validation_concerns[concern], entry)
    else:
        log.error("Passed invalid list of concerns: %r", concerns)
        raise ValueError("Missing list of concerns to process")


def check_entry_status(db_type, cursor, entry, table, column):
    """Return field enabled/disable status"""

    if db_type not in VALID_DB_TYPES:
        raise ValueError("results: db_Type must be one of %r." % VALID_DB_TYPES)

    # The name of the column that controls whether an entry is visible
    status_column_name = 'enabled'

    log.debug("SELECT: Retrieve status for %s column in %s %s table",
            table[column], db_type, table['name'])

    try:
        cursor.execute("SELECT {} FROM {} WHERE {} = '{}'".format(
            status_column_name, table['name'], table[column], entry))

    # TODO: Need a more specific handler here
    except Exception as error:
        log.exception(error)
        raise

    else:
        log.debug(
            "OK: Retrieved list of %s column entries from %s %s table",
                table[column], table['name'], db_type)


    # Value/expected result is one entry, either 1 (default) or 0 (intentional)
    result = cursor.fetchall()

    if result:
        # grab first tuple from first list item, hopefully that is ALL
        # that was returned
        status = result[0][0]
        log.debug("Just assigned result[0][0] to status variable")
    else:
        status = result

    if status is None:
        log.error("empty query results")

        raise ValueError("Query returned zero results."
            " Recheck query, {} table entries for '{}' value",
            table['name'], entry)

    elif len(result) != 1:
        log.error("Expected one query result, received %d with values: %d."
            "Recheck query for %s in %s %s table",
            len(result), result, entry, table['name'], db_type)

        raise ValueError("Query returned unexpected results: {}"
            " Recheck query, {} table entries for '{}' value".format(result,
            table['name'], entry))

    # FIXME: There has to be a cleaner way of handling this
    elif int(status) not in [0, 1]:

        log.error("Expected either 1 or 0 as column values, received %d."
            "Recheck query for %s in %s %s table",
            status, entry, table['name'], db_type)

        raise ValueError("Query returned unexpected results: {}"
            " Recheck query, {} table entries for '{}' value".format(status,
            table['name'], entry))

    else:
        return bool(status)


def get_table_names(db_type, cursor):
    """"""

    if db_type not in VALID_DB_TYPES:
        raise ValueError("results: db_Type must be one of %r." % VALID_DB_TYPES)

    # Use values from VALID_DB_TYPES
    show_table_queries = {
        'sqlite': 'SELECT name FROM sqlite_master WHERE type=\'table\';',
        'mysql': 'SHOW TABLES;',
    }

    log.debug("Retrieving list of %s tables ...", db_type)

    try:
        cursor.execute(show_table_queries[db_type])

    # TODO: Need a more specific handler here
    except Exception as error:
        log.exception(error)
        raise

    else:
        log.debug(
            "OK: Retrieved list of %s tables", db_type)

    # FIXME: Need try/except block here
    result = cursor.fetchall()
    log.debug("Results of %s table list query: %r", db_type, result)

    if result:
        # grab first tuple from each list item
        # FIXME: There HAS to be a more elegant way to do this
        tables = [table[0] for table in result]
    else:
        log.debug("Unable to fetch list of tables from %s database", db_type)

        # TODO: Raise an exception of some kind here
        return None

    tables.sort()

    return tables


def get_column_entries(db_type, cursor, table, column):
    """Receive cursor, table name, return matching column entries"""

    if db_type not in VALID_DB_TYPES:
        raise ValueError("results: db_Type must be one of %r." % VALID_DB_TYPES)

    log.debug(
        "SELECT: %s column in %s %s table",
            table[column], db_type, table['name'])

    try:
        cursor.execute("SELECT {} FROM {}".format(
            table[column], table['name']))

    # TODO: Need a more specific handler here
    except Exception as error:
        log.exception(error)
        raise

    else:
        log.debug(
            "OK: Retrieved list of %s column entries from %s table",
                table[column], table['name'])


    # FIXME: Need try/except block here
    column_entries = cursor.fetchall()

    return column_entries


# TODO: Finish this function
def compare_postfix_query_results(results):
    """Compare results from two different postmap queries"""

    # Ideal situation
    if results[0] == results[1]:
        return (True, '[OK] Match found')

        # check for empty strings
        # check for only whitespace
        # check for other things worth noting
    else:

        # Perform query against source MySQL database to determine
        return (False, '')



# TODO: Configure formatter to log function/class info
file_formatter = logging.Formatter('%(asctime)s - %(name)s - L%(lineno)d - %(funcName)s - %(levelname)s - %(message)s')
stdout_formatter = logging.Formatter('%(levelname)s - L%(lineno)d - %(funcName)s - %(message)s')

# Grab root logger and set initial logging level
root_logger = logging.getLogger()
root_logger.setLevel(logging.INFO)

console_handler = logging.StreamHandler(stream=sys.stdout)
console_handler.setFormatter(stdout_formatter)
# Apply lax logging level since we will use a filter to examine message levels
# and compare against allowed levels set within the main config file. This
# filter is added later once the settings config object has been constructed.
console_handler.setLevel(logging.INFO)

file_handler = logging.FileHandler(app_name + '.log', mode='a')
file_handler.setFormatter(file_formatter)
file_handler.setLevel(logging.DEBUG)

# Create logger object that inherits from root and will be inherited by
# all modules used by this project
# Note: The console_handler is added later after the settings config object
# has been constructed.
app_logger = logging.getLogger(app_name)
app_logger.addHandler(file_handler)
app_logger.addHandler(console_handler)
app_logger.setLevel(logging.DEBUG)

log = app_logger.getChild(__name__)

log.debug("Logging initialized for %s", __name__)


########################################
# Modules - Third party
########################################

# Upstream module, actively maintained and official recommendation
# of the MariaDB project (per their documentation).
#
# Available via OS packages (including apt repo) or pip.
#
# Examples:
#
# * sudo apt-get install mysql-connector-python
# * pip install mysql-connector-python --user
log.debug("Attempting to import mysql.connector module")
import mysql.connector as mysql


####################################################################
# Open connections to databases
####################################################################

log.info("Opening connection to MySQL database")
mysql_connection = mysql_connect(mysql_database)
mysql_cursor = mysql_connection.cursor()

log.info("Opening connection to SQLite database")
sqlite_connection = sqlite_connect(sqlite_database)
sqlite_cursor = sqlite_connection.cursor()

tables_in_source_db = get_table_names('mysql', mysql_cursor)
if tables_in_source_db is None:
    log.error("Unable to retrieve list of tables from %s db; aborting!",
        'mysql')
    sys.exit(1)

# FIXME: This is busted logic? Should we loop over tables in the database or
# loop over tables in the INI file?
#
# Loop over each table in the database

# FIXME: Need to pull list of tables from INI file?
# For now, treat the table_mappings list as the authoratative list that
# we will process

log.debug("tables_in_source_db: %s", tables_in_source_db)
log.debug("table_mappings: %s", table_mappings)


tables_to_process = []
for table in table_mappings:
    if table['name'] in tables_in_source_db:
        tables_to_process.append(table)
    else:
        log.warning("Skipping table %s not listed in table_mappings")

log.info("Processing MySQL tables: %s", ", ".join([table['name'] for table in tables_to_process]))

for table in tables_to_process:

    log.info("Validating entries in %s ...", table['name'])

    # TODO: Perform key column validation, then value column validation
    # then finally perform postfix query validation on all entries that
    # passed earlier evaluation
    #
    # This should allow us to skip validation of any entries that have
    # already failed earlier known problem checks

    try:
        mysql_column_entries = get_column_entries(
            'mysql', mysql_cursor, table, 'key_column')

    # FIXME: Use a more specific exception handler here
    except Exception as error:
        log.exception(error)
        sys.exit(1)

    # Collapse list of single item tuples
    # FIXME: Better way to do this?
    mysql_column_entries = [x[0] for x in mysql_column_entries]

    # At this point we want to loop over the returned results and run postmap
    # using the values.
    for entry in mysql_column_entries:

        try:
            mysql_postfix_query_result = postfix_query(
                'mysql', entry, table)

        except subprocess.CalledProcessError as error:
            log.debug("Failed to run postmap query against %s", entry)
            log.debug("Output from postmap query: %s", error.output)

            entry_enabled = check_entry_status('mysql', mysql_cursor,
                entry, table, 'key_column')

            if not entry_enabled:
                log.info(
                    "[-] Confirmed: %s in %s %s table is disabled",
                    entry, 'mysql', table['name'])

                # FIXME
                # No point in checking the SQLite db if the MySQL entry
                # is disabled?
                # continue


        try:
            sqlite_postfix_query_result = postfix_query(
                'sqlite', entry, table)

        # FIXME: Need to be more specific here
        except subprocess.CalledProcessError as error:

            log.error("Error running postfix query: %s", error)
            log.info("Attempting to determine cause ...")

            mysql_entry_enabled = check_entry_status('mysql',
                mysql_cursor, entry, table, 'key_column')

            if not mysql_entry_enabled:
                log.info("[-] Confirmed: %s in %s %s table is disabled",
                    entry, 'mysql', table['name'])

            sqlite_entry_enabled = check_entry_status('sqlite',
                sqlite_cursor, entry, table, 'key_column')

            if not sqlite_entry_enabled:
                log.info("[-] Confirmed: %s in %s %s table is disabled",
                    entry, 'sqlite', table['name'])


            # Peform additional validation
            concerns = validate_column_entry(entry)
            process_concerns(concerns)

            # FIXME: Should we continue to the next entry or bomb out here?
            continue


        # First, make sure the two match. This is a base requirement.
        if mysql_postfix_query_result == sqlite_postfix_query_result:

            log.debug("Match on %s", entry)

        else:

            # Why didn't they match? Start with MySQL query result as that
            # is our "source" and is considered the authoritative source.

            log.warning("Mismatch between MySQL and SQLite db tables for %s",
                entry)

            # Check for empty result
            if mysql_postfix_query_result is None:

                log.warning("None type search result for %s", entry)

            elif not mysql_postfix_query_result:

                log.warning("Empty search result for %s", entry)

            # Not an empty search result, so why else are the two queries
            # not producing the same result?
            else:

                # TODO: We need to pull the actual entry from the SQLite db
                # to check its validity as well.

                # Peform additional validation
                concerns = validate_column_entry(entry)
                process_concerns(concerns)


log.info("Validation of tables is complete")

log.debug("Closing MySQL cursor")
mysql_cursor.close()

log.debug("Closing SQLite cursor")
sqlite_cursor.close()

# Close database connections
log.info("Closing MySQL database connection ...")
mysql_connection.close()

log.info("Closing SQLite database connection ...")
sqlite_connection.close()

log.info("Database connections closed")
