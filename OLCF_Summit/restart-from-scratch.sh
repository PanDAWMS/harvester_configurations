#!/bin/bash

echo "Stopping Harvester"
./stop.sh

echo "removing dbs, logs, workdirs"
rm -Rf /tmp/harvester.db /gpfs/alpine/hep113/world-shared/harvester/var/lib/harvester.db var/lib/workdir/panda/* var/log/panda/*

echo "removing aux files area"
rm -Rf /gpfs/alpine/hep113/world-shared/harvester/var/lib/workdir/aux/aux_input/*

echo "restore runcontainer hack"
mkdir -pv /gpfs/alpine/hep113/world-shared/harvester/var/lib/workdir/aux/aux_input/c3/9e
cp -v ~/runcontainer-hack /gpfs/alpine/hep113/world-shared/harvester/var/lib/workdir/aux/aux_input/c3/9e/runcontainer 

echo "remove container build scripts"
rm -Rf /gpfs/alpine/hep113/world-shared/harvester/var/lib/containers/*

echo "build database"
python lib/python3.7/site-packages/pandaharvester/harvestertest/basicTest.py 

echo "check result"
python lib/python3.7/site-packages/pandaharvester/harvestertest/getJobs.py ANALY_ORNL_Summit

echo "Starting Harvester"
./start.sh

