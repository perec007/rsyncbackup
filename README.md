### example use over rsync protocol:
command to start script:

$ ./backuprsync.sh -u=root -s=CLIENT_IP_OR_FQDN --backupfs=rsyncbackup-root -t=rsync --password=XXXXXX
### config rsync daemon:
***cat /etc/rsyncd.conf***

```
use chroot = yes
max connections = 4
pid file = /var/run/rsyncd.pid
exclude = lost+found/
transfer logging = yes
timeout = 900
ignore nonreadable = yes
dont compress   = *.gz *.tgz *.zip *.z *.Z *.rpm *.deb *.bz2
secrets file = /etc/rsyncd.secrets 
auth users = root
list = true
```
[rsyncbackup-root]
read only = true
path = /
uid = root
gid = root
hosts allow = SERVER_IP
hosts deny = *

***/etc/rsyncd.secrets***

root:XXXXXX


### example use over ssh protocol:
command to start
./backuprsync.sh -u=rsyncbackupuser -s=10.20.30.4 -p=22 -k=/root/.ssh/id_rsa --backupfs=/,/srv/docker

- on client need create rsyncbackupuser
- and add sudo permissions to run sudo rsync
- add open rsa ssh key to auth

## help
params:     protocol: description:
-t|--type   ssh|rsync type protocol
-u|--user   ssh|rsync username (if remote)
-s|--server ssh|rsync servername set local if backup localhost filesystem
-p|--port   ssh|rsync if remote; ssh or rsyncd port
--password     |rsync rsync auth password
-k|-key     ssh|      ssh key auth
--backupfs  ssh|rsync filesystem over coma e.q. /,/boot, if rsync type - backupfs is modulename cfg file
--exclude   ssh|rsync path file to excludefile--extparam  ssh|rsync external params to rsync

