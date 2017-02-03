#!/bin/bash

# include config 
[ -f `dirname @0`/config ] && . `dirname @0`/config
zbxalertlog=$savepath/zabbix-alert.log

for i in "$@"
do
case $i in
    -u=*|--user=*)
    user="${i#*=}"
    ;;
    -s=*|--server=*)
    server="${i#*=}"
    ;;
    -p=*|--port=*)
    port="${i#*=}"
    ;;
    -k=*|--key=*)
    key="${i#*=}"
    ;;
    --backupfs=*)
      backupfs="${i#*=}"
    ;;
    --exclude=*)
      exclude="--delete-excluded --exclude-from=${i#*=}"
    ;;
    --include=*)
      include="--include-from=${i#*=}"
    ;;
    -t=*|--type=*)
      type="${i#*=}"
    ;;
    -e=*|--ext=*)
      ext="${i#*=}"
    ;;
    --password=*)
      password="${i#*=}"
    ;;
    --savepath=*)
      savepath="${i#*=}"
    ;;
    --prefix=*)
      prefix="${i#*=}"
    ;;
    "--sudo=yes")
      sudo="sudo -E"
	;;
    -ok=*|--okerr=*)
      okerr="${i#*=}"
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
-t|--type   ssh|rsync yes   type protocol                                          
-u|--user   ssh|rsync yes   username (if remote)                                         
-s|--server ssh|rsync yes   servername set local if backup localhost filesystem 
-prefix     ssh|rsync no    prefix servername - need to human readable save path
-p|--port   ssh|      yes   if remote; ssh or rsyncd port                                            
--password     |rsync no    rsync auth password
-k|-key     ssh|      yes   ssh key auth                                         
--backupfs  ssh|rsync yes   filesystem over coma e.q. /,/boot, if rsync type - backupfs is modulename cfg file                                         
--exclude   ssh|rsync no    path file to excludefile 
--include   ssh|rsync no    path file to includefile 
-e|--ext    ssh|rsync no    external params to rsync
--savepath  ssh|rsync yes   path to local backup dir
-ok|--okerr    |rsync no    normal rsync exit code, not 0 
-h|--help   ssh|rsync no    print this help
--sudo      ssh|      no    Set yes if need use local sudo rsync
EOF
exit 
}


[[ $help -eq 1 ]] && printhelp
#if backup localfs - need use format command rsync of ssh
[[ "$type" == "local" ]] && type=ssh


#check params
for i in "$backupfs"  "$savepath" "$backupfs" "$server" "$type"
do
    cnt=$((cnt+1))
    if [[ "$i" == ""  ]]; then
        echo Mandatory param $cnt is empty. Need params: "backupfs savepath backupfs server type" 
        exit 1
    fi
done




. `dirname $0`/function


for backup in `echo $backupfs | sed "s/,/\ /g"`; do
    fs=`fsname $backup`
    latestfslog=$savepath/$fservername/latest-$fs/errorsbackup.log

    printf "%s" "start backup $fs on $fservername:"
    printf "%s" "type:$type. Start rsync..."

    mkdir -p $savepath/$fservername/latest-$fs

    case $type in 
        "ssh")
            $sudo rsync $backupsrv$backup $savepath/$fservername/latest-$fs \
                -e "ssh -p $port -i $key" \
                --one-file-system --delete \
                -A -H --archive --numeric-ids \
                $exclude $include \
                $ext 2>&1 | tee -a $latestfslog >> $zbxalertlog
                exitrsync=$?
        ;;
        "rsync")
            export RSYNC_PASSWORD="$password"
            $sudo rsync $backupsrv:$backup $savepath/$fservername/latest-$fs \
                --one-file-system --delete \
                -A -H --archive --numeric-ids \
                $exclude $include \
                $ext 2>&1 | tee -a $latestfslog >> $zbxalertlog            
                exitrsync=$?
        ;;
    esac

    echo $okerr | grep -q $exitrsync && exitrsync=0 # check exit code and fix if ok
    if [ $exitrsync -ne 0 ]; then
      echo "Exit rsync code is $exitrsync. Backup name: $fservername/latest-$fs Check Log!" | tee -a $latestfslog >> $zbxalertlog  
      echo "$date $fservername rsync error on $backup" | tee -a $latestfslog >> $zbxalertlog
    fi    

    if [ $exitrsync -eq 0 ]; then
        printf "%s" "du latest-$fs... "
        rm -f $savepath/$fservername/latest-$fs/du.txt
        ducount "$savepath/$fservername/latest-$fs" "$savepath/$fservername/latest-$fs/du.txt"  || ( echo error du; exit 1 )
        
        printf "%s" "du all $fs... "
        rm -f $savepath/$fservername/latest-$fs/du-all.txt
        ducount "$savepath/$fservername/$fs-* $savepath/$fservername/latest-$fs" "$savepath/$fservername/latest-$fs/du-all.txt" || ( echo error du-all; exit 1 )
        

        printf "%s" "cp... "
        mkdir -p $savepath/$fservername/$fs-$date

        cp --link --archive $savepath/$fservername/latest-$fs/* $savepath/$fservername/$fs-$date/ 2>&1 | tee -a $latestfslog >> $zbxalertlog  
        exitcp=$?
        if [ $exitcp -eq 0 ]; then
          printf "%s" "cp ok. Path: $savepath/$fservername/$fs-$date. "
        else
          echo "Exit cp code $exitcp. Check Log!" | tee -a $latestfslog >> $zbxalertlog
        fi
    else
        printf "%s" "ERROR: rsync exit code: $exitrsync: Not run cp!"
    fi

    printf "%s\n" "done. "
done


