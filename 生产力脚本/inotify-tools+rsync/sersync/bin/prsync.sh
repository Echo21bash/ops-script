#!/bin/bash
set -o pipefail
# Usage:
#   rsync_parallel.sh [--parallel=N] [rsync args...]
# 
# Options:
#   --parallel=N	Use N parallel processes for transfer. Default is to use all available processors (`nproc`) or fail back to 10.
#
# Notes:
#   * Requires GNU Parallel
#   * Use with ssh-keys. Lots of password prompts will get very annoying.
#   * Does an itemize-changes first, then chunks the resulting file list and launches N parallel
#     rsyncs to transfer a chunk each.
#   * be a little careful with the options you pass through to rsync. Normal ones will work, you 
#     might want to test weird options upfront.
#

program=$(basename $0)
# Define colours for STDERR text
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 忽略错误码
rsync_ignore_exit_code=('24')

if [[ -z "$@" ]];then
	cat <<-EOF
	Usage:${program} [--parallel=N] [rsync args...]
	Options:
	  --parallel=N Use N parallel processes for transfer. 
	    Default is to use all available processors (`nproc`) or fail back to 10
	EOF
	exit
fi

if [[ "$1" == --parallel=* ]]; then
	PARALLEL_RSYNC="${1##*=}"
	if [[ -z "${PARALLEL_RSYNC}" ]];then
		PARALLEL_RSYNC=$(nproc 2> /dev/null || echo 10)
	fi
	shift
else
	PARALLEL_RSYNC=$(nproc 2> /dev/null || echo 10)
fi

echo -e "${GREEN}[INFO] Using up to ${PARALLEL_RSYNC} processes for transfer.${NC}"
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT
currentDate=$(date +%Y-%m-%d)
logsFile=${logs_dir:-${TMPDIR}}/${currentDate}_${remote_sync_dir:-non}_${rsyncd_ipaddr:-non}.rsync.log
SECONDS=0
echo -ne "${GREEN}[INFO] Determining file list for transfer ...${NC}"
# 获取发生改变的文件及目录，并按照目录排序
rsync "$@" --out-format="%l %n" --no-v --dry-run 2>> ${logsFile} > "${TMPDIR}/changed.all"
sort -k 2 "${TMPDIR}/changed.all" > "${TMPDIR}/files.all"
echo -e "${GREEN}DONE (${SECONDS}s)${NC}"

# 删除无效数据
sed -i -e '/\.\/$/d' -e '/^sending/d' "${TMPDIR}/files.all"

# 获取传输的文件数量及大小
TOTAL_FILES=$(wc -l < "${TMPDIR}/files.all")
TOTAL_SIZE=$(awk '{ts+=$1}END{printf "%.0f", ts}' < "${TMPDIR}/files.all")

# 输出传输的文件数量及大小，没有文件改变时退出程序
if [ "${TOTAL_FILES}" -eq "0" ]; then
	echo -e "${ORANGE}[WARN] Nothing to transfer :)${NC}"
	echo -e "${GREEN}[INFO] ${TOTAL_FILES} ($(( TOTAL_SIZE/1024**2 )) MB) files to transfer.${NC}"
	exit 0
else
	echo -e "${GREEN}[INFO] ${TOTAL_FILES} ($(( TOTAL_SIZE/1024**2 )) MB) files to transfer.${NC}"
fi

# 将更新列表和删除列表分开，因为更新和删除处理逻辑不一样
sed '/^deleting/d' "${TMPDIR}/files.all" | awk '{$1="";gsub(/^[[:space:]]+/, "");print$0}' > "${TMPDIR}/update.all"
sed '/^[0-9]/d' "${TMPDIR}/files.all" | awk '{$1="";gsub(/^[[:space:]]+/, "");print$0}' > "${TMPDIR}/delete.all"

# 将更新列表按照文件类型文件和目录分开，这样做为了处理重复数据
sed '/\/$/d' "${TMPDIR}/update.all" > "${TMPDIR}/updatefile.all"
sed '/\/$/!d' "${TMPDIR}/update.all" > "${TMPDIR}/updatedir.all"

