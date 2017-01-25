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
    --sizeback=*)
	  let sizeback="${i#*=}"*1024*1024
	  ;;
    --countback=*)
    countback="${i#*=}"
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
if [[ ( -z $server || -z $backupfs || -z $savepath || -z $backupfs || -z $server ) ]]; then
        echo Need mandatory params! Use --help options.
        exit 1
fi


. `dirname @0`/function


for backup in `echo $backupfs | sed "s/,/\ /g"`; do
    fs=`fsname $backup`

    #rotate by countback
    if [ ! -z $countback ]; then
        echo Start rotate by count backups on file system.
        countback_current=$(echo $savepath/$fservername/$fs-* |tr ' ' \\n|wc -l)
        if [ "$countback_current" -gt "$countback" ]; then
            echo Need rotate $countback_current gt $countback
            let diff=$countback_current-$countback

            for rotate in `echo $savepath/$fservername/$fs-* `; do
                # echo $rotate
                if [ "$diff" -gt "0" ]; then
                    rm -rf $rotate
                    let diff=$diff-1
                fi
            done
        else
            echo "Not need rotate backup $fs by countback"
        fi
    fi


    # rotate by sizeback
    if [ ! -z $sizeback ]; then
        echo Start rotate by SIZE backup on filesystem.
        ducount "$savepath/$fservername/latest-$fs/ $savepath/$fservername/$fs-* " "$savepath/$fservername/latest-$fs/du-all.txt" 
        sizeback_current=`cat $savepath/$fservername/latest-$fs/du-all.txt`
        echo Current catalog size: `echo $sizeback_current | awk '{print $1/1024/1024"GB" }'`
        if [ "$sizeback_current" -ge "$sizeback" ]; then
            echo  need rotate


            for rotate in `echo $savepath/$fservername/$fs-* `; do
                ducount "$savepath/$fservername/latest-$fs/" "$savepath/$fservername/latest-$fs/du-all.txt" 
                sizeback_current=`cat $savepath/$fservername/latest-$fs/du-all.txt`
                if [ "$sizeback_current" -ge "$sizeback" ]; then
                    echo rotate $rotate
                    rm -rf $rotate $savepath/$fservername/latest-$fs/du-all.txt
                fi
            done

        fi
    fi
    
done











