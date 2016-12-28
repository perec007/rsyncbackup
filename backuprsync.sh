#!/bin/bash


printhelp() {
cat << EOF
1 user=
2 server=
3 port=
4 key=
5 srvremotebackup=
EOF
}

user=$1
server=$2
port=$3
key=$4
srvremotebackup=$5
extparam=$6

if [[ -z $1 || -z $2 || -z $3 || -z $4 || -z $5  ]]; then
        echo Need params
        printhelp
        exit 1
fi

backuppath=/srv/bacula/rsyncbackup
date=`date +%F--%H-%M`

for backup in `echo $srvremotebackup | sed "s/,/\ /g"`; do
	if [ $backup == "/" ]; then
		fs=root
	else
		fs=`echo $backup | sed "s,/,-,g; s,^-,,g"`
	fi
	[ $server == "local" ] && backupsrv="" || backupsrv="$user@$server:" 
	mkdir -p $backuppath/$server/latest-$fs $backuppath/$server/$fs-$date
	touch $backuppath/reporterror.log

	printf "%s" "start backup $fs on $server:"
	printf "%s" "start rsync..."
	rsync $backupsrv$backup $backuppath/$server/latest-$fs \
		-e "ssh -p $port -i $key" --rsync-path="sudo rsync"  --one-file-system --delete \
		-A -H --archive --numeric-ids --partial \
		--exclude="/var/lib/docker/*" --exclude='*/.cache/*' --exclude='*/Cache/*' \
		$extparam 2> $backuppath/$server/rsync-error-$fs-$date.log
	if [ $? -ne 0 ]; then
	  echo exit 'Exit rsync code is not 0. Check Log!' | tee -a $backuppath/$server/errors-$fs-$date.log 
	  echo "$date rsync error on $fs $backupsrv$backup" >> $backuppath/reporterror.log
	fi
	printf "%s" "done. "
	printf "%s" "start cp... "
	cp --link --archive $backuppath/$server/latest-$fs/* $backuppath/$server/$fs-$date/ 2>> $backuppath/$server/errors-$fs-$date.log 
	if [ $? -ne 0 ]; then
	  echo exit 'Exit cp code is not 0. Check Log!' | tee -a $backuppath/$server/errors-$fs-$date.log 
	  echo "$date cp error on $fs $backupsrv$backup" >> $backuppath/reporterror.log
	fi
	printf "%s\n" "done. "
done

