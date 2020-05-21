#!/bin/sh

dir=$SCRATCH/harvester
cd $dir
thishost=`hostname`
pidfile='var/run/'${thishost}'.pid'
oldpidfiles=`ls var/run/${thishost}.pid 2>/dev/null`
if [ -n "$oldpidfiles" ]; then
    echo Warning! Old pid files exist: $oldpidfiles
    # stop harvester if needed
    kill -USR2 `cat $pidfile`
    i=0
    while [ $i -lt 10 ]; do
	((i=i+1))
	sleep 1
	myid=`id -un`
	rc=`ps -ef |grep $myid | grep pandaharvester | grep -v grep`
	if [ -z "$rc" ]; then
            echo Harvester is stopped
	    break
	fi
    done
    rm -v $pidfile
fi
source ./setup.sh
# contents for etc/sysconfig/panda_harvester in setup.sh
#source etc/sysconfig/panda_harvester

# copy over harvester db
if [ "$SCRATCH/harvester/var/lib/harvester-py3.db" -nt "/tmp/harvester-py3.db" ] ; then
    echo "$SCRATCH/harvester/var/lib/harvester-py3.db is new than /tmp/harvester-py3.db"
    cp -fv $SCRATCH/harvester/var/lib/harvester-py3.db /tmp/harvester-py3.db
fi


# pidfile needs to be absolute path
pidfile=$PWD/var/run/`hostname`.pid
echo pidfile: $pidfile
rm -f $pidfile
python /global/common/software/atlas/harvester/lib/python*/site-packages/pandaharvester/harvesterbody/master.py --pid $pidfile
