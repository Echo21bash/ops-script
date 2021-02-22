#!/bin/bash
#auto exec vacuum full
#do not echo command, just get a list of db
source /usr/local/greenplum-db/greenplum_path.sh
exec=$1
log_file='/home/gpadmin/itp_tool/vacuum.log'
tables_file='/home/gpadmin/itp_tool/tables.txt'
dblist=`psql -d postgres -c "copy (select datname from pg_stat_database) to stdout"`
dblist=($dblist)
dblist=('tyacc_tytest' 'lcdb')
#申明关联数组
declare -A schema_name
schema_name=([tyacc_tytest]='AFC_ITP_BUSINESS AFC_ITP_SDK' [lcdb]='afc_business')
start_time=`date +'%Y-%m-%d %H:%M:%S'`

run_vacuum(){
if [[ -z $exec ]];then
    exec='VACUUM'
fi
for db in ${dblist[@]} ; do
    #skip system databases
    if [[ $db == template0 ]] ||  [[ $db == template1 ]] || [[ $db == postgres ]] || [[ $db == gpdb ]] ; then
        continue
    fi
        echo " 正在处理$db"
        #use a temp file to store the table list, which could be vary large
        >$tables_file
        #query out only the normal user tables, excluding partitions of parent tables
        schema_list=(${schema_name[$db]})
        for schema in ${schema_list[@]}
        do
                psql -d $db -c "copy (select '\"'||tables.schemaname||'\".' || '\"'||tables.tablename||'\"' from (select nspname as schemaname, relname as tablename from pg_catalog.pg_class, pg_catalog.pg_namespace, pg_catalog.pg_roles where pg_class.relnamespace = pg_namespace.oid and pg_namespace.nspowner = pg_roles.oid and pg_class.relkind='r' and (pg_namespace.nspname = '${schema}' or pg_roles.rolsuper = 'false' ) ) as tables(schemaname, tablename) left join pg_catalog.pg_partitions on pg_partitions.partitionschemaname=tables.schemaname and pg_partitions.partitiontablename=tables.tablename where pg_partitions.partitiontablename is null) to stdout;" >>$tables_file
        done
        while read line; do
                #some table name may contain the $ sign, so escape it
                line=`echo $line |sed 's/\\\$/\\\\\\\$/g'`
                #vacuum full this table, which will lock the table
				psql -d $db -e -a -c "$exec $line;" && psql -d $db -e -a -c "set lock_timeout = '3s';REINDEX TABLE $line;" &
        done <$tables_file
        #reindex system tables firstly
        psql -d $db -e -a -c "REINDEX SYSTEM $db;"
        #更新统计数据
        psql -d $db -e -a -c "ANALYZE VERBOSE;"

done
}

echo ${start_time} >>${log_file}
run_vacuum >>${log_file}
end_time=`date +'%Y-%m-%d %H:%M:%S'`
echo ${end_time} >>${log_file}
start_seconds=$(date --date="$starttime" +%s);
end_seconds=$(date --date="$endtime" +%s);
echo "本次运行时间："$((end_seconds-start_seconds))"s" >>${log_file}