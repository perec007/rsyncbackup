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
    --countback=*)
    countback=="${ i#*=}"
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
params:     need: description:                                         
-s|--server yes   servername set local if backup localhost filesystem 
-prefix     no    prefix servername - need to human readable save path
--backupfs  yes   filesystem over coma e.q. /,/boot, if rsync type - backupfs is modulename cfg file                                         
--savepath  yes   path to local backup dir
--sizeback  no    GB. Max backup size on hard drive. Need if not define countback. 
--countback no    Count max backups on hard drive. Need if not define sizeback. 
--sudo      no    Set yes if need use local sudo rsync
-h|--help   no    print this help
EOF
exit 
}

#check params
[[ $help -eq 1 ]] && printhelp
if [[ "$server" == "" || "$backupfs" == "" || -z $savepath || -z $backupfs || -z $server || -z type ]]; then
        echo Need mandatory params! Use --help options.
        exit 1
fi


. `dirname @0`/function

echo start rotate 
for backup in `echo $backupfs | sed "s/,/\ /g"`; do
    if [ $backup == "/" ]; then
        fs=root
    else
        fs=`echo $backup | sed "s,/,-,g; s,^-,,g; s,-$,,g"`
    fi
    ls $savepath/$fservername/latest-$fs/du.txt $savepath/$fservername/$fs-*/du.txt

done
