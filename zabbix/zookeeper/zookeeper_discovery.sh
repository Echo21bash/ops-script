#!/bin/bash
find_base_dir=/apps/base-env
home_dir=`find ${find_base_dir} -name zoo.cfg 2>/dev/null |awk -F "/conf/zoo.cfg" '{print $1}'`
deploy_mumber=`find ${find_base_dir} -name zoo.cfg 2>/dev/null |awk -F "/conf/zoo.cfg" '{print $1}'|wc -l`

i=1
ip=127.0.0.1
echo -e '{\n'
echo -e '\t"data":[\n'

for j in $home_dir
do
    base_dir=`echo "$j"|awk -F"/" '{print $(NF)}'`
    port=`cat "$j/conf/zoo.cfg"| grep clientPort | grep -oE [0-9]+`
    if [[ "$i" < "${deploy_mumber}" ]];then
       echo -e '\t\t{\n'
       echo -e "\t\t\t\"{#BASE_DIR}\":\"${base_dir}\",\n"
       echo -e "\t\t\t\"{#IP}\":\"${ip}\",\n"
       echo -e "\t\t\t\"{#PORT}\":\"${port}\"\n"
       echo -e '\t\t},'
    else
       echo -e '\t\t{\n'
       echo -e "\t\t\t\"{#BASE_DIR}\":\"${base_dir}\",\n"
       echo -e "\t\t\t\"{#IP}\":\"${ip}\",\n"
       echo -e "\t\t\t\"{#PORT}\":\"${port}\"\n"
       echo -e '\t\t}'
    fi
    let "i=i+1"
done

echo -e '\t]'
echo -e '}'
