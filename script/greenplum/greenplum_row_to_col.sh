#!/bin/bash
###此脚本用于将行式业务报表同步至列式数据仓库
###开始时间与结束时间差必须大于定时任务执行间隔
source /usr/local/greenplum-db/greenplum_path.sh
###日志目录
logfile=/home/gpadmin/itp_tool/greenplum_row_to_col.log
###数据时间间隔可选【1 days】【1 hour】【1 min】
time_interval='1 hour'
start_time=`date -d "-${time_interval}" +"%Y-%m-%d %H:%M:00"`
end_time=`date +"%Y-%m-%d %H:%M:00"`


#数据库名
database_name='tyacc_tytest'
#查询条件
index_name=('createdAt')
#源模式
source_schema='AFC_ITP_BUSINESS'
#目标模式
target_schema='AFC_ITP_BIZ_COL'
#业务行式表
business_table=('app_pay_bills' 'devices' 'inout_records' 'mobile_pay_bills' 'mobile_pay_orders' 'mobile_pay_refundorders' 'orders' 'single_ticket_trip_records' 'single_tickets' 'stations' 'ticket_matrices' 'user_accounts' 'user_details' 'user_pay_accounts' 'user_phone_login')
#数仓列式表
dat_warehouse_table=('app_pay_bills' 'devices' 'inout_records' 'mobile_pay_bills' 'mobile_pay_orders' 'mobile_pay_refundorders' 'orders' 'single_ticket_trip_records' 'single_tickets' 'stations' 'ticket_matrices' 'user_accounts' 'user_details' 'user_pay_accounts' 'user_phone_login')


delete_old_data(){
	psql -d ${database_name} << EOF
\timing
DELETE 
FROM
	"${target_schema}"."${dat_warehouse_table[$i]}" 
WHERE
	"${target_schema}"."${dat_warehouse_table[$i]}"."${index}" > '${start_time}' 
	AND "${target_schema}"."${dat_warehouse_table[$i]}"."${index}" <= '${end_time}';
EOF

}

delete_updata_old_data(){
#对于存在有超过开始结束时间差的数据单独处理
#将有更新的数据通过行式表id查询出来匹配到列式表数据删除
	psql -d ${database_name} << EOF
\timing
DELETE
FROM
	"${target_schema}"."${dat_warehouse_table[$i]}" 
WHERE
	"id" IN (SELECT "id" FROM "${source_schema}"."${business_table[$i]}" WHERE "createdAt" < '${start_time}' AND "updatedAt" >= '${end_time}');
EOF
}

inset_new_data(){
	psql -d ${database_name} << EOF
\timing
INSERT INTO "${target_schema}"."${dat_warehouse_table[$i]}" 
SELECT
	"${source_schema}"."${business_table[$i]}".* 
FROM
	"${source_schema}"."${business_table[$i]}" 
WHERE
	"${source_schema}"."${business_table[$i]}"."${index}" > '${start_time}' 
	AND "${source_schema}"."${business_table[$i]}"."${index}" <= '${end_time}';
EOF
}

inset_updata_new_data(){
#对于存在有超过开始结束时间差的数据单独处理
#将有更新的数据通过行式表id查询出来插入到列式表
	psql -d ${database_name} << EOF
\timing
INSERT INTO "${target_schema}"."${dat_warehouse_table[$i]}" 
SELECT
	"${source_schema}"."${business_table[$i]}".* 
FROM
	"${source_schema}"."${business_table[$i]}" 
WHERE
    "createdAt" < '${start_time}' AND "updatedAt" >= '${end_time}';
EOF
}

start_run_time=`date`
echo "${start_run_time}" >>$logfile
i=0
for now_table in ${business_table[@]}
do
	index='createdAt'
	echo "deleting ${now_table} data" >>$logfile
	delete_old_data >>$logfile
	delete_updata_old_data >>$logfile
	echo "updating ${now_table} data" >>$logfile
	inset_new_data >>$logfile
	inset_updata_new_data >>$logfile
	((i++))
done
end_run_time=`date`
echo "${end_run_time}" >>$logfile
