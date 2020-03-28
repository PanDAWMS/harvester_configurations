#!/bin/sh
#SBATCH -q debug
#SBATCH --time 0:30:00
#DPB #SBATCH -q premium
#DPB #SBATCH --time 2:00:00
#SBATCH --image=custom:atlas_athena_21.0.15_DBRelease-31.8.1:latest
#SBATCH --module=cvmfs
#DPB #SBATCH -q flex
#DPB #SBATCH --time-min=02:00:00
#DPB #SBATCH --time 4:00:00
#SBATCH -A m2616
#SBATCH -L SCRATCH,project
#SBATCH -C knl,quad,cache  
#SBATCH --cpus-per-task 136
#SBATCH -N {nNode}

export container_setup=/usr/atlas/release_setup.sh

export PANDA_QUEUE=NERSC_Cori_p2_ES

export HARVESTER_DIR=$PANDA_HOME  # PANDA_HOME is defined in etc/sysconfig/panda_harvester
export WORK_DIR={accessPoint}
export HARVESTER_WORK_DIR={accessPoint}
export HARVESTER_WORKER_ID={workerID}

source $HARVESTER_DIR/setup.sh
source $HARVESTER_DIR/etc/sysconfig/panda_harvester

export pilot_wrapper_file=$HARVESTER_DIR/etc/panda/runpilot2-wrapper.sh
export pilot_tar_file=$HARVESTER_DIR/etc/panda/pilot2.tar.gz

echo WORK_DIR:         $WORK_DIR
cd $WORK_DIR

PANDA_JOB_IDS=( "$(python -c "import json;pids = json.load(open('worker_pandaids.json'));print(' '.join(str(x) for x in pids))")" )
echo [$SECONDS] PANDA_JOB_IDS: $PANDA_JOB_IDS

export X509_USER_PROXY=$HARVESTER_DIR/var/lib/x509up_vomsproxy

#set -x
export MPICH_GNI_VC_MSG_PROTOCOL=MSGQ
export KMP_AFFINITY="granularity=fine,compact,1,0"

# move into job directory
#DPBmkdir -v $PANDA_JOB_IDS
#DPBcd $PANDA_JOB_IDS
echo [$SECONDS] Launching job in: $PWD
#DPB((nTasks=$SLURM_JOB_NUM_NODES*2))
nTasks=$SLURM_JOB_NUM_NODES
#DPB
#copy pilot wrapper and panda pilot tarball to working directory
echo [$SECONDS] copy $pilot_wrapper_file to $PWD
cp -v $pilot_wrapper_file $PWD
echo [$SECONDS] copy $pilot_tar_file to $PWD
cp -v $pilot_tar_file $PWD
echo [$SECONDS] TMPDIR = $TMPDIR
echo [$SECONDS] unset TMPDIR
unset TMPDIR
echo [$SECONDS] TMPDIR = $TMPDIR


export ATHENA_PROC_NUMBER=136

#DPB debugging
env | sort
#DPB debugging


# now start things up
srun -n $nTasks  -o PandaID-$PANDA_JOB_IDS-%N-%j-%t.log shifter \
     /bin/bash ./runpilot2-wrapper.sh -s $PANDA_QUEUE -r $PANDA_QUEUE \
     -q $PANDA_QUEUE -j managed -i PR -t --mute --harvester SLURM_NODEID \
     --container $container_setup -w generic --pilot-user=ATLAS \
     --url=http://128.55.144.151 -p 25080 -d --harvester-submit-mode=PUSH \
     --harvester-workdir=$HARVESTER_WORK_DIR \
     --allow-same-user=False --resource-type MCORE -z &

cd $WORK_DIR

wait
