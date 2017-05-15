#!/bin/bash

dir=`dirname $0`
$rsyncpram="--one-file-system --delete -HAX --partial --stats --numeric-ids"

# include config
[ -f $dir/config ] && . $dir/config

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
-p|--port   ssh|rsync no    if remote; ssh or rsyncd port                                            
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
    logzbx=$savepath/zabbix-alert.log
    logbackup=$savepath/$fservername/latest-$fs/errorsbackup.log
    logglobal=$savepath/errorsbackup.log

    printf "%s" "start backup $fs on $fservername:"
    printf "%s" "type:$type. Start rsync..."

    mkdir -p $savepath/$fservername/latest-$fs


   [[ "$type" == "rsync" && "$port" != "" ]] && backupsrv="rsync://$user@$server:$port/"
   [[ "$type" == "rsync" && "$port" == "" ]] && backupsrv="rsync://$user@$server/"
   [[ "$type" == "ssh" ]]   && backupsrv="$user@$server:"
   [[ "$type" == "local" || "$server" == "local" ]] && backupsrv="" && type="ssh"

   
   case $type in 
        "ssh")
            port="-p $port"
            $sudo rsync $backupsrv$backup $savepath/$fservername/latest-$fs \
                -e "ssh $port -i $key" \
                $rsyncparam $exclude $include \
                $ext >> /tmp/$$.log  2>&1 
                exitrsync=$?
                mv -f /tmp/$$.log $logbackup 
        ;;
        "rsync")
            export RSYNC_PASSWORD="$password"
            $sudo rsync $backupsrv$backup $savepath/$fservername/latest-$fs \
                $rsyncparam $exclude $include \
                $ext >> /tmp/$$.log  2>&1 
                exitrsync=$?
                mv -f /tmp/$$.log $logbackup 
        ;;
    esac

    echo $okerr | grep -q $exitrsync && exitrsync=0 # check exit code and fix if ok
    [ $exitrsync -ne 0 ] && \
    echo "Error: Exit rsync code: $exitrsync: see log $logbackup"  | tee -a $logglobal >> $logzbx  

    if [ $exitrsync -eq 0 ]; then
        printf "%s" "du latest-$fs... "
        rm -f $savepath/$fservername/latest-$fs/du.txt
        ducount "$savepath/$fservername/latest-$fs" "$savepath/$fservername/latest-$fs/du.txt"  
       
        printf "%s" "du all $fs... "
        rm -f $savepath/$fservername/latest-$fs/du-all.txt
        ducount "$savepath/$fservername/$fs-* $savepath/$fservername/latest-$fs" "$savepath/$fservername/latest-$fs/du-all.txt" 
        

        printf "%s" "cp... "
        mkdir -p $savepath/$fservername/$fs-$date

        cp --link --archive $savepath/$fservername/latest-$fs/* $savepath/$fservername/$fs-$date/ 2>&1 >> $logbackup   
        exitcp=$?
        [ $exitcp -ne 0 ] && echo "Error: Exit cp code: $exitcp: see log $logbackup"  | tee -a $logglobal >> $logzbx 
        
    else
        printf "%s" "ERROR: rsync exit code: $exitrsync: Not run cp!"
        echo "cp not run see log $logbackup"  | tee -a $logglobal >> $logzbx 
    fi

    printf "%s\n" "done. "
done


