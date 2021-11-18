### Rsyncbackup 
rsyncbackup - это набор скриптов предназначенный для создания резервных копий основанных на hard link, и их ротации. Фундаментом является rsync и утилита cp. Для создания резервных копий, в процессе которых могут появиться файлы с количеством hard link боле 65000 необходимо использовать xfs.
```
   Преимущества:
    - дедупликация на основе hard links 
    - полный бекап создается 1 раз
    - прозрачность и скорость восстановления
    - два независимых типа ротации - по размеру, по занятому месту 
    - мониторинг и оповещения о неуспешности (zabbix)
    
   Недостатки:
     - нет шифрования
     - нет сжатия из коробки
```
### Установка и обновление
Выполняются из этого репозитория клонированием репозитория 
cd /etc/scripts; git clone https://github.com/perec007/rsyncbackup.git
Обновление так же - pull:
cd /etc/scripts; git pull

### Пример резервного копирования. 
Часто используемые параметры для упрощения записи в cron можно вынести в файл конфируации. Он располагается в той же папке что и скрипт резервного копирования, называется config. Файл всегда выполняется перед запуском скрипта, в нем можно отразить любые часто используемые параметры. 
По умолчанию файл не существует, его надо создать, например переименованием и редактированием файла config.example. Все параметры в этом файле называются аналогично длинным версиям консольных вариантов. Для осталных есть пометки в комментариях в этом файле. 

# Пример рабочего config файла
```
[root@backupserver /etc/scripts/rsyncbackup]# cat config.example
# This file contain predefined param.
# If you want to set the correct values, keep this in mind:
# let sizeback="${i#*=}"*1024*1024
# sudo="sudo -E"
# exclude="--delete-excluded --exclude-from=${i#*=}"
exclude="--exclude-from=/etc/scripts/backup/exclude/exclude-centos.txt --delete-excluded"
password=Wrojyawpvujnehysho
savepath=/srv/rsyncbackup/
countback=60
type=rsync
user=root
```

Скрипт резервного копирования запускается через крон каждые сутки в 6 утра. В 8 часов запускается ротирование, которое следит чтобы резервными копиями секции не было занято более 200гб (задается как параметр командной строки) и хранилось не более 60 последних копий (задается в файле config). Большинство параметров может быть вынесено в файл конфиругарции который называется config и располагается в корне той же папки что и скрипт резервного копирования.
```
0 6 * * * /etc/scripts/rsyncbackup/backuprsync.sh -s=serverbackuping --backupfs=rsyncbackup-root,rsyncbackup-boot  
    --exclude=/etc/scripts/rsyncbackup/exclude/exclude-centos.txt 
0 8 * * *  /etc/scripts/rsyncbackup/rotatebackup.sh -s=serverbackuping --backupfs=rsyncbackup-root --sizeback=200
0 8 * * *  /etc/scripts/rsyncbackup/rotatebackup.sh -s=serverbackuping --backupfs=rsyncbackup-boot --sizeback=1
```


### Настройка и резервное копирования по протоколу rsync
команда для старта
```
$ ./backuprsync.sh -u=root -s=CLIENT_IP_OR_FQDN --backupfs=rsyncbackup-root -t=rsync --password=XXXXXX
```
## настройка демона на сервере который бекапим:
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

### настройка резервного копирования по протоколу ssh (не рекомендуется)
command to start:

```
./backuprsync.sh -u=rsyncbackupuser -s=10.20.30.4 -p=22 -k=/root/.ssh/id_rsa --backupfs=/,/srv/docker
```
Требуемые настройки:

```
- 
- необходимо создать пользователя от которого будет происходить резервное копирование
- добавить возможность этому пользователю запускать rsync через sudo (не требуется если этот пользователь root)
- настроить авторизацию по ключам 
```


### Ротация бекапов 
Ротация может происходить как по размеру, так и по количеству.
```
/etc/scripts/rsyncbackup/rotatebackup.sh -s=testserver --backupfs=rsyncbackup-root --sizeback=200 --countback=600
```

## help

```
./backuprsync.sh --help
./rotatebackup.sh --help
```

### Мониторинг и логирование
В заббикс необходимо импортировать xml шаблон из этой папки. Чтобы своевременно понимать что во время одной из резервных копий что-то пошло не так создается log файл в папке резервной копии с названием errorsbackup.log  и этот же текст дублируется через tee по пути $savepath/zabbix-alert.log
Если этот файл существует заббикс выдаст алерт. Чтобы его убрать необходимо удалить файл zabbix-alert.log, предварительно вдумчиво прочитав.
