#!/bin/sh
# Begin LSF Directives
#BSUB -P csc343
#BSUB -W 0:15
#BSUB -nnodes 1
#BSUB -alloc_flags "gpumps smt1"
#BSUB -J make_{container_name}
#BSUB -o /gpfs/alpine/world-shared/csc343/psvirin/harvester-ml/var/log/build-container-logs/build-container.%J.stdout
#BSUB -e /gpfs/alpine/world-shared/csc343/psvirin/harvester-ml/var/log/build-container-logs/build-container.%J.stderr

# This is bad but we are running on the Launch nodes

#set -x 
# full path to container
CONTAINER_DIR={container}
# test if container image exists
if [ "$(ls -A $CONTAINER_DIR)" ]; then
     echo "Skip creating container $CONTAINER_DIR is not Empty"
     exit 0
else
    echo "$CONTAINER_DIR is Empty"
    ### Check if a directory does not exist ###
    container_path=$(dirname $CONTAINER_DIR)
    if [ ! -d "$container_path" ] 
    then
	mkdir -pv $container_path
    fi
    unset $XDG_RUNTIME_DIR
    #if singularity build --force --sandbox $CONTAINER_DIR {source_url}; then
    if singularity build  $CONTAINER_DIR {source_url}; then
	echo "Successfully build image: "$CONTAINER_DIR
	mkdir $CONTAINER_DIR/ctrdata
	exit 0
    else
	echo "Failed to build image :"$CONTAINER_DIR
	if [ -d "$CONTAINER_DIR" ] ; then
	    rm -Rf $CONTAINER_DIR
	fi
	exit 1
    fi
fi
#set +x 

