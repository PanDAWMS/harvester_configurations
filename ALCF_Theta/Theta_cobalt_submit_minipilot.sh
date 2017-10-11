#!/bin/bash
#COBALT -n {nNode}
#COBALT -t 06:00:00
#COBALT -q default
#COBALT --attrs mcdram=cache:numa=quad
#COBALT --project AtlasADSP
#COBALT -e {accessPoint}/cobalt_stderr.log.$COBALT_JOBID
#COBALT -o {accessPoint}/cobalt_stdout.log.$COBALT_JOBID
#COBALT --debuglog {accessPoint}/cobalt.log
#COBALT --cwd {accessPoint}

#
# what about COBALT -e ....
# what about COBALT -o ....
# what about COBALT --debuglog ....
# 

echo [$SECONDS] Starting job
echo DATE:               $(date)
echo COBALT_JOBID:       $COBALT_JOBID
echo COBALT_PARTNAME:    $COBALT_PARTNAME

export PROC_PER_NODE=1 # 1 RANK PER NODE
export NUM_NODES=$(($COBALT_PARTSIZE * $PROC_PER_NODE))

#by Hand Hack for now
export ATHENA_PROC_NUMBER=128
#export ATHENA_PROC_NUMBER=8

export HARVESTER_DIR=/projects/AtlasADSP/atlas/harvester
export EXAMPLES_DIR=$HARVESTER_DIR/examples
export PILOT_DIR=/projects/AtlasADSP/atlas/pilot
export YODA_DIR=$HARVESTER_DIR/panda-yoda
export YAMPL_DIR=/projects/AtlasADSP/atlas/harvester/yampl/install/lib
export YAMPL_PY_DIR=/projects/AtlasADSP/atlas/harvester/python-yampl/build/lib.linux-x86_64-2.7

export RUCIO_ACCOUNT=pilot
export X509_USER_PROXY=$HARVESTER_DIR/globus/x509up_usathpc_vomsproxy
#export X509_USER_PROXY=$HARVESTER_DIR/globus/$USER/myproxy
#export X509_CERT_DIR=

echo PROC_PER_NODE:   $PROC_PER_NODE
echo HARVESTER_DIR:   $HARVESTER_DIR
echo RUCIO_ACCOUNT:   $RUCIO_ACCOUNT
echo X509_USER_PROXY: $X509_USER_PROXY
echo X509_CERT_DIR:   $X509_CERT_DIR
echo ATHENA_PROC_NUMBER: $ATHENA_PROC_NUMBER

source $HARVESTER_DIR/bin/activate
source $HARVESTER_DIR/etc/sysconfig/panda_harvester

source /projects/AtlasADSP/atlas/setup_atlaslocalrootbase.sh
localSetupRucioClients
localSetupEmi

export HPC_SW_INSTALL_AREA=/projects/AtlasADSP/atlas/cvmfs/atlas.cern.ch/repo/sw

#DPBexport PYTHONPATH=$PILOT_DIR:$YODA_DIR:$YAMPL_PY_DIR:$PYTHONPATH
export PYTHONPATH=$YODA_DIR:$YAMPL_PY_DIR:$PYTHONPATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$YAMPL_DIR

echo PYTHON Version:   $(python -V)
echo PYTHONPATH:       $PYTHONPATH
echo LD_LIBRARY_PATH:  $LD_LIBRARY_PATH
echo PATH:             $PATH
echo NUM_NODES:        $NUM_NODES
echo PROC_PER_NODE:    $PROC_PER_NODE
echo
env | grep COBALT
echo
which aprun
which python

export WORK_DIR={accessPoint}
echo WORK_DIR:         $WORK_DIR

cd $WORK_DIR

PANDA_JOB_IDS=( "$(python -c "import json;pids = json.load(open('worker_pandaids.json'));print ' '.join(str(x) for x in pids)")" )
echo [$SECONDS] PANDA_JOB_IDS: $PANDA_JOB_IDS

#aprun -n $(($COBALT_PARTSIZE * $PROC_PER_NODE)) -D 3 -N $PROC_PER_NODE python /projects/AtlasADSP/atlas/harvester/examples/hello-world-mpi.py
#mpirun -f $COBALT_NODEFILE -n $NUM_NODES python /projects/AtlasADSP/atlas/harvester/examples/hello-world-mpi.py

for JOB_ID in $PANDA_JOB_IDS; do
   
   # move into job directory
   cd $JOB_ID
   echo [$SECONDS] Launching job in: $PWD
   aprun -n 1 -N 1 -d 64 -j 1 --cc depth -e KMP_AFFINITY=none python /projects/AtlasADSP/atlas/harvester/examples/Theta_single_job_per_node.py --workdir $PWD > $JOB_ID.log 2>&1 &
   # move back to working directory
   cd $WORK_DIR
done

wait

echo [$SECONDS] done
   
#aprun -n $NUM_NODES -N $PROC_PER_NODE python -c "print 'hello: {accessPoint}'"


#aprun -n $(($COBALT_PARTSIZE * $PROC_PER_NODE)) -N $PROC_PER_NODE python $YODA_DIR/pandayoda/yoda_droid.py \
#    --globalWorkingDir=$WORK_DIR  --localWorkingDir=$WORK_DIR --dumpEventOutputs --debug

