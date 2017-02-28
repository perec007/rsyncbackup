#!/bin/bash

dir=`dirname $0`
cd $dir

# include config
[ -f $dir/config ] && . $dir/config

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
--backupfs  yes   one filesystem (not coma separated), if rsync type - backupfs is modulename cfg file                                         
--savepath  yes   path to local backup dir
--sizeback  no    GB. Max backup size on hard drive. Need if not define countback. 
--countback no    Count max backups on hard drive. Need if not define sizeback. 
--sudo      no    Set yes if need use local sudo rsync
-h|--help   no    print this help
EOF
exit 
}

[[ $help -eq 1 ]] && printhelp

#check params
for i in "$server" "$backupfs" "$savepath" "$backupfs" 
do
    cnt=$((cnt+1))
    if [[ "$i" == ""  ]]; then
        echo Mandatory param $cnt is empty. Need params: "server backupfs savepath backupfs" 
        exit 1
    fi
done

if [[ $backupfs == *,* ]]; then
        echo This script only works with one file system at a time.
        exit 1
fi


. `dirname @0`/function


for backup in `echo $backupfs | sed "s/,/\ /g"`; do
    fs=`fsname $backup`

    #rotate by countback
    if [ ! -z $countback ]; then
        printf "%s" "Rotation by COUNT $fs..."
        countback_current=$(echo $savepath/$fservername/$fs-* |tr ' ' \\n|wc -l)
        if [ "$countback_current" -gt "$countback" ]; then
            let diff=$countback_current-$countback

            for rotate in `echo $savepath/$fservername/$fs-* `; do
                if [ "$diff" -gt "0" ]; then
                    rm -rf $rotate
                    let diff=$diff-1
                fi
            done
	    printf "%s" "Done!"
        else
            printf "%s\n" "Not need rotation $fs by COUNT! Total backups: $countback_current."
        fi
    fi


    # rotate by sizeback
    if [ ! -z $sizeback ]; then
        printf "%s" "Rotation by SIZE $fs..." 
        ducount "$savepath/$fservername/latest-$fs/ $savepath/$fservername/$fs-* " "$savepath/$fservername/latest-$fs/du-all.txt" 

        sizeback_current=`cat $savepath/$fservername/latest-$fs/du-all.txt`
        if [ "$sizeback_current" -ge "$sizeback" ]; then

            for rotate in `echo $savepath/$fservername/$fs-* `; do
                ducount "$savepath/$fservername/latest-$fs" "$savepath/$fservername/latest-$fs/du-all.txt" 
                sizeback_current=`cat $savepath/$fservername/latest-$fs/du-all.txt`
                if [ "$sizeback_current" -ge "$sizeback" ]; then
                    echo rotate $rotate
                    rm -rf $rotate $savepath/$fservername/latest-$fs/du-all.txt
                fi
            done
	    printf "%s" "Done!"
	else 
	    printf "%s\n" "Not need rotation $fs by SIZE! Current catalog size: `echo $sizeback_current | awk '{print $1/1024/1024"GB" }'`"
        fi
    fi
    
    echo
    
done











