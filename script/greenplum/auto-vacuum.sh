#!/bin/bash
#auto exec vacuum full
#do not echo command, just get a list of db
dblist=`psql -d postgres -c "copy (select datname from pg_stat_database) to stdout"`
dblist=($dblist)
dblist=('tyacc_production')
schema_name=('AFC_ITP_BUSINESS')
for db in ${dblist[@]} ; do
    #skip system databases
    if [[ $db == template0 ]] ||  [[ $db == template1 ]] || [[ $db == postgres ]] || [[ $db == gpdb ]] ; then
        continue
    fi
	echo processing db "$db"
	#do a normal vacuum
	psql -d $db -e -a -c "VACUUM;"
	#reindex system tables firstly
	psql -d $db -e -a -c "REINDEX SYSTEM $db;"
	#use a temp file to store the table list, which could be vary large
	cp /dev/null tables.txt
	#query out only the normal user tables, excluding partitions of parent tables
	for schema in ${schema_name[@]}
	do
		psql -d $db -c "copy (select '\"'||tables.schemaname||'\".' || '\"'||tables.tablename||'\"' from (select nspname as schemaname, relname as tablename from pg_catalog.pg_class, pg_catalog.pg_namespace, pg_catalog.pg_roles where pg_class.relnamespace = pg_namespace.oid and pg_namespace.nspowner = pg_roles.oid and pg_class.relkind='r' and (pg_namespace.nspname = '${schema}' or pg_roles.rolsuper = 'false' ) ) as tables(schemaname, tablename) left join pg_catalog.pg_partitions on pg_partitions.partitionschemaname=tables.schemaname and pg_partitions.partitiontablename=tables.tablename where pg_partitions.partitiontablename is null) to stdout;" > tables.txt
	done
	while read line; do
		#some table name may contain the $ sign, so escape it
		line=`echo $line |sed 's/\\\$/\\\\\\\$/g'`
		echo processing table "$line"
		#vacuum full this table, which will lock the table
		psql -d $db -e -a -c "VACUUM FULL $line;"
		#reindex the table to reclaim index space
		psql -d $db -e -a -c "REINDEX TABLE $line;"
	done <tables.txt

done
