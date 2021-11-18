#!/bin/bash

dir=`dirname $0`
cd $dir

# include config
[ -f $dir/config ] && . $dir/config
cd $savepath


du_latest=`cat */latest-*/du.txt |awk '{ sum+=$1 }; END { print sum }'`
du_latestall=`cat */latest-*/du-all.txt |awk '{ sum+=$1 }; END { print sum }'`
du_latestgb=`bc <<< "scale=3; $du_latest/1000/1000"|sed 's/^\./0./'`
du_latestallgb=`bc <<< "scale=3; $du_latestall/1000/1000"|sed 's/^\./0./'`
du_diffall=`bc <<< "scale=3; $du_latestallgb-$du_latestgb"|sed 's/^\./0./'`

echo "ALL BACKUPS"
echo "LATEST: $du_latestgb; TOTAL: $du_latestallgb; DIFF: $du_diffall"
echo 

for i in `ls */latest*/du.txt` ; do
  
	srvname=`echo $i |sed "s,/.*, ," | cut -d ' ' -f 1`
	fsname=`echo $i |sed "s,/, ,g"|cut -d ' ' -f 2 `
  	du=`cat $srvname/$fsname/du.txt` ; dugb=`bc <<< "scale=3; $du/1000/1000"|sed 's/^\./0./'`
  	duall=`cat $srvname/$fsname/du-all.txt` ; duallgb=`bc <<< "scale=3; $duall/1000/1000"|sed 's/^\./0./'`
	du_diff=`bc <<< "scale=3; $duallgb-$dugb"|sed 's/^\./0./'`
  	echo "$srvname $fsname du: $dugb GB; du-all: $duallgb GB; diff: $du_diff"
done
