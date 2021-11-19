#!/bin/bash

bkp_path=/srv/rsyncbackup
LOGS=`ls $bkp_path/*/latest-*/backup-monitoring-error*.txt 2> /dev/null`

 JSON="{ \"data\":["
         for BACKUPS in $LOGS 
            do

                JSON=${JSON}"{ \"{#BACKUPS}\":\"${BACKUPS}\" },"

            done

       JSON=${JSON}"]}"
          echo  ${JSON} | sed "s/},]}/}]}/g"
          exit 0


