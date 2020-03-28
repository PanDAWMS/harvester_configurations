#!/bin/sh

# This shell script takes as inputs 

HARVESTER_DIR=/gpfs/alpine/hep113/world-shared/harvester
CONTAINER_DIR=${HARVESTER_DIR}/var/lib/containers


function err() {
  dt=$(date --utc +"%Y-%m-%d %H:%M:%S,%3N [wrapper]")
  echo $dt $@ >&2
}

function log() {
  dt=$(date --utc +"%Y-%m-%d %H:%M:%S,%3N [wrapper]")
  echo $dt $@
}

function usage () {
  echo "Usage: $0 -i <source URL> -o <destination path>"
  echo
  echo "  -i,   source URL "
  echo "  -o,   detination path" 
  echo
  exit 1
}

function main() {
  #
  # get the file name 
  # 
  TMPCONTAINER_SCRIPT=$(mktemp --tmpdir=${CONTAINER_DIR} ANALY_ORNL_Summit_make_container-$(date +%Y-%m-%d-%H-%M-%S)-XXXXXX.lsf) || exit 1

  containername=$(basename $oarg)

  cat ${HARVESTER_DIR}/etc/panda/ANALY_ORNL_Summit_make_container.lsf.template | \
      sed "s~{container_name}~$containername~g" | \
      sed "s~{container}~$oarg~g" | \
      sed "s~{source_url}~$iarg~g" > ${TMPCONTAINER_SCRIPT}

  result=$(bsub -L /bin/sh ${TMPCONTAINER_SCRIPT} 2>&1 ; echo RC=$?)
  retcode=$(echo $result | tr -d '\n' | awk 'BEGIN { FS = "RC="};{ print $2}')
  if [ "$retcode" == "0" ] ; then 
      batchid=$(echo $result | cut -d ' ' -f 2 | sed 's/<//g' | sed 's/>//g')
      echo $batchid
  fi
  exit $retcode
}

starttime=$(date +%s)


iarg=''
oarg=''
myargs="$@"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h|--help)
    usage
    shift
    shift
    ;;
    -i)
    iarg="$2"
    shift
    shift
    ;;
    -o)
    oarg="$2"
    shift
    shift
    ;;
esac
done

if [ -z "${iarg}" ]; then usage; exit 1; fi
if [ -z "${oarg}" ]; then usage; exit 1; fi

# get the 
# test for lock file if found exit


main 


