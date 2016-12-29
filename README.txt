params:     protocol: description:                                         
-t|--type   ssh|rsync type protocol                                            
-u|--user   ssh|rsync username (if remote)                                         
-s|--server ssh|rsync servername set local if backup localhost filesystem                                          
-p|--port   ssh|rsync if remote; ssh or rsyncd port                                            
--password     |rsync rsync auth password
-k|-key     ssh|      ssh key auth                                         
--backupfs  ssh|rsync filesystem over coma e.q. /,/boot, if rsync type - backupfs is modulename cfg file                                         
--exclude   ssh|rsync path file to excludefile                                         
--extparam  ssh|rsync external params to rsync

