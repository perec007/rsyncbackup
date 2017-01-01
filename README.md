### example use over rsync protocol
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

[rsyncbackup-root]
read only = true
path = /
uid = root
gid = root
hosts allow = SERVER_IP
hosts deny = *
```

***/etc/rsyncd.secrets***

```
root:XXXXXX
```

### example use over ssh protocol
command to start:

```
./backuprsync.sh -u=rsyncbackupuser -s=10.20.30.4 -p=22 -k=/root/.ssh/id_rsa --backupfs=/,/srv/docker
```
Need settings:

```
- on client need create rsyncbackupuser
- and add sudo permissions to run sudo rsync
- add open rsa ssh key to auth
```

## help

```
./backuprsync.sh --help
```