# 将删除列表按照文件类型文件和目录分开，这样做为了处理重复数据
sed '/\/$/d' "${TMPDIR}/delete.all" > "${TMPDIR}/deletefile.all"
sed '/\/$/!d' "${TMPDIR}/delete.all" > "${TMPDIR}/deletedir.all"

# 更新文件时会自动创建目录，只需要刷选出只是创建了目录，筛选出不在文件更新列表的目录、创建了文件夹
while read dir
do
	if [[ -s "${TMPDIR}/updatefile.all" && -z $(grep "${dir}" "${TMPDIR}/updatefile.all") ]];then
		echo "${dir}" >> "${TMPDIR}/updatedirexe.all"
	fi
done < "${TMPDIR}/updatedir.all"

# 删除存在子目录关系的数据，只保留父目录，进一步减少同步操作
cp "${TMPDIR}/deletedir.all" "${TMPDIR}/deletedir.rsync"
while read dir
do
	basedir=$(echo "${dir}" | xargs basename )
	parentdir=$(echo "${dir}" | xargs dirname | xargs basename )
	if [[ ${parentdir} != "." ]];then
		grep -qE "${parentdir}$|${parentdir}/$" "${TMPDIR}/deletedir.all" && sed -i -e "/${parentdir}\/${basedir}$/d" -e "/${parentdir}\/${basedir}\/$/d" "${TMPDIR}/deletedir.rsync"
	fi
done < "${TMPDIR}/deletedir.all"

# 忽略已经存在删除文件夹操作的文件，有目录的删除就不需要单独删除文件
while read dir
do
	basedir=$(echo "${dir}" | sed -e 's/[]`!@#$%^&*(){}|\;:<>,. []/\\&/g' | xargs basename )
	if [[ -n "${basedir}" ]];then
		sed -i "/${basedir}/d" "${TMPDIR}/deletefile.all"
	fi
done < "${TMPDIR}/deletedir.all"

SECONDS=0
echo -ne "${GREEN}[INFO] Distributing files among chunks ...${NC}"
# declare chunk-size array
if [[ ${PARALLEL_RSYNC} > '1' ]];then
	CHUNKS_SUM=$((${PARALLEL_RSYNC}*2))
else
	CHUNKS_SUM="1"
fi

# 按照并发数的2倍分割数据文件
if [[ -s "${TMPDIR}/deletefile.all" ]];then
	rows_num=$(wc -l < "${TMPDIR}/deletefile.all")
	line_num=$((${rows_num}/${CHUNKS_SUM}))
	if [[ ${line_num} = "0" ]];then
		line_num="1"
	fi
	split -d -l ${line_num} "${TMPDIR}/deletefile.all" "${TMPDIR}/deletefile.f"
	# 按照并发数量生成多个include-from文件
	for file in `ls ${TMPDIR}/deletefile.f*`
	do
		awk -F '/' '{OFS="/"}{$NF="";print $0}' ${file} | awk '!a[$0]++' | sed 's/.$//g' > "${TMPDIR}/deleteTmp"
		while read dir
		do
			olddir=${dir}
			i=1
			while true
			do
				dirname=$(dirname "$dir" | head -1)
				if [[ $dirname != '.' ]];then
					include[$i]=$dirname/
					dir=$dirname
					echo "${include[$i]}">>"${TMPDIR}/deleteTmp.include"
				else
					include[$i]=${olddir}
					echo "${include[$i]}">>"${TMPDIR}/deleteTmp.include"
					break
				fi
				((i++))
			done
		done < "${TMPDIR}/deleteTmp"
		cat ${file} "${TMPDIR}/deleteTmp.include" > ${file}.include && rm -rf "${TMPDIR}/deleteTmp.include"
	done
fi

