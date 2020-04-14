#!/bin/sh

dir=`dirname $0`
pidfile=`echo $dir/var/run/*.pid`
runninghost=`basename $pidfile | sed -e 's/\.pid//g'`
myhost=`hostname`

if [ -z "$runninghost" -o "$runninghost" = "*" ]; then
    echo harvester is not running or not started by the start.sh script
    exit 1
fi

if [ "$runninghost" != "$myhost" ]; then
    echo please login to $runninghost and run this script
    exit 1
fi

kill -USR2 `cat $pidfile`

i=0
while [ $i -lt 10 ]; do
    ((i=i+1))
    sleep 1
    myid=`id -un`
    rc=`ps -ef |grep $myid | grep pandaharvester | grep -v grep`
    if [ -z "$rc" ]; then
        echo Harvester is stopped
        # copy over harvester db
        if [ "/tmp/harvester.db" -nt "/hpcgpfs01/work/benjamin/harvester-knl-py3/var/lib/harvester.db" ] ; then
            echo "/tmp/harvester.db is newer than /hpcgpfs01/work/benjamin/harvester-knl-py3/var/lib/harvester.db"
	        cp -fv /tmp/harvester.db /hpcgpfs01/work/benjamin/harvester-knl-py3/var/lib/harvester.db                                        
		fi
	rm -v $pidfile
        exit 0
    fi
done
echo Harvester has not stopped yet
echo $rc
echo "kill -9 " `cat $pidfile`
kill -9 `cat $pidfile`
rm -v $pidfile
# copy over harvester db
if [ "/tmp/harvester.db" -nt "/hpcgpfs01/work/benjamin/harvester-knl-py3/var/lib/harvester.db" ] ; then
    echo "/tmp/harvester.db is newer than /hpcgpfs01/work/benjamin/harvester-knl-py3/var/lib/harvester.db"
    cp -fv /tmp/harvester.db /hpcgpfs01/work/benjamin/harvester-knl-py3/var/lib/harvester.db                                        
fi
exit 1

