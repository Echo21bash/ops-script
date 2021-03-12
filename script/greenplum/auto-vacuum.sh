#!/bin/bash
#auto exec vacuum full
#do not echo command, just get a list of db
source /usr/local/greenplum-db/greenplum_path.sh
exec=$1
work_dir='/home/gpadmin/itp_tool'
log_file="${work_dir}/vacuum.log"
dblist=`psql -d postgres -c "copy (select datname from pg_stat_database) to stdout"`
dblist=($dblist)
dblist=('lcdb' 'tyacc_production')
#申明关联数组
declare -A schema_name
schema_name=([tyacc_production]='AFC_ITP_BUSINESS AFC_ITP_SDK AFC_ITP_BIZ_COL AFC_ITP_FACE' [lcdb]='afc_txn')


get_all_tables(){

	tables_file="${work_dir}/${db}_table_list.txt"
	>${tables_file}
	#skip system databases
	if [[ $db == template0 ]] || [[ $db == template1 ]] || [[ $db == postgres ]] || [[ $db == gpdb ]] ; then
		continue
	fi
		
	#query out only the normal user tables, excluding partitions of parent tables
	schema_list=(${schema_name[$db]})
	for schema in ${schema_list[@]}
	do
		psql -d $db -c "copy (select '\"'||tables.schemaname||'\".' || '\"'||tables.tablename||'\"' from (select nspname as schemaname, relname as tablename from pg_catalog.pg_class, pg_catalog.pg_namespace, pg_catalog.pg_roles where pg_class.relnamespace = pg_namespace.oid and pg_namespace.nspowner = pg_roles.oid and pg_class.relkind='r' and (pg_namespace.nspname = '${schema}' or pg_roles.rolsuper = 'false' ) ) as tables(schemaname, tablename) left join pg_catalog.pg_partitions on pg_partitions.partitionschemaname=tables.schemaname and pg_partitions.partitiontablename=tables.tablename where pg_partitions.partitiontablename is null) to stdout;" >>${tables_file}
	done


}

run_vacuum(){
	
	
	if [[ -z $exec ]];then
		exec='VACUUM'
	fi

		
	tables_file="${work_dir}/${db}_table_list.txt"
	while read line; do
		#some table name may contain the $ sign, so escape it
		line=`echo $line |sed 's/\\\$/\\\\\\\$/g'`
		#vacuum full this table, which will lock the table
		psql -d $db -L ${log_file} -e -a -c "$exec $line;" && \
		psql -d $db -L ${log_file} -e -a -c "set lock_timeout = '3s';REINDEX TABLE $line;" && \
		psql -d $db -L ${log_file} -e -a -c "ANALYZE $line;" &
	done <${tables_file}
		

	while true; do
		sleep 10
		proc=`psql -e -a -c "select * from pg_stat_activity;" | grep -oiE 'VACUUM|REINDEX|ANALYZE'`
		if [[ -z $proc ]];then
			return
		fi
	done
	
}

run_ctrl(){

	
	for db in ${dblist[@]} ; do
		get_all_tables >>${log_file}
		start_time=`date +'%Y-%m-%d %H:%M:%S'`
		start_seconds=$(date --date="$start_time" +%s);
		run_vacuum >>${log_file}
		end_time=`date +'%Y-%m-%d %H:%M:%S'`
		end_seconds=$(date --date="$end_time" +%s);
		echo "本次VACUUM ${db} 运行时间："$((end_seconds-start_seconds))"s" >>${log_file}
	done
	
}

main(){

	start_run_time=`date +'%Y-%m-%d %H:%M:%S'`
	echo ${start_run_time} >>${log_file}
	run_ctrl
	end_run_time=`date +'%Y-%m-%d %H:%M:%S'`
	echo ${end_run_time} >>${log_file}
	start_seconds=$(date --date="$start_run_time" +%s);
	end_seconds=$(date --date="$end_run_time" +%s);
	echo "本次总运行时间："$((end_seconds-start_seconds))"s" >>${log_file}

}

main
