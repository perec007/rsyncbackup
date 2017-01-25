#!/bin/bash

# include config 
[ -f `dirname @0`/config ] && . `dirname @0`/config

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



#check param
[[ $help -eq 1 ]] && printhelp
if [[ "$server" == "" || "$backupfs" == "" || -z $savepath || -z $backupfs || -z $server || -z type ]]; then
        echo Need mandatory params! Use --help options.
        exit 1
fi

. `dirname $0`/function


for backup in `echo $backupfs | sed "s/,/\ /g"`; do
    fs=`fsname $backup`

    printf "%s" "start backup $fs on $fservername:"
    printf "%s" "start type:$type rsync..."


    mkdir -p $savepath/$fservername/latest-$fs $savepath/$fservername/log
    touch $savepath/reporterror.log

    case $type in 
        "ssh")
            $sudo rsync $backupsrv$backup $savepath/$fservername/latest-$fs \
                -e "ssh -p $port -i $key" \
                --one-file-system --delete \
                -A -H --archive --numeric-ids \
                $exclude \
                $ext 2> $savepath/$fservername/log/errors-$fservername-$fs-$date.log
                exitrsync=$?
        ;;
        "rsync")
            export RSYNC_PASSWORD="$password"
            $sudo rsync $backupsrv:$backup $savepath/$fservername/latest-$fs \
                --one-file-system --delete \
                -A -H --archive --numeric-ids \
                $exclude \
                $ext 2> $savepath/$fservername/log/errors-$fservername-$fs-$date.log
            exitrsync=$?
        ;;
    esac
    if [ $exitrsync -ne 0 ]; then
      echo "Exit rsync code is $exitrsync. Backup name: $fservername/latest-$fs Check Log!" | tee -a $savepath/$fservername/log/errors-$fservername-$fs-$date.log 
      echo "$date $fservername rsync error on $backup" >> $savepath/reporterror.log
    fi    

    if [ $exitrsync -eq 0 ]; then
        printf "%s" "du latest-$fs... "
        rm -f $savepath/$fservername/latest-$fs/du.txt
        du -s $savepath/$fservername/latest-$fs/ \
            | awk '{ print $1 }' > $savepath/$fservername/latest-$fs/du.txt || ( echo error du; exit 1 )
        printf "%s" "du all $fs... "

        rm -f $savepath/$fservername/latest-$fs/du-all.txt
        du -s $savepath/$fservername/$fs-*/ $savepath/$fservername/latest-$fs/ \
            | awk '{ sum += $1 }; END { print sum }' > $savepath/$fservername/latest-$fs/du-all.txt || ( echo error du; exit 1 )
        

        printf "%s" "cp... "
        mkdir -p $savepath/$fservername/$fs-$date

        cp --link --archive $savepath/$fservername/latest-$fs/* $savepath/$fservername/$fs-$date/ 2>> $savepath/$fservername/log/errors-$fservername-$fs-$date.log 
        if [ $? -eq 0 ]; then
          printf "%s" "cp ok. Path: $savepath/$fservername/$fs-$date. "
        else
          echo 'Exit cp code is not 0. Check Log!' | tee -a $savepath/$fservername/log/errors-$fservername-$fs-$date.log 
          echo "$date $fservername cp error on $backup" >> $savepath/reporterror.log
          exit 1
        fi
    else
        printf "%s" "ERROR: rsync exit code: $exitrsync: Not run cp!  "
    fi

    printf "%s\n" "done. "
done


