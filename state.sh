#!/bin/bash

dir=`dirname $0`
cd $dir

# include config
[ -f $dir/config ] && . $dir/config
cd $savepath

for i in `ls */latest*/du.txt` ; do
  
	srvname=`echo $i |sed "s,/.*, ," | cut -d ' ' -f 1`
	fsname=`echo $i |sed "s,/, ,g"|cut -d ' ' -f 2 `
  	du=`cat $srvname/$fsname/du.txt` ; dugb=`bc <<< "scale=2; $du/1000/1000"|sed 's/^\./0./'`
  	duall=`cat $srvname/$fsname/du-all.txt` ; duallgb=`bc <<< "scale=2; $duall/1000/1000"|sed 's/^\./0./'`
  	echo "$srvname $fsname du: $dugb GB; du-all: $duallgb GB"
done

