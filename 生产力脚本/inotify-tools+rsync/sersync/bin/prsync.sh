#!/bin/bash
set -e
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

rsync_ignore_exit_code=('24')
rsync_ignore_out='vanished'

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


echo -e "${GREEN}[INFO] Using up to ${PARALLEL_RSYNC} processes for transfer ...${NC}"
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo -e "${GREEN}[INFO] Determining file list for transfer ...${NC}"
# sorted by size (descending)
rsync "$@" --out-format="%l %n" --no-v --dry-run 2> /dev/null \
  | sort --numeric-sort --reverse \
  > "${TMPDIR}/files.all"

# check for nothing-to-do
TOTAL_FILES=$(wc -l < "${TMPDIR}/files.all")
TOTAL_SIZE=$(awk '{ts+=$1}END{printf "%.0f", ts}' < "${TMPDIR}/files.all")
echo -e "${GREEN}[INFO] ${TOTAL_FILES} ($(( TOTAL_SIZE/1024**2 )) MB) files to transfer.${NC}"
if [ "${TOTAL_FILES}" -eq "0" ]; then
	echo -e "${ORANGE}[WARN] Nothing to transfer :)${NC}"
	exit 0
fi


# 将更新列表和删除列表分开
sed '/^deleting/d' "${TMPDIR}/files.all" > "${TMPDIR}/update.all"
sed '/^[0-9]/d' "${TMPDIR}/files.all" > "${TMPDIR}/delete.all"

# 将更新列表按照文件和目录分开
sed '/\/$/d' "${TMPDIR}/update.all" > "${TMPDIR}/updatefile.all"
sed '/\/$/!d' "${TMPDIR}/update.all" > "${TMPDIR}/updatedir.all"

# 将删除列表按照文件和目录分开
sed '/\/$/d' "${TMPDIR}/delete.all" > "${TMPDIR}/deletefile.all"
sed '/\/$/!d' "${TMPDIR}/delete.all" > "${TMPDIR}/deletedir.all"

# 筛选出不在文件更新列表的目录、只是创建了文件夹
while read size dir
do
	if [[ -s "${TMPDIR}/updatefile.all" && -z $(grep "${dir}" "${TMPDIR}/updatefile.all") ]];then
		echo "${size} ${dir}" >> "${TMPDIR}/updatedirexe.all"
	fi
done < "${TMPDIR}/updatedir.all"

# 忽略已经删除文件夹的文件
while read size dir
do
	basedir=$(echo "${dir}" | sed -e 's/[]`!@#$%^&*(){}|\;:<>,. []/\\&/g' | xargs basename )
	if [[ -n "${basedir}" ]];then
		sed -i "/${basedir}/d" "${TMPDIR}/deletefile.all"
	fi
done < "${TMPDIR}/deletedir.all"

SECONDS=0
echo -e "${GREEN}[INFO] Distributing files among chunks ...${NC}"
# declare chunk-size array
if [[ ${PARALLEL_RSYNC} > '1' ]];then
	CHUNKS_SUM=$((${PARALLEL_RSYNC}*2))
else
	CHUNKS_SUM="1"
fi

# 按照并发数量生成多个include-from文件
j=1
while read size dir
do
	olddir=${dir}
	type=$(echo -n "${dir}" | grep -oE "/$" || true)
	i=1
	result=$((${j} % ${CHUNKS_SUM}))
	while true
	do
		dirname=$(dirname "$dir" | head -1)
		if [[ $dirname != '.' ]];then
			include[$i]=$dirname
			dir=$dirname
			echo "${include[$i]}">>"${TMPDIR}/deleteTmp.${result}"
			
		else
			if [[ $type = '/' ]];then
				#目录被删除时，同时删除目录下的所有文件
				include[$i]=${olddir}***
			else
				include[$i]=${olddir}
			fi
			echo "${include[$i]}">>"${TMPDIR}/deleteTmp.${result}"
			break
		fi
		((i++))
	done
	((j++))
done < <( cat "${TMPDIR}/deletefile.all" "${TMPDIR}/deletedir.all")

for ((i=0;i<"${CHUNKS_SUM}";i++))
do
	if [[ -s "${TMPDIR}/deleteTmp.${i}" ]];then
		sort -u "${TMPDIR}/deleteTmp.${i}" > "${TMPDIR}/delete.${i}"
	fi
done


if [[ -s "${TMPDIR}/updatefile.all" ]];then
	i=1
	while read -r FSIZE FPATH;
	do
		result=$((${i}" % "${CHUNKS_SUM}))
		echo "${FPATH}" >> "${TMPDIR}/chunk.${result}"
		((i++))
	done < "${TMPDIR}/updatefile.all"
fi

if [[ -s "${TMPDIR}/updatedirexe.all" ]];then
	i=1
	while read -r FSIZE FPATH;
	do
		result=$((${i} % ${CHUNKS_SUM}))
		echo "${FPATH}" >> "${TMPDIR}/chunk.${result}"
		((i++))
	done < "${TMPDIR}/updatedirexe.all"
fi
echo -e "${GREEN}DONE (${SECONDS}s)${NC}"

SECONDS=0
echo -e "${GREEN}[INFO] Starting transfers ...${NC}"
find "${TMPDIR}" -type f -name "chunk.*" | xargs -I{} -P "${PARALLEL_RSYNC}" rsync --files-from={} "$@" 2>&1 | (grep -Ev "${rsync_ignore_out}" || true) || \
find "${TMPDIR}" -type f -name "delete.*" | xargs -I{} -P "${PARALLEL_RSYNC}" rsync --include-from={} --exclude="*" "$@" 2>&1 | (grep -Ev "${rsync_ignore_out}" || true) 
echo -e "${GREEN}DONE (${SECONDS}s)${NC}"


