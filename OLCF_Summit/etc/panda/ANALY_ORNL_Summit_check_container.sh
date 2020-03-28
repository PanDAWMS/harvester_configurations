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
  echo "Usage: $0 -i <destination path>"
  echo
  echo "  -i,   detination path" 
  echo
  exit 1
}

function main() {

  # full path to container
  CONTAINER_DIR=$iarg
  # test if container image exists
  if [ "$(ls -A $CONTAINER_DIR)" ]; then
      echo "Skip creating container $CONTAINER_DIR is not Empty"
      exit 0
  else
      echo "$CONTAINER_DIR is Empty"
      exit 1
  fi
}

starttime=$(date +%s)


iarg=''

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
esac
done

if [ -z "${iarg}" ]; then usage; exit 1; fi


main 


