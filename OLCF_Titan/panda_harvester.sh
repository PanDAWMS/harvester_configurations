# panda home
export PANDA_HOME=${VIRTUAL_ENV}

# timezone
export TZ=UTC

export SITE_PACKAGES_PATH=`python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())"`

# import panda modules
export PYTHONPATH=${SITE_PACKAGES_PATH}/pandacommon:${SITE_PACKAGES_PATH}

# option for frontend
OPTIONS="-f "${VIRTUAL_ENV}"/etc/panda/panda_harvester-httpd.conf"

#setup Rucio enviroment variables and pathes to gfal (for Titan)

export RUCIO_ACCOUNT=pilot
export RUCIO_AUTH_TYPE=x509_proxy
export PYTHONPATH=$PYTHONPATH:/lustre/atlas/proj-shared/csc108/app_dir/pilot/grid_env/gfal_rhel7/current/usr/lib/python2.7/site-packages:/lustre/atlas/proj-shared/csc108/app_dir/pilot/grid_env/gfal_rhel7/current/usr/lib64/python2.7/site-packages
