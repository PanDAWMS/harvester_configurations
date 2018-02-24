#!/bin/sh
#SBATCH -p regular
#SBATCH -t 5:30:00
#SBATCH -L SCRATCH,project
#SBATCH -C haswell
#SBATCH -N {nNode}

export ATHENA_PROC_NUMBER=32
export PANDA_QUEUE=NERSC_Cori_p1_mcore

export HARVESTER_DIR=$PANDA_HOME  # PANDA_HOME is defined in etc/sysconfig/panda_harvester
export WORK_DIR={accessPoint}

source $HARVESTER_DIR/setup.sh
source $HARVESTER_DIR/etc/sysconfig/panda_harvester
source $HARVESTER_DIR/bin/activate

export YAMPL_DIR=$HARVESTER_DIR/lib
export YAMPL_PY_DIR=$HARVESTER_DIR/lib/python2.7/site-packages/

export PYTHONPATH=$YAMPL_PY_DIR:$PYTHONPATH
export LD_LIBRARY_PATH=$HARVESTER_DIR/libextra:$LD_LIBRARY_PATH:$YAMPL_DIR

echo WORK_DIR:         $WORK_DIR
cd $WORK_DIR

PANDA_JOB_IDS=( "$(python -c "import json;pids = json.load(open('worker_pandaids.json'));print ' '.join(str(x) for x in pids)")" )
echo [$SECONDS] PANDA_JOB_IDS: $PANDA_JOB_IDS

export X509_USER_PROXY=$HARVESTER_DIR/var/lib/x509up_vomsproxy

set -x
FIRST_JOB_ID=`echo $PANDA_JOB_IDS | cut -f1 -d' '`
for JOB_ID in $PANDA_JOB_IDS; do
   # move into job directory
   cd $JOB_ID
   [ $JOB_ID -eq $FIRST_JOB_ID ] && touch use_here_as_working_dir
   echo [$SECONDS] Launching job in: $PWD
   srun -n 1 -N 1 --ntasks-per-node=1 --cpu_bind=verbose,none --cpus-per-task=272 -o $JOB_ID.log \
       python $HARVESTER_DIR/etc/panda/NERSC_single_job_per_node.py --workdir $PWD 2>&1 &
   cd $WORK_DIR
done

wait
