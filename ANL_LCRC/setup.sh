# This script setups up the environment for running harvester
# including the using ALRB to get software needed for voms-proxy-*
# and rucio client
#

#DPB - not needed knlsubmit01.sdcc.bnl.gov export http_proxy=http://proxy.sdcc.bnl.local:3128
#DPB - not needed kblsubmit01.sdcc.bnl.gov export https_proxy=https://proxy.sdcc.bnl.local:3128

# get local path of this script
LOCAL_PANDA_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# timezone
export TZ=UTC

# load singularity
module load singularity

# activate virtual environment
module load anaconda3

if [ -z ${CONDA_DEFAULT_ENV+x} ]; then
    source /home/dbenjamin/anaconda3/etc/profile.d/conda.sh
    conda activate /home/dbenjamin/harvester-py3
fi


# panda home
export PANDA_HOME=${CONDA_DEFAULT_ENV}

# HARVESTER DIR
export HARVESTER_DIR=${CONDA_DEFAULT_ENV}

#setup ALRB software for Harvester outside of container -
export ATLAS_LOCAL_ROOT_BASE=/home/dbenjamin/harvester-py3/ATLASLocalRootBase; 

source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh --quiet
#setup rucio client for voms code and rucio python libraries
export X509_USER_PROXY=$LOCAL_PANDA_PATH/globus/$USER/usathpc_robot_vomsproxy_2020.pem
export RUCIO_ACCOUNT=pilot
lsetup rucio emi xrootd

#Singularity directories
export SINGULARITY_TMPDIR=/lcrc/group/ATLAS/users/dbenjamin/harvester/singularity/tmp
export SINGULARITY_CACHEDIR=/lcrc/group/ATLAS/users/dbenjamin/harvester/singularity/cache

# option for frontend
OPTIONS="-f "${CONDA_DEFAULT_ENV}"/etc/panda/panda_harvester-httpd.conf"

# passphrase for watcher
export HARVESTER_WATCHER_PASSPHRASE=FIXME_FIXME_FIXME

# setting these after the ALRB setup so they are picked over ALRB packages
export SITE_PACKAGES_PATH=`python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())"`

# import panda modules
export PYTHONPATH=${CONDA_DEFAULT_ENV}/pilot2:${SITE_PACKAGES_PATH}/pandacommon:${SITE_PACKAGES_PATH}:${PYTHONPATH}

#add virtual environment to path/libs

export LD_LIBRARY_PATH=${CONDA_DEFAULT_ENV}/lib:$LD_LIBRARY_PATH
export PATH=${CONDA_DEFAULT_ENV}/bin:$PATH

#needed for building python-yampl
export PKG_CONFIG_PATH=${CONDA_DEFAULT_ENV}/lib/pkgconfig:$PKG_CONFIG_PATH

