#!/bin/bash
source /usr/local/greenplum-db/greenplum_path.sh
#logfile
logfile=/home/gpadmin/itp_tool/greenplum_row_to_col.log
#开始时间
#start_time=`date -d "1 days ago" +"%Y-%m-%d"`
start_time=`date +"%Y-%m-%d"`
#结束时间
#end_time=`date -d "1 days ago" +"%Y-%m-%d"`
end_time=`date +"%Y-%m-%d"`
start_created_time="${start_time} 00:00:00.000+08"
end_created_time="${end_time} 23:59:59.999+08"
#开始时间戳(s)
#start_timestamp=`date -d "${start_time} 00:00:00" +%s`
#结束时间戳(s)
#end_timestamp=`date -d "${end_time} 00:00:00" +%s`

#数据库名
database_name='tyacc_production'

#源模式
source_schema='AFC_ITP_BUSINESS'
#目标模式
target_schema='AFC_ITP_BIZ_COL'
#业务行式表
business_table=('app_pay_bills' 'devices' 'inout_records' 'mobile_pay_bills' 'mobile_pay_orders' 'mobile_pay_refundorders' 'orders' 'single_ticket_trip_records' 'single_tickets' 'stations' 'ticket_matrices' 'user_accounts' 'user_black_lists' 'user_details' 'user_keys' 'user_pay_accounts' 'user_phone_login')
#数仓列式表
dat_warehouse_table=('app_pay_bills' 'devices' 'inout_records' 'mobile_pay_bills' 'mobile_pay_orders' 'mobile_pay_refundorders' 'orders' 'single_ticket_trip_records' 'single_tickets' 'stations' 'ticket_matrices' 'user_accounts' 'user_black_lists' 'user_details' 'user_keys' 'user_pay_accounts' 'user_phone_login')


delete_old_data(){
	echo "deleting ${start_time}--->${end_time} ${target_schema}.${now_table} old data..."
	psql -d ${database_name} << EOF
\timing
delete FROM "${target_schema}"."${dat_warehouse_table[$i]}" WHERE "${target_schema}"."${dat_warehouse_table[$i]}"."createdAt" > '${start_created_time}' AND "${target_schema}"."${dat_warehouse_table[$i]}"."createdAt" <= '${end_created_time}';
EOF
}

inset_new_data(){
	echo "inseting ${start_time}--->${end_time} ${target_schema}.${now_table} new data..."
	psql -d ${database_name} << EOF
\timing
insert into "${target_schema}"."${dat_warehouse_table[$i]}" SELECT "${source_schema}"."${business_table[$i]}".* FROM "${source_schema}"."${business_table[$i]}" WHERE "${source_schema}"."${business_table[$i]}"."createdAt" > '${start_created_time}' AND "${source_schema}"."${business_table[$i]}"."createdAt" <= '${end_created_time}';
EOF
}

i=0
for now_table in ${business_table[@]}
do
	delete_old_data >>$logfile
	inset_new_data >>$logfile
	((i++))
done

