
# get local path of this script
LOCAL_PANDA_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# load python
module load python/3.7-anaconda-2019.07
# swap intel compiler environment for GNU
module swap PrgEnv-intel PrgEnv-gnu
# swap GNU version to something more on scale with ATLAS software
module swap gcc gcc/8.3.0
# load java 
#module load java

# timezone
export TZ=UTC

# add Package config path incase future installs need them
export PKG_CONFIG_PATH=$INSTALL_AREA/lib/pkgconfig:$PKG_CONFIG_PATH

# activate the python virtual environment
source ${LOCAL_PANDA_PATH}/bin/activate

# panda home
export PANDA_HOME=${VIRTUAL_ENV}


export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh --quiet
#setup rucio client for voms code and rucio python libraries
#OLD export X509_USER_PROXY=$LOCAL_PANDA_PATH/globus/$USER/usathpc-robot-vomsproxy
export X509_USER_PROXY=$LOCAL_PANDA_PATH/globus/$USER/bdouglas-harvester-vomsproxy
export RUCIO_ACCOUNT=pilot
lsetup rucio emi prmon

# contents for etc/sysconfig/panda_harvester in setup.sh
#source etc/sysconfig/panda_harvester

# option for frontend
OPTIONS="-f "${VIRTUAL_ENV}"/etc/panda/panda_harvester-httpd.conf"

# passphrase for watcher
export HARVESTER_WATCHER_PASSPHRASE=FIXME_FIXME_FIXME

# setting these after the ALRB setup so they are picked over ALRB packages
export SITE_PACKAGES_PATH=`python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())"`

# import panda modules
export PYTHONPATH=${SITE_PACKAGES_PATH}/pandacommon:${SITE_PACKAGES_PATH}:${PYTHONPATH}

#add virtual environment to path/libs

export LD_LIBRARY_PATH=${VIRTUAL_ENV}/lib:$LD_LIBRARY_PATH
export PATH=${VIRTUAL_ENV}/bin:$PATH


# add Package config path incase future installs need them
export INSTALL_AREA=${VIRTUAL_ENV}
export PKG_CONFIG_PATH=$INSTALL_AREA/lib/pkgconfig:$PKG_CONFIG_PATH
