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

TIMENOW=`date '+%s'`
DUCACHE_REAL=/tmp/backup-du-l.cache
DUCACHE_ONHDD=/tmp/backup-du-h.cache
touch $DUCACHE_REAL
let TTLCACHE=60*60*12

##### CACHE #####

if [ -f /tmp/backup-rotate.lock ]; then
 find /tmp/backup-rotate.lock  -cmin +720 -delete
 echo "Locking by lockfile! Sleep 10 min and rerun $0 $@"
 sleep 600
 $0 $@
fi

if [ -s "${DUCACHE_REAL}" ]; then
  TIMECACHE=`stat -c"%Z" "${DUCACHE_REAL}"`
else
  TIMECACHE=0
fi
if [ "$((${TIMENOW} - ${TIMECACHE}))" -gt "${TTLCACHE}" ]; then
  echo "" >> ${DUCACHE_REAL} 
  touch /tmp/backup-rotate.lock
  DATACACHE_REAL=`du --max-depth=2 $savepath` || exit 1
  DATACACHE_ONHDD=`du -l --max-depth=2 $savepath` || exit 1
  echo "${DATACACHE_REAL}" > ${DUCACHE_REAL}
  echo "${DATACACHE_ONHDD}" > ${DUCACHE_ONHDD}
  rm -f /tmp/backup-rotate.lock
fi

cat $DUCACHE_REAL | awk  '{ sum += $1 }; END { print "TOTAL ON REAL DISK USED: "sum/1024/1024"Gb" }'
cat $DUCACHE_ONHDD | awk  '{ sum += $1 }; END { print "TOTAL ON HARDLINKS DISK USED: "sum/1024/1024"Gb" }'


fservername=$server
[ ! -z $prefix ] && fservername=$prefix-$server

for backup in `echo $backupfs | sed "s/,/\ /g"`; do
    if [ $backup == "/" ]; then
        fs=root
    else
        fs=`echo $backup | sed "s,/,-,g; s,^-,/,g; s,-$,/,g"`
    fi

    cat $DUCACHE_ONHDD | grep "$fservername/$fs"| awk -v "bckp=$fservername/$fs" '{ sum += $1 }; END { print "TOTAL USED BACKUP " bckp " : "sum/1024/1024"Gb" }'

    # backups=`ls $savepath/$fservername/$fs-*|grep :$|sed "s/://g; s,.*/,,g"|sort -r`
    # for i in $backups; do
    # 	cat $DUCACHE_REAL | grep $i
    # done
done



