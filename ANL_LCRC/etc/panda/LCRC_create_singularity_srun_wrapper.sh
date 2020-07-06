#!/bin/bash

#
# This routine expects the following variables set -
#
# PANDA_QUEUE - PanDA queue (eg BNL_KNL_MCORE)
# HARVESTER_WORKDIR - working directory for harvester - the pilot is unpacked here
# HARVESTER_MAPTYPE - Harvester workflow (eg ManyToOne)
# HARVESTER_CONTAINER_IMAGE - singularity container image
#


# test if the following variables are defined
if [ -z ${PANDA_QUEUE+x} ]; then 
    echo "PANDA_QUEUE variable is not set - exit"
    exit 1
fi

if [ -z ${HARVESTER_WORKDIR+x} ]; then 
    echo "HARVESTER_WORKDIR variable is not set - exit"
    exit 1
fi
if [ -z ${HARVESTER_MAPTYPE+x} ]; then 
    echo "HARVESTER_MAPTYPE variable is not set - exit"
    exit 1
fi
if [ -z ${HARVESTER_CONTAINER_IMAGE+x} ]; then 
    echo "HARVESTER_CONTAINER_IMAGE variable is not set - exit"
    exit 1
fi

echo
echo [$SECONDS] "Create ./singularity_wrapper_file.sh"
echo [$SECONDS] "PanDA Queue - "$PANDA_QUEUE
echo [$SECONDS] "Harvester Work DIR - "$HARVESTER_WORKDIR
echo [$SECONDS] "Harvester workflow (MAPTYPE) - "$HARVESTER_MAPTYPE
echo [$SECONDS] "Harvester container image - "$HARVESTER_CONTAINER_IMAGE
echo

echo "#!/bin/bash" > ./singularity_wrapper_file.sh-tmp
echo " " >>  ./singularity_wrapper_file.sh-tmp
echo "# setup python 2 environment " >> ./singularity_wrapper_file.sh-tmp
echo "echo Setup Python 2 environment" >> ./singularity_wrapper_file.sh-tmp
echo "module unload anaconda3" >> ./singularity_wrapper_file.sh-tmp
echo "module load anaconda" >> ./singularity_wrapper_file.sh-tmp
echo "source activate /home/dbenjamin/harvester-py2-new" >> ./singularity_wrapper_file.sh-tmp
echo "python -V" >> ./singularity_wrapper_file.sh-tmp
#DPB echo -n "singularity exec --bind /hpcgpfs01/work/benjamin/yampl:/opt/yampl,/hpcgpfs01/scratch:/hpcgpfs01/scratch "$HARVESTER_CONTAINER_IMAGE >>  ./singularity_wrapper_file.sh-tmp
echo -n " /bin/bash ./runpilot2-wrapper.sh -s "$PANDA_QUEUE" -r "$PANDA_QUEUE" -q "$PANDA_QUEUE >>  ./singularity_wrapper_file.sh-tmp
echo -n " -j managed -i PR -t --mute --harvester SLURM_NODEID --harvester_workflow "$HARVESTER_MAPTYPE >>  ./singularity_wrapper_file.sh-tmp
echo -n " --container -w generic --pilot-user=atlas --hpc-resource cori --use-https False -d --harvester-submit-mode=PUSH" >>  ./singularity_wrapper_file.sh-tmp
echo -n " --harvester-workdir="$HARVESTER_WORKDIR" --allow-same-user=False --resource-type MCORE --cleanup False -z" >>  ./singularity_wrapper_file.sh-tmp
echo " " >>   ./singularity_wrapper_file.sh-tmp
chmod -v +x ./singularity_wrapper_file.sh-tmp
mv -v ./singularity_wrapper_file.sh-tmp ./singularity_wrapper_file.sh
