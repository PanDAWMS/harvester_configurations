#!/bin/bash
#BSUB -P {{submitter.projectName}}
#BSUB -W 02:00
#BSUB -nnodes {{worker.jobspec_list|length}}
#BSUB -alloc_flags gpumps
#BSUB -J atlas-ml-{{workerID}}
#BSUB -o {{worker.accessPoint}}/stdout
#BSUB -e {{worker.accessPoint}}/stderr

#export PATH=/usr/bin:/usr/sbin:/sw/sources/lsf-tools/2.0/summit/bin:/sw/summit/xalt/1.1.4/bin:/autofs/nccs-svm1_sw/summit/.swci/1-compute/opt/spack/20180914/linux-rhel7-ppc64le/gcc-4.8.5/darshan-runtime-3.1.7-csygoqyym3m3ysoaperhxlhoiluvpa2u/bin:/sw/sources/hpss/bin:/autofs/nccs-svm1_sw/summit/.swci/1-compute/opt/spack/20180914/linux-rhel7-ppc64le/xl-16.1.1-3/spectrum-mpi-10.3.0.1-20190611-aqjt3jo53mogrrhcrd2iufr435azcaha/bin:/sw/summit/xl/16.1.1-3/xlC/16.1.1/bin:/sw/summit/xl/16.1.1-3/xlf/16.1.1/bin:/opt/ibm/spectrumcomputing/lsf/10.1/linux3.10-glibc2.17-ppc64le-csm/etc:/opt/ibm/spectrumcomputing/lsf/10.1/linux3.10-glibc2.17-ppc64le-csm/bin:/opt/ibm/csm/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/opt/ibm/flightlog/bin:/opt/ibutils/bin:/opt/ibm/spectrum_mpi/jsm_pmix/bin:/opt/puppetlabs/bin:/usr/lpp/mmfs/bin:/ccs/home/zhangr/bin
#export X509_USER_PROXY=/ccs/home/zhangr/harvester_instance_0.2.2/proxy/x509up_u60449
#export X509_CERT_DIR=/ccs/home/zhangr/harvester_instance_0.2.2/grid-security/4.0.3-1_191004/../certificates

export PILOT_HOME=/gpfs/alpine/world-shared/csc343/harvester_instances/harvester-ml/
export HARVESTER_ROOT=/gpfs/alpine/world-shared/csc343/harvester_instances/harvester-ml/

export WRAPPER_PATH=${PILOT_HOME}/misc/pilot-wrapper/runpilot2-wrapper.sh
#export WRAPPER_PATH=/autofs/nccs-svm1_home1/psvirin/harvesters/summit-ml/harvester/misc/pilot-wrapper/runpilot2-wrapper.sh
#SINGULARITY_OPTS="singularity exec --bind "/hpcgpfs01/work/benjamin/yampl:/opt/yampl" $HARVESTER_CONTAINER_IMAGE"

export PANDA_QUEUE=ANALY_ORNL_Summit_ML
export HARVESTER_ACCESS_POINT={{worker.accessPoint}}
export HARVESTER_MAPTYPE=ManyToOne
export HARVESTER_ID=Summit_Harvester
export JOBIDS_FILE={{worker.accessPoint}}/worker_pandaids.json
export PRODSOURCELABEL=user
export PILOT_USER=atlas
#export PILOT_URL=file://${HARVESTER_ROOT}/misc/pilot2.tar.gz
export PILOT_URL=file://${HARVESTER_ROOT}/misc/pilot2-2.7.14.tar.gz
#export PILOT_URL=file://${HARVESTER_ROOT}/misc/pilot2-2.7.2-PRE.tar.gz

# no unzip on worker nodes so far
export USRBIN=/gpfs/alpine/world-shared/csc343/psvirin/harvester-ml/usr/bin

export ATLAS_LOCAL_ROOT_BASE=/gpfs/alpine/csc343/world-shared/psvirin/harvester-ml/ALRB/ATLASLocalRootBase
export ALRB_SHELL=bash
export ALRB_localConfigDir=/gpfs/alpine/csc343/world-shared/psvirin/harvester-ml/var/atlasLocalRootBase/localConfig
export HOME=/gpfs/alpine/csc343/world-shared/psvirin/harvester-ml/var/atlasLocalRootBase/localConfig
export PAYLOAD_CONTAINER_LOCATION=/gpfs/alpine/csc343/proj-shared/psvirin/singularity/test/tensorflow/

export ATLAS_LOCAL_ROOT_ARCH_OVERRIDE=x86_64; 
export ALRB_OSTYPE_OVERRIDE="Linux"; 
export ALRB_OSMAJORVER_OVERRIDE="7";

export IMAGE_BASE=/gpfs/alpine/world-shared/csc343/harvester/var/lib/containers


#module load python/2.7.15
module load python/3.7.0

nTasks={{worker.jobspec_list|length}}
gpuPerRank=1

cd ${HARVESTER_ACCESS_POINT}

curl -s "http://atlas-agis-api.cern.ch/request/pandaqueue/query/list/?json&preset=schedconf.all&panda_queue=${PANDA_QUEUE}" > queuedata.json
cp queuedata.json agis_schedconf.json
curl -s "http://atlas-agis-api.cern.ch/request/ddmendpoint/query/list/?json&state=ACTIVE&preset=dict&ddmendpoint=" > agis_ddmendpoints.json


JSRUN_OPTS="-n ${nTasks} -r 1 -c 1 -g ${gpuPerRank} --stdio_mode individual --stdio_stdout analyjob_stdout --stdio_stderr analyjob_stderr"

set -x

## Setting HARVESTER_WORKDIR variable is essential, it is used by pilot to fing runGen

jsrun ${JSRUN_OPTS} \
	/bin/bash -c "export PANDAID=(\$(tr ',' ' ' < ${JOBIDS_FILE} | tr -d '[]')); echo Job to use: \${PANDAID[\$PMIX_RANK]}; \
	cd \${PANDAID[\$PMIX_RANK]}; \
	cp ../agis*.json .; cp ../queuedata.json .; cp ../queuedata.json ./cric_pandaqueues.json; cp ../agis_ddmendpoints.json ./cric_ddmendpoints.json; \
	export HARVESTER_WORKDIR=${HARVESTER_ACCESS_POINT}/\${PANDAID[\$PMIX_RANK]} PILOT_NOKILL=1; \
	export PATH=$PATH:${USRBIN}; \
         ${WRAPPER_PATH} -s ${PANDA_QUEUE} -r ${PANDA_QUEUE} \
	-q ${PANDA_QUEUE} -j ${PRODSOURCELABEL} -i PR -t --mute --harvester SLURM_NODEID \
	--harvester_workflow ${HARVESTER_MAPTYPE} \
	-w generic \
	--pilot-user=${PILOT_USER} \
	--hpc-resource cori \
	--use-https False \
	-d \
	--container \
	--harvester-submit-mode=PUSH \
	--piloturl ${PILOT_URL} \
	--harvester-workdir ${HARVESTER_ACCESS_POINT}/\${PANDAID[\$PMIX_RANK]} \
	--allow-same-user=False \
	--resource-type MCORE \
	--hpc-mode manytoone \
	--cleanup False \
	-z; " 

