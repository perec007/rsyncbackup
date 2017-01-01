#!/bin/bash



for i in "$@"
do
case $i in
    -u=*|--user=*)
    user="${i#*=}"
    shift # past argument=value
    ;;
    -s=*|--server=*)
    server="${i#*=}"
    shift # past argument=value
    ;;
    -p=*|--port=*)
    port="${i#*=}"
    shift # past argument=value
    ;;
    -k=*|--key=*)
    key="${i#*=}"
    shift # past argument with no value
    ;;
    --backupfs=*)
      backupfs="${i#*=}"
      shift
    ;;
    -t=*|--type=*)
      type="${i#*=}"
      shift
    ;;
    -e=*|--extparam=*)
      extparam="${i#*=}"
      shift
    ;;
    --password=*)
      password="${i#*=}"
      shift
    ;;
    --savepath=*)
      savepath="${i#*=}"
      shift
    ;;
    -h|--help)
      help=1
      shift
    ;;

    *)
        echo $i unknown option
    ;;
esac
done

printhelp() {
cat << EOF
params:     protocol: description:                                         
-t|--type   ssh|rsync type protocol                                            
-u|--user   ssh|rsync username (if remote)                                         
-s|--server ssh|rsync servername set local if backup localhost filesystem                                          
-p|--port   ssh|rsync if remote; ssh or rsyncd port                                            
--password     |rsync rsync auth password
-k|-key     ssh|      ssh key auth                                         
--backupfs  ssh|rsync filesystem over coma e.q. /,/boot, if rsync type - backupfs is modulename cfg file                                         
--exclude   ssh|rsync path file to excludefile                                         
--extparam  ssh|rsync external params to rsync
--savepath  ssh|rsync path to local backup dir
EOF
exit 
}

[[ $help -eq 1 ]] && printhelp
if [[ "$server" == "" || "$backupfs" == "" ]]; then
        echo Need params!
        printhelp
        exit 1
fi

savepath=/srv/bacula/rsyncbackup
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
                $extparam 2> $savepath/$server/log/rsync-error-$fs-$date.log
        ;;
        "rsync")
            export RSYNC_PASSWORD="$password"
            rsync $backupsrv:$backup $savepath/$server/latest-$fs \
                --one-file-system --delete \
                -A -H --archive --numeric-ids --partial \
                --exclude="/var/lib/docker/*" --exclude='*/.cache/*' --exclude='*/Cache/*' \
                $extparam 2> $savepath/$server/log/rsync-error-$fs-$date.log
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


