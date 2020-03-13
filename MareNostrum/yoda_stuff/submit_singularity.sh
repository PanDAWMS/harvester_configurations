#!/bin/bash
echo [$SECONDS] Start inside Singularity
echo [$SECONDS] DATE=$(date)
WORKDIR={working_dir}
echo [$SECONDS] WORKDIR=$WORKDIR

cd $WORKDIR

# ls -l > starting_directory_listing.txt
# ls -l .. > lower_directory_list.txt

export ATHENA_PROC_NUMBER=128 # AthenaMP workers per node

#export ATLAS_BASE_DIR=/projects/AtlasADSP/atlas
#export HARVESTER_DIR=$ATLAS_BASE_DIR/harvester

export RUCIO_APPID={processingType}
export FRONTIER_ID="[{taskID}_{pandaID}]"
export CMSSW_VERSION=$FRONTIER_ID

#export X509_USER_PROXY=$HARVESTER_DIR/globus/$USER/myproxy
#export X509_CERT_DIR=$ATLAS_BASE_DIR/gridsecurity/certificates

echo [$SECONDS] ATHENA_PROC_NUMBER:   $ATHENA_PROC_NUMBER
#echo [$SECONDS] HARVESTER_DIR:        $HARVESTER_DIR
#echo [$SECONDS] RUCIO_ACCOUNT:        $RUCIO_ACCOUNT
#echo [$SECONDS] X509_USER_PROXY:      $X509_USER_PROXY
#echo [$SECONDS] X509_CERT_DIR:        $X509_CERT_DIR

#source $HARVESTER_DIR/bin/activate
echo [$SECONDS] Setting up Atlas Local Root Base
export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
source $ATLAS_LOCAL_ROOT_BASE/user/atlasLocalSetup.sh --quiet

# add this for mpi4py
#export PYTHONPATH=$PYTHONPATH:/projects/AtlasADSP/atlas/harvester/lib/python2.7/site-packages


echo [$SECONDS] Setting up Atlas Software
RELEASE={release}
PACKAGE={package}
CMTCONFIG={cmtConfig}
echo [$SECONDS] RELEASE=$RELEASE
echo [$SECONDS] PACKAGE=$PACKAGE
echo [$SECONDS] CMTCONFIG=$CMTCONFIG
#RELEASE_MAJOR=$(python -c "x='$RELEASE';print(x.split('.')[0])")
#RELEASE_MAJOR_MINOR=$(python -c "x='$RELEASE';print('.'.join(y for y in x.split('.')[0:2]))")

source $AtlasSetup/scripts/asetup.sh $RELEASE,$PACKAGE --cmtconfig=$CMTCONFIG --makeflags=\"$MAKEFLAGS\" --cmtextratags=ATLAS,useDBRelease {gcclocation}

#export LD_LIBRARY_PATH=$VO_ATLAS_SW_DIR/ldpatch:$LD_LIBRARY_PATH
DBBASEPATH=$ATLAS_DB_AREA/DBRelease/current
export CORAL_DBLOOKUP_PATH=$DBBASEPATH/XMLConfig
export CORAL_AUTH_PATH=$DBBASEPATH/XMLConfig
export DATAPATH=$DBBASEPATH:$DATAPATH
mkdir poolcond
export DBREL_LOCATION=$ATLAS_DB_AREA/DBRelease
cp $DBREL_LOCATION/current/poolcond/*.xml poolcond
export DATAPATH=$PWD:$DATAPATH
unset FRONTIER_SERVER

# tell transform to skip file validation
export G4ATLAS_SKIPFILEPEEK=1

#export LD_LIBRARY_PATH=/lus/theta-fs0/projects/AtlasADSP/atlas/harvester/athenalib_dpb:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH


echo [$SECONDS] PYTHON Version:       $(python --version)
echo [$SECONDS] PYTHONPATH:           $PYTHONPATH
echo [$SECONDS] LD_LIBRARY_PATH:      $LD_LIBRARY_PATH
echo [$SECONDS] ATHENA_PROC_NUMBER:   $ATHENA_PROC_NUMBER
#echo [$SECONDS] HARVESTER_DIR:        $HARVESTER_DIR
#echo [$SECONDS] RUCIO_ACCOUNT:        $RUCIO_ACCOUNT
#echo [$SECONDS] X509_USER_PROXY:      $X509_USER_PROXY
#echo [$SECONDS] X509_CERT_DIR:        $X509_CERT_DIR
env | sort > env_dump.txt

echo [$SECONDS] Starting transformation
{transformation} {jobPars}
echo [$SECONDS] Transform exited with return code: $?
echo [$SECONDS] Exiting
