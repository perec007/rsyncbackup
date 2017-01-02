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
    --exclude=*)
      exclude="--delete-excluded --exclude-from=${i#*=}"
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
-e|--ext    ssh|rsync no    external params to rsync
--savepath  ssh|rsync yes   path to local backup dir
-h|--help   ssh|rsync no    print this help
--sudo      ssh|      no    Set yes if need use local sudo rsync
EOF
exit 
}

[[ $help -eq 1 ]] && printhelp
if [[ "$server" == "" || "$backupfs" == "" || -z $savepath || -z $backupfs || -z $server || -z type ]]; then
        echo Need mandatory params! Use --help options.
        exit 1
fi

fservername=$server
[ ! -z $prefix ] && fservername=$prefix-$server

date=`date +%F--%H-%M`

for backup in `echo $backupfs | sed "s/,/\ /g"`; do
    if [ $backup == "/" ]; then
        fs=root
    else
        fs=`echo $backup | sed "s,/,-,g; s,^-,,g; s,-$,,g"`
    fi

    printf "%s" "start backup $fs on $fservername:"
    printf "%s" "start type:$type rsync..."

    if [ $server == "local" ]; then
      backupsrv="" 
      type=ssh
    else
      backupsrv="$user@$server:" 
    fi

    mkdir -p $savepath/$fservername/latest-$fs $savepath/$fservername/log $savepath/$fservername/$fs-$date
    touch $savepath/reporterror.log

    case $type in 
        "ssh")
            $sudo rsync $backupsrv$backup $savepath/$fservername/latest-$fs \
                -e "ssh -p $port -i $key" --rsync-path="sudo rsync" \
                --one-file-system --delete \
                -A -H --archive --numeric-ids --partial \
                $exclude \
                $ext 2> $savepath/$fservername/log/errors-$fservername-$fs-$date.log
        ;;
        "rsync")
            export RSYNC_PASSWORD="$password"
            $sudo rsync $backupsrv:$backup $savepath/$fservername/latest-$fs \
                --one-file-system --delete \
                -A -H --archive --numeric-ids --partial \
                $exclude \
                $ext 2> $savepath/$fservername/log/errors-$fservername-$fs-$date.log
        ;;
    esac
    du -s $savepath/$fservername/latest-$fs/ > $savepath/$fservername/log/du-latest-$fs.log
    if [ $? -ne 0 ]; then
      echo exit 'Exit rsync code is not 0. Check Log!' | tee -a $savepath/$fservername/log/errors-$fservername-$fs-$date.log 
      echo "$date rsync error on $fs $backupsrv$backup" >> $savepath/reporterror.log
    fi
    printf "%s" "done. "
    printf "%s" "start cp... "
    cp --link --archive $savepath/$fservername/latest-$fs/* $savepath/$fservername/$fs-$date/ 2>> $savepath/$fservername/log/errors-$fservername-$fs-$date.log 
    du -s $savepath/$fservername/$fs-$date/ > $savepath/$fservername/log/du-$fs-$date.log
    if [ $? -ne 0 ]; then
      echo exit 'Exit cp code is not 0. Check Log!' | tee -a $savepath/$fservername/log/errors-$fservername-$fs-$date.log 
      echo "$date cp error on $fs $backupsrv$backup" >> $savepath/reporterror.log
    fi
    printf "%s\n" "done. "
done


