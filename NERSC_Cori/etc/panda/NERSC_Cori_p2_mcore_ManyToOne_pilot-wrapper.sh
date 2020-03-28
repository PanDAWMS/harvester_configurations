#!/bin/sh
#DPB #SBATCH -q debug
#DPB #SBATCH --time 0:30:00
#DPB #SBATCH -q premium
#DPB #SBATCH --time 2:00:00
#SBATCH -q regular
#SBATCH --time 6:00:00
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

export MPICH_GNI_VC_MSG_PROTOCOL=MSGQ
export KMP_AFFINITY="granularity=fine,compact,1,0"
nTasks=$SLURM_JOB_NUM_NODES

export container_setup=/usr/atlas/release_setup.sh

export PANDA_QUEUE=NERSC_Cori_p2_mcore

export HARVESTER_DIR=$PANDA_HOME  # PANDA_HOME is defined in etc/sysconfig/panda_harvester
export HARVESTER_WORKER_ID={workerID}
export HARVESTER_ACCESS_POINT={accessPoint}
export HARVESTER_NNODE={nNode}
export HARVESTER_NTASKS=$nTasks

#set variable to define HARVESTER running mode (mapType) for this worker
#  possible choices OneToOne, OneToMany, ManyToOne
export HARVESTER_MAPTYPE=ManyToOne


#source $HARVESTER_DIR/setup.sh
#source $HARVESTER_DIR/etc/sysconfig/panda_harvester

export pilot_wrapper_file=$HARVESTER_DIR/etc/panda/runpilot2-wrapper.sh
export pilot_tar_file=$HARVESTER_DIR/etc/panda/pilot2.tar.gz

export HARVESTER_CONTAINER_IMAGE=custom:atlas_athena_21.0.15_DBRelease-31.8.1:latest
# variables create the string to setup container release path including fixing PYTHONPATH and LD_LIBRARY_PATH for yampl
export HARVESTER_CONTAINER_RELEASE_SETUP_FILE="/usr/atlas/release_setup.sh"
export HARVESTER_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
export HARVESTER_PYTHONPATH=$PYTHONPATH 

#Athena settings for AthenaMP
export ATHENA_PROC_NUMBER_JOB=136
export ATHENA_PROC_NUMBER=136
export ATHENA_CORE_NUMBER=136

# get the PanDA Job IDs from worker_pandaids.json 
PANDA_JOB_IDS=( "$(python -c "import json;pids = json.load(open('worker_pandaids.json'));print(' '.join(str(x) for x in pids))")" )

export X509_USER_PROXY=$HARVESTER_DIR/var/lib/x509up_vomsproxy

# record the various HARVESTER envars
echo
echo [$SECONDS] "Harvester Top level directory - "$HARVESTER_DIR
echo [$SECONDS] "Harvester accessPoint - "$HARVESTER_ACCESS_POINT
echo [$SECONDS] "Harvester Worker ID - "$HARVESTER_WORKER_ID
echo [$SECONDS] "Harvester workflow (MAPTYPE) - "$HARVESTER_MAPTYPE
echo [$SECONDS] "Harvester accessPoint - "$HARVESTER_ACCESS_POINT
echo [$SECONDS] "pilot wrapper file - "$pilot_wrapper_file
echo [$SECONDS] "Pilot tar file - "$pilot_tar_file
echo [$SECONDS] "Container image - "$HARVESTER_CONTAINER_IMAGE
echo [$SECONDS] "command to setup release in container - "$HARVESTER_CONTAINER_RELEASE_SETUP_FILE
echo [$SECONDS] PANDA_JOB_IDS: $PANDA_JOB_IDS
echo [$SECONDS] "Number of Nodes to use - "$HARVESTER_NNODE
echo [$SECONDS] "Number of tasks for srun - "$HARVESTER_NTASKS 
echo [$SECONDS] "ATHENA_PROC_NUMBER - "$ATHENA_PROC_NUMBER
echo

echo [$SECONDS] TMPDIR = $TMPDIR
echo [$SECONDS] unset TMPDIR
unset TMPDIR
echo [$SECONDS] TMPDIR = $TMPDIR


# In OneToOne running Harvester expects fdiles in $HARVESTER_ACCESS_POINT
# In OneToMany running (aka Jumbo jobs) Harvester expects fdiles in $HARVESTER_ACCESS_POINT
#    Note in jumbo job running pilot wrapper will ensure each pilot runs in a different directory

