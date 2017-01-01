#!/bin/bash



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
-u|--user   ssh|rsync no    username (if remote)                                         
-s|--server ssh|rsync yes   servername set local if backup localhost filesystem                                          
-p|--port   ssh|rsync no    if remote; ssh or rsyncd port                                            
--password     |rsync no    rsync auth password
-k|-key     ssh|      no    ssh key auth                                         
--backupfs  ssh|rsync yes   filesystem over coma e.q. /,/boot, if rsync type - backupfs is modulename cfg file                                         
--exclude   ssh|rsync no    path file to excludefile                                         
-e|--ext    ssh|rsync no    external params to rsync
--savepath  ssh|rsync yes   path to local backup dir
-h|--help   ssh|rsync no    print this help
EOF
exit 
}

[[ $help -eq 1 ]] && printhelp
if [[ "$server" == "" || "$backupfs" == "" || -z $savepath || -z $backupfs || -z $server || -z type ]]; then
        echo Need mandatory params! Use --help options.
        exit 1
fi


date=`date +%F--%H-%M`

for backup in `echo $backupfs | sed "s/,/\ /g"`; do
    if [ $backup == "/" ]; then
        fs=root
    else
        fs=`echo $backup | sed "s,/,-,g; s,^-,,g"`
    fi
    [[ "$type" == "ssh" && $server == "local" ]] && backupsrv="" || backupsrv="$user@$server:" 
    mkdir -p $savepath/$server/latest-$fs $savepath/$server/log $savepath/$server/$fs-$date
    touch $savepath/reporterror.log

    printf "%s" "start backup $fs on $server:"
    printf "%s" "start type:$type rsync..."
    case $type in 
        "ssh")
            rsync $backupsrv$backup $savepath/$server/latest-$fs \
                -e "ssh -p $port -i $key" --rsync-path="sudo rsync" \
                --one-file-system --delete \
                -A -H --archive --numeric-ids --partial \
                --exclude="/var/lib/docker/*" --exclude='*/.cache/*' --exclude='*/Cache/*' \
                $ext 2> $savepath/$server/log/rsync-error-$fs-$date.log
        ;;
        "rsync")
            export RSYNC_PASSWORD="$password"
            rsync $backupsrv:$backup $savepath/$server/latest-$fs \
                --one-file-system --delete \
                -A -H --archive --numeric-ids --partial \
                --exclude="/var/lib/docker/*" --exclude='*/.cache/*' --exclude='*/Cache/*' \
                $ext 2> $savepath/$server/log/rsync-error-$fs-$date.log
        ;;
    esac
    if [ $? -ne 0 ]; then
      echo exit 'Exit rsync code is not 0. Check Log!' | tee -a $savepath/$server/log/errors-$fs-$date.log 
      echo "$date rsync error on $fs $backupsrv$backup" >> $savepath/reporterror.log
    fi
    printf "%s" "done. "
    printf "%s" "start cp... "
    cp --link --archive $savepath/$server/latest-$fs/* $savepath/$server/$fs-$date/ 2>> $savepath/$server/log/errors-$fs-$date.log 
    if [ $? -ne 0 ]; then
      echo exit 'Exit cp code is not 0. Check Log!' | tee -a $savepath/$server/log/errors-$fs-$date.log 
      echo "$date cp error on $fs $backupsrv$backup" >> $savepath/reporterror.log
    fi
    printf "%s\n" "done. "
done


