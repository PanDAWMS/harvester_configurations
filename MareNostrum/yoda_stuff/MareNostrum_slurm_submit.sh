#!/usr/bin/env bash

#SBATCH --job-name=harvester_yoda_{workerID}
#SBATCH --qos=class_a
#SBATCH --time=8:00:00
#SBATCH --account=ifae96
#SBATCH --workdir={accessPoint}
#SBATCH --error={accessPoint}/slurm_%j.err
#SBATCH --output={accessPoint}/slurm_%j.out
#SBATCH --cpus-per-task=48
#SBATCH --nodes={nNode}

export PANDA_QUEUE="pic_MareNostrum4_Harvester"

echo [$SECONDS] initial environment
env | sort
echo

echo [$SECONDS] Setting up harvester environment
MPI_RANKS_PER_NODE=1
HARVESTER_DIR=/home/ifae96/ifae96853/harvester_p27
#DPB source $HARVESTER_DIR/setup.sh
echo [$SECONDS]simplified environment setup
#module swap PrgEnv-intel PrgEnv-gnu
source /home/ifae96/ifae96853/yoda_stuff/setup.sh
#source $HARVESTER_DIR/bin/activate
#export PYTHONPATH=$HARVESTER_DIR/lib/python2.7/site-packages/pandacommon:$HARVESTER_DIR/lib/python2.7/site-packages:$PYTHONPATH
#export LD_LIBRARY_PATH=$HARVESTER_DIR/lib:/opt/cray/pe/lib64/:$LD_LIBRARY_PATH
#source $HARVESTER_DIR/etc/sysconfig/panda_harvester

echo [$SECONDS] ldd
#ldd $HARVESTER_DIR/lib/python2.7/site-packages/mpi4py/MPI.so
ldd /apps/PYTHON/2.7.13/INTEL/lib/python2.7/site-packages/mpi4py/MPI.so
#ldd /apps/PYTHON/3.6.4_ML/lib/python3.6/site-packages/mpi4py/MPI.cpython-36m-x86_64-linux-gnu.so
#DPB

# temporary solution for MPI issues on Theta
#export MPICH_GNI_VC_MSG_PROTOCOL=MSGQ

WORK_DIR={accessPoint}
mkdir -p $WORK_DIR
echo [$SECONDS] WORK_DIR = $WORK_DIR

ulimit -c unlimited

# run cray pat
#module unload darshan
#module load perftools-base perftools-preload
#export KMP_AFFINITY="granularity=fine,compact,1,0"

#RUNTIME=$(( $COBALT_ENDTIME - $COBALT_STARTTIME ))
#RUNTIME=$(( $RUNTIME / 60 ))
#echo [$SECONDS] RUNTIME=$RUNTIME

### Manually symlink all input files
#ls -1 /gpfs/projects/ifae96/ifae96853/rucio_files/mc15_13TeV/ | xargs -I%% ln -s /gpfs/projects/ifae96/ifae96853/rucio_files/mc15_13TeV/%% $WORK_DIR/%%
###


PANDA_JOB_IDS=( "$(python -c "import json;pids = json.load(open('worker_pandaids.json'));print ' '.join(str(x) for x in pids)")" )
echo [$SECONDS] PANDA_JOB_IDS: $PANDA_JOB_IDS

# move into job directory
mkdir $PANDA_JOB_IDS
cd $PANDA_JOB_IDS
echo [$SECONDS] Launching job in: $PWD

nTasks=$SLURM_JOB_NUM_NODES

echo [$SECONDS] start environment dump
env | sort
echo [$SECONDS] end environment dump

echo [$SECONDS] Starting yoda_droid
srun -n $nTasks --output=$JOB_ID.log  \
   $HARVESTER_DIR/bin/python /home/ifae96/ifae96853/panda-yoda/pandayoda/yoda_droid.py -w $WORK_DIR -c /home/ifae96/ifae96853/yoda_stuff/yoda.cfg --debug
EXIT_CODE=$?
echo [$SECONDS] yoda_droid exit code = $EXIT_CODE
exit $EXIT_CODE
