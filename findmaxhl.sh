#!/bin/bash


for i in "$@"
do
case $i in
    --max=*)
	  max="${i#*=}"
	;;
    --fs=*)
	  fs="${i#*=}"
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
params: need: description:                                         
--max   yes   max symlink file
--fs    yes   check filesystem
To find all links of file use:
find /filesystem/ -samefile /path/to/file_name
EOF
}


[[ $help -eq 1 ]] && printhelp
if [[ -z $max || -z $fs  ]]; then
        echo Need mandatory params! Use --help options.
        exit 1
fi


find $fs -xdev -type f > /tmp/findmaxhl$$.txt
while read file ;do 
  # file=$line
  # echo "$file"
  inode=`stat "$file" | grep Inode |awk '{ print $4 }'`
  hardlinks=`stat "$file" | grep Inode |awk '{ print $6 }'`
  name=`stat "$file" | grep File |awk '{ print $2 }'`
  [ $hardlinks -ge $max ] && echo inode:$inode hardlinks:$hardlinks file:$file	
done < /tmp/findmaxhl$$.txt


rm -f /tmp/findmaxhl$$.txt