if [[ -s "${TMPDIR}/deletedir.rsync" ]];then
	rows_num=$(wc -l < "${TMPDIR}/deletedir.rsync")
	line_num=$((${rows_num}/${CHUNKS_SUM}))
	if [[ ${line_num} = "0" ]];then
		line_num="1"
	fi
	split -d -l ${line_num} "${TMPDIR}/deletedir.rsync" "${TMPDIR}/deletedir.d"
	# 按照并发数量生成多个include-from文件
	for file in `ls ${TMPDIR}/deletedir.d*`
	do
		awk -F '/' '{OFS="/"}{$NF="";print $0}' ${file} | awk '!a[$0]++' | sed 's/.$//g' > "${TMPDIR}/deleteTmp"
		while read dir
		do
			olddir=${dir}
			i=1
			while true
			do
				dirname=$(dirname "$dir" | head -1)
				if [[ $dirname != '.' ]];then
					include[$i]=$dirname/
					dir=$dirname
					echo "${include[$i]}">>"${TMPDIR}/deleteTmp.include"
				else
					include[$i]=${olddir}/***
					echo "${include[$i]}">>"${TMPDIR}/deleteTmp.include"
					break
				fi
				((i++))
			done
		done < "${TMPDIR}/deleteTmp"
		cat ${file} "${TMPDIR}/deleteTmp.include" > ${file}.include && rm -rf "${TMPDIR}/deleteTmp.include"
	done
fi

if [[ -s "${TMPDIR}/updatefile.all" ]];then
	rows_num=$(wc -l < "${TMPDIR}/updatefile.all")
	line_num=$((${rows_num}/${CHUNKS_SUM}))
	if [[ ${line_num} = "0" ]];then
		line_num="1"
	fi
	split -d -l ${line_num} "${TMPDIR}/updatefile.all" "${TMPDIR}/chunk.f"
fi

if [[ -s "${TMPDIR}/updatedirexe.all" ]];then
	rows_num=$(wc -l < "${TMPDIR}/updatedirexe.all")
	line_num=$((${rows_num}/${CHUNKS_SUM}))
	if [[ ${line_num} = "0" ]];then
		line_num="1"
	fi
	split -d -l ${line_num} "${TMPDIR}/updatedirexe.all" "${TMPDIR}/chunk.d"
fi
echo -e "${GREEN}DONE (${SECONDS}s)${NC}"

SECONDS=0
echo -ne "${GREEN}[INFO] Starting transfers ...${NC}"
find "${TMPDIR}" -type f -name "chunk.*" | xargs -I{} -P "${PARALLEL_RSYNC}" rsync --files-from={} "$@" 2>&1 | xargs -I{} echo {} >> ${logsFile}
# 将忽略的rsync错误码修改为0
rsync_exit_code=$?
if [[ ${rsync_exit_code} =~ ${rsync_ignore_exit_code} ]];then
    rsync_exit_code=0
fi
find "${TMPDIR}" -type f -name "*.include" | xargs -I{} -P "${PARALLEL_RSYNC}" rsync --include-from={} --exclude="*" "$@" 2>&1 | xargs -I{} echo {} >> ${logsFile}

# 将忽略的rsync错误码修改为0
rsync_exit_code=$?
if [[ ${rsync_exit_code} =~ ${rsync_ignore_exit_code} || ${rsync_exit_code} = "0" ]];then
    rsync_exit_code=0
    echo -e "${GREEN}DONE (${SECONDS}s)${NC}"
fi

if [[ -n ${logs_dir} ]];then
	if [[ -f ${logs_dir}/${currentDate}_${remote_sync_dir:-non}_${rsyncd_ipaddr:-non}.files.all ]];then
		cat "${TMPDIR}/files.all" >> ${logs_dir}/${currentDate}_${remote_sync_dir:-non}_${rsyncd_ipaddr:-non}.files.all
	else
		cp "${TMPDIR}/files.all" ${logs_dir}/${currentDate}_${remote_sync_dir:-non}_${rsyncd_ipaddr:-non}.files.all
	fi
fi
exit ${rsync_exit_code}