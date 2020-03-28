
# get local path of this script
LOCAL_PANDA_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# load python
module load python/3.7.0-anaconda3-2018.12
# timezone
export TZ=UTC

# add Package config path incase future installs need them
export PKG_CONFIG_PATH=$INSTALL_AREA/lib/pkgconfig:$PKG_CONFIG_PATH

# activate the python virtual environment
source ${LOCAL_PANDA_PATH}/bin/activate

# panda home
export PANDA_HOME=${VIRTUAL_ENV}


export ATLAS_LOCAL_ROOT_BASE=/gpfs/alpine/hep113/world-shared/harvester/ALRB/ATLASLocalRootBase
source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh --quiet
#setup rucio client for voms code and rucio python libraries
export X509_USER_PROXY=$LOCAL_PANDA_PATH/globus/$USER/usathpc-robot-vomsproxy
export RUCIO_ACCOUNT=pilot
lsetup rucio emi

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
