# This script setups up the environment for running harvester
# including the using ALRB to get software needed for voms-proxy-*
# and rucio client
#

# get local path of this script
#LOCAL_PANDA_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# load python
#module load python/2.7-anaconda-4.4
# swap intel compiler environment for GNU
#module swap PrgEnv-intel PrgEnv-gnu
#module load PrgEnv-gnu
# swap GNU version to something more on scale with ATLAS software
#module swap gcc gcc/4.9.3
# load java
#module load java

module load gcc
module load impi/2018.1
module load mkl/2018.1
module load python/2.7.13

module load intel/2018.1
module load singularity/2.4.2

export VIRTUAL_ENV="/home/ifae96/ifae96853/harvester_p27"
export YODA_DIR="/home/ifae96/ifae96853/panda-yoda"
export YAMPL_DIR="/home/ifae96/ifae96853/yampl_install"
export SITE_PACKAGES_PATH="/home/ifae96/ifae96853/harvester_p27/lib/python2.7/site-packages"
export CUSTOM_LIB_DIR="/home/ifae96/ifae96853/custom_lib"

source ${VIRTUAL_ENV}/bin/activate

# timezone
export TZ=UTC

# activate conda environment
#source activate $LOCAL_PANDA_PATH

# panda home
#export PANDA_HOME=${CONDA_DEFAULT_ENV}
export PANDA_HOME=${VIRTUAL_ENV}

#setup ALRB software
#source /global/project/projectdirs/m2015/scripts/setup_atlaslocalrootbase.sh

#setup rucio client for voms code and rucio python libraries
#export X509_USER_PROXY=$LOCAL_PANDA_PATH/globus/$USER/usathpc-robot-vomsproxy
#export X509_CERT_DIR=/global/project/projectdirs/m2015/cvmfs/atlas.cern.ch/ATLASLocalRootBase/etc/grid-security-emi/certificates
#export RUCIO_ACCOUNT=pilot
#lsetup rucio emi

# option for frontend
#OPTIONS="-f "${CONDA_DEFAULT_ENV}"/etc/panda/panda_harvester-httpd.conf"

# passphrase for watcher
#export HARVESTER_WATCHER_PASSPHRASE=FIXME_FIXME_FIXME

# setting these after the ALRB setup so they are picked over ALRB packages
#export SITE_PACKAGES_PATH=`python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())"`

# import panda modules
export PYTHONPATH=${YODA_DIR}:${SITE_PACKAGES_PATH}/pandacommon:${SITE_PACKAGES_PATH}:${PYTHONPATH}



#add virtual environment to path/libs

#export LD_LIBRARY_PATH=${CONDA_DEFAULT_ENV}/lib:$LD_LIBRARY_PATH
#export PATH=${CONDA_DEFAULT_ENV}/bin:$PATH
#export LD_LIBRARY_PATH=${YAMPL_DIR}/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=${CUSTOM_LIB_DIR}:${YAMPL_DIR}/lib:$LD_LIBRARY_PATH


# add Package config path incase future installs need them
#export INSTALL_AREA=${CONDA_DEFAULT_ENV}
#export PKG_CONFIG_PATH=$INSTALL_AREA/lib/pkgconfig:$PKG_CONFIG_PATH
