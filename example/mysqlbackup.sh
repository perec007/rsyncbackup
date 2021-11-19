#!/bin/bash

path="/srv/mysqlbackup"
find $path -name "*.sql.bz2"  -mtime +1 -delete
mkdir -p $path

# Remove previos report backup file if exist
rm -f /backup-monitoring-error.txt

mk_backup(){
	port=$1

	base=$(echo "show databases;" | mysql --port=$port |grep -v Database |grep -v information_schema | tr -s "\n" " ")
	#if previos command fail and exit code not null then report to log file.
	[[ $? -ne 0 ]] && echo "MySQL BACKUP Error! Details: $port step1" >> /backup-monitoring-error.txt
	
	for db in $base; do
		DATE=$(date '+%F--%H-%M')
        	mysqldump $param -e $db | bzip2 -9 - >  $path/MYSQL-port-$port-$DATE-$db.sql.bz2
		#if previos command fail and exit code not null then report to log file.
		[[ $? -ne 0 ]] && echo "MySQL BACKUP Error! Details: port: $port DB: $db" >> /backup-monitoring-error.txt
	done

}



# Backup MySQL Databases 
mk_backup 3306
mk_backup 3307


