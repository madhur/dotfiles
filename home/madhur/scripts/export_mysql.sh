# Export all databases except system databases
# First get the list of databases excluding system DBs
DATABASES=$(mysql -h 127.0.0.1 -u root -p -ANe "SELECT GROUP_CONCAT(schema_name SEPARATOR ' ') FROM information_schema.schemata WHERE schema_name NOT IN ('mysql','information_schema','performance_schema','sys')")

# Then use that list in mysqldump
mysqldump -u root -h 127.0.0.1 -p \
--single-transaction \
--master-data=2 \
--routines \
--triggers \
--events \
--databases $DATABASES > all_user_databases.sql
