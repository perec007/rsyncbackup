#!/bin/bash


for i in "$@"
do
case $i in
    -s=*|--server=*)
    server="${i#*=}"
    ;;
    --backupfs=*)
      backupfs="${i#*=}"
    ;;
    --savepath=*)
      savepath="${i#*=}"
    ;;
    --prefix=*)
      prefix="${i#*=}"
    ;;
    --sizebackup=*)
	  sizebackup="${i#*=}"
	;;
    "--sudo=yes")
      sudo="sudo -E"
	;;
    -h|--help)
      help=1
    ;;

    *)
        echo $i unknown option
    ;;
esac
done

printhelp() {
cat << EOF
params:     protocol: need: description:                                         
-s|--server ssh|rsync yes   servername set local if backup localhost filesystem 
-prefix     ssh|rsync no    prefix servername - need to human readable save path
--backupfs  ssh|rsync yes   filesystem over coma e.q. /,/boot, if rsync type - backupfs is modulename cfg file                                         
--savepath  ssh|rsync yes   path to local backup dir
--sudo      ssh|      no    Set yes if need use local sudo rsync
-h|--help   ssh|rsync no    print this help
EOF
exit 
}

[[ $help -eq 1 ]] && printhelp
if [[ "$server" == "" || "$backupfs" == "" || -z $savepath || -z $backupfs || -z $server || -z type ]]; then
        echo Need mandatory params! Use --help options.
        exit 1
fi

if [ $backupfs == "/" ]; then
    fs=root
else
    fs=`echo $backupfs | sed "s,/,-,g; s,^-,,g; s,-$,,g"`
fi

fservername=$server
[ ! -z $prefix ] && fservername=$prefix-$server

TIMENOW=`date '+%s'`
DUCACHE="/tmp/backup-du-$fs.cache"
touch $DUCACHE
let TTLCACHE=60*60*12

##### CACHE #####

if [ -f /tmp/backup-rotate-$fs.lock ]; then
 find /tmp/backup-rotate-$fs.lock  -cmin +720 -delete
 echo "Locking by lockfile! Sleep 10 min and rerun $0 $@"
 sleep 600
 $0 $@
fi

if [ -s "${DUCACHE}" ]; then
  TIMECACHE=`stat -c"%Z" "${DUCACHE}"`
else
  TIMECACHE=0
fi

DATACACHE_FILE="/tmp/backup-du-$fs-$prefix-$fservername.cache.txt"
DATACACHE_LATEST_FILE="/tmp/backup-du-$fs-$prefix-$fservername.cache_latest.txt"

if [ "$((${TIMENOW} - ${TIMECACHE}))" -gt "${TTLCACHE}" ]; then
  echo "" >> ${DUCACHE} 
  touch /tmp/backup-rotate-$fs.lock
  DATACACHE=`du -s $savepath/$fservername/latest-$fs $savepath/$fservername/$fs-* | awk '{  sum += $1 }; END { print sum }'` || exit 1
  DATACACHE_LATEST=`du -s $savepath/$fservername/latest-$fs | awk '{ print $1 }'` || exit 1
  # DATACACHE=10000
  # DATACACHE_LATEST=1000000
  echo "${DATACACHE}" > "${DATACACHE_FILE}" 
  echo "${DATACACHE_LATEST}" > "${DATACACHE_LATEST_FILE}" 

rm -f /tmp/backup-rotate-$fs.lock
fi

cat $DATACACHE_FILE | awk  '{ sum += $1 }; END { print "TOTAL ON REAL DISK USED: "sum/1024/1024"Gb" }'
cat $DATACACHE_LATEST_FILE | awk  '{ sum += $1 }; END { print "TOTAL LATEST DISK USED: "sum/1024/1024"Gb" }'

for cleandir in `echo $savepath/$fservername/$fs-* |sort`; do
  echo $cleandir
done