# Loop over PanDA ID's

for PANDA_JOB_ID in $PANDA_JOB_IDS;  do

    echo [$SECONDS] "PanDA Job ID - "$PANDA_JOB_ID
    
    # test if running in ManyToOne mode and set working directory accordingly
    export HARVESTER_WORKDIR=$HARVESTER_ACCESS_POINT
    if [[ "$HARVESTER_MAPTYPE" = "ManyToOne" ]] ; then
	export HARVESTER_WORKDIR=$HARVESTER_ACCESS_POINT/$PANDA_JOB_ID
    fi    
    echo [$SECONDS] "setting Harvester Work Directory to - "$HARVESTER_WORKDIR

    # move into job directory
    echo [$SECONDS] "Changing to $HARVESTER_WORKDIR "
    cd $HARVESTER_WORKDIR
    
    #copy pilot wrapper and panda pilot tarball to working directory
    echo [$SECONDS] copy $pilot_wrapper_file to $HARVESTER_WORKDIR
    cp -v $pilot_wrapper_file $HARVESTER_WORKDIR
    echo [$SECONDS] copy $pilot_tar_file to $HARVESTER_WORKDIR
    cp -v $pilot_tar_file $HARVESTER_WORKDIR
    
    #DPB debugging
    #env | sort
    #DPB debugging

    # In ManyToOne running or OnetoOne running want one launch on srun per node - per PanDAid
    if [[ "$HARVESTER_MAPTYPE" = "OneToMany" ]] ; then    #AKA Jumbo jobs
        # now start things up
	echo [$SECONDS] "Launching srun command from : " $PWD

	echo [$SECONDS] srun -n $nTasks  -o PandaID-$PANDA_JOB_ID-%N-%j-%t.log \
	     shifter /bin/bash ./runpilot2-wrapper.sh -s $PANDA_QUEUE -r $PANDA_QUEUE \
	     -q $PANDA_QUEUE -j managed -i PR -t --mute --harvester SLURM_NODEID \
	     --harvester_workflow $HARVESTER_MAPTYPE \
	     --container -w generic --pilot-user=atlashpc \
	     -d --harvester-submit-mode=PUSH \
	     --harvester-workdir=$HARVESTER_WORKDIR \
	     --allow-same-user=False --resource-type MCORE -z 

	srun -n $nTasks  -o PandaID-$PANDA_JOB_ID-%N-%j-%t.log \
	     shifter /bin/bash ./runpilot2-wrapper.sh -s $PANDA_QUEUE -r $PANDA_QUEUE \
	     -q $PANDA_QUEUE -j managed -i PR -t --mute --harvester SLURM_NODEID \
	     --harvester_workflow $HARVESTER_MAPTYPE \
	     --container -w generic --pilot-user=atlashpc \
	     -d --harvester-submit-mode=PUSH \
	     --harvester-workdir=$HARVESTER_WORKDIR \
	     --allow-same-user=False --resource-type MCORE -z &
    else
        # now start things up
	echo [$SECONDS] "Launching srun command from : " $PWD

	echo [$SECONDS] srun -n 1 -N 1 -o PandaID-$PANDA_JOB_ID-%N-%j-%t.log \
	     shifter /bin/bash ./runpilot2-wrapper.sh -s $PANDA_QUEUE -r $PANDA_QUEUE \
	     -q $PANDA_QUEUE -j managed -i PR -t --mute --harvester SLURM_NODEID \
	     --harvester_workflow $HARVESTER_MAPTYPE \
	     --container -w generic --pilot-user=atlashpc \
	     -d --harvester-submit-mode=PUSH \
	     --harvester-workdir=$HARVESTER_WORKDIR \
	     --allow-same-user=False --resource-type MCORE -z 

	srun -n 1 -N 1 -o PandaID-$PANDA_JOB_ID-%N-%j-%t.log \
	     shifter /bin/bash ./runpilot2-wrapper.sh -s $PANDA_QUEUE -r $PANDA_QUEUE \
	     -q $PANDA_QUEUE -j managed -i PR -t --mute --harvester SLURM_NODEID \
	     --harvester_workflow $HARVESTER_MAPTYPE \
	     --container -w generic --pilot-user=atlashpc \
	     -d --harvester-submit-mode=PUSH \
	     --harvester-workdir=$HARVESTER_WORK_DIR \
	     --allow-same-user=False --resource-type MCORE -z &
    fi
    

done

wait
