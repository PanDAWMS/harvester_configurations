#!/bin/env python

#
#  This python program processes 1 job per node
#


import argparse
import datetime
import fnmatch
import json
import os
import os.path
from pprint import pprint
import re
import psutil
import sys
import tarfile
import shlex
import subprocess
import threading
import signal
import pipes
import time
import logging


from pandaharvester.harvestercore.queue_config_mapper import QueueConfigMapper
from pandaharvester.harvestercore.db_proxy import DBProxy

from pandaharvester.harvestercore.plugin_factory import PluginFactory
from pandaharvester.harvestercore.plugin_base import PluginBase
from pandaharvester.harvestercore.job_spec import JobSpec

from pandaharvester.harvestercore import core_utils
from pandaharvester.harvestercore.work_spec import WorkSpec
from pandaharvester.harvestercore.file_spec import FileSpec
from pandaharvester.harvestercore.event_spec import EventSpec
from pandaharvester.harvesterconfig import harvester_config
from pandaharvester.harvestermover import mover_utils

log = logging.getLogger("NERSC_single_job_per_node")

def touch(path):
    basedir = os.path.dirname(path)
    if not os.path.exists(basedir):
        os.makedirs(basedir)
    with open(path, 'a'):
        os.utime(path, None)

class CollectStream(threading.Thread):
    def __init__(self, stream, child):
        threading.Thread.__init__(self)
        self.stream = stream
        self.child = child
        self.buffer = ''

    def run(self):
        while True:
            out = self.stream.read(1)
            if out == '' and self.child.poll() is not None:
                break
            if out != '':
                self.buffer += out
                # print(out)

        self.stream.close()


terminator = signal.SIGTERM if os.name != 'nt' else signal.CTRL_BREAK_EVENT

class Popen(psutil.Popen):

    def __init__(self, args, timeout=None, terminate_timeout=5):
        psutil.Popen.__init__(self, args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        o = CollectStream(self.stdout, self)
        e = CollectStream(self.stderr, self)

        o.start()
        e.start()

        if timeout:
            end = time.time() + timeout
        while self.is_running():
            if timeout and end < time.time():
                log.info("child timed out, terminating")
                self.terminate_graceful()
                end = time.time() + terminate_timeout
                break

        while self.is_running():
            if terminate_timeout and end < time.time():
                log.info("child termination timed out, killing")
                self.kill()
                break

    def terminate_graceful(self):
        self.send_signal(terminator)



# the master class which runs the main process
class Singlejobpernode:
    # constructor
    def __init__(self, workdir=None):
        # initialize database and config
        self.workdir = workdir
        # hard code data path right now.
        self.dataPath = '/global/cscratch1/sd/dbenjami/m2015/atlasdatadisk/rucio'
        self.dbProxy = DBProxy()

    def create_job_shell_script(self,PandajobID,jobjson,eventstatusjson,workerAttributesFile,datapath):
        print "start of create_job_shell_script"
        # this routine used the Panda Job Id and jobspec information to create a shell script that is executed by aprun
        try:
            pilot_directory = os.path.join(self.workdir,"{0}".format(PandajobID))
        except:
            print "Can not make path"
            raise
        # cmd is the contents of the shell script
        try:
            cmd =  "#set -x;"
            cmd += "umask 022;"
            cmd += "source $HARVESTER_DIR/bin/deactivate;"
            cmd += "shifter --image=custom:atlas_cvmfs_centos6:latest --volume=/global/cscratch1/sd/yangw/tmpfiles:/tmp:perNodeCache=size=8G --volume=/global/project/projectdirs/atlas/prodenv/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase/etc/grid-security-emi/certificates:/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase/etc/grid-security-emi/certificates:ro --volume=/global/project/projectdirs/atlas/prodenv/cvmfs/atlas.cern.ch/repo/sw/local/etc:/cvmfs/atlas.cern.ch/repo/sw/local/etc:ro --volume=/global/project/projectdirs/atlas/prodenv/cvmfs/atlas.cern.ch/repo/sw/local/x86_64-slc5-gcc43-opt:/cvmfs/atlas.cern.ch/repo/sw/local/x86_64-slc5-gcc43-opt:ro <<EOF;"

            cmd += "#!/bin/bash;"
            cmd += "WORKDIR={0};".format(self.workdir)
            cmd += "[ -f \$WORKDIR/use_here_as_working_dir ] || WORKDIR=/tmp;"
            cmd += "cd \$WORKDIR;"
            cmd += "tar xzvf $HARVESTER_DIR/etc/minipilot-container.tgz;"
            cmd += "export PYTHONPATH=\$WORKDIR/lib64/python2.6/site-packages;"
            cmd += "export X509_USER_PROXY=" + os.getenv("X509_USER_PROXY") + ";"
            cmd += "#export ATHENA_PROC_NUMBER=68;"
            cmd += "export VO_ATLAS_SW_DIR=/cvmfs/atlas.cern.ch/repo/sw/;"
            cmd += "export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase;"
            cmd += "source \$ATLAS_LOCAL_ROOT_BASE/user/atlasLocalSetup.sh;"

            cmtconfig = jobjson['cmtConfig']
            homepackage = jobjson['homepackage'].replace("/",",")
            cmd += "source \$AtlasSetup/scripts/asetup.sh --cmtconfig={0} {1};".format(cmtconfig, homepackage)
            cmd += "export RUCIO_ACCOUNT=yangw;"
            cmd += "localSetupRucioClients;"

            #cmdline="$@"
            #set --
            ## setup yampl to run event service jobs
            #source $VO_ATLAS_SW_DIR/local/setup-yampl.sh
            #set -- $cmdline

            cmd += ";"
            cmd += "localSetupEmi;"
            cmd += " ;"
            cmd += "export DBBASEPATH=/cvmfs/atlas.cern.ch/repo/sw/database/DBRelease/current;"
            cmd += "export CORAL_DBLOOKUP_PATH=\$DBBASEPATH/XMLConfig;"
            cmd += "export CORAL_AUTH_PATH=\$DBBASEPATH/XMLConfig;"
            cmd += "export DATAPATH=\$WORKDIR:\$DBBASEPATH:\$DATAPATH;"
            cmd += " ;"
            cmd += "#mkdir -p \$WORKDIR/poolcond;"
            cmd += "#cp -v \$DBBASEPATH/poolcond/*.xml \$WORKDIR/poolcond;"
            cmd += "unset FRONTIER_SERVER;"
            cmd += "python ./pilot.py --queue $PANDA_QUEUE --queuedata /cvmfs/atlas.cern.ch/repo/sw/local/etc/agis_schedconf.json --job_tag prod --job_description {0}/jobspec_{1}.json --simulate_rucio --no_job_update --harvester --harvester_workdir {2} --harvester_datadir {3} --harvester_eventStatusDumpJsonFile {4} --harvester_workerAttributesFile {5};".format(self.workdir,PandajobID,self.workdir,self.dataPath,eventstatusjson,workerAttributesFile)
            cmd += "EOF;"
            cmd = cmd.replace(";","\n")
            print cmd
            to_script = cmd + "\n"
        except:
            print "Cannot create cmd script"
            raise

        try:
            job_shell_script_file_name = os.path.join(self.workdir,"execute_pilot_{0}.sh".format(PandajobID))
            with open(job_shell_script_file_name,'w') as outfile:
                outfile.write(to_script)

            os.chmod(job_shell_script_file_name, 0775)

        except:
            print "cannot write script"
            raise

    # main loop
    def start(self):
        # send heartbeat to harvester
        # get queue 

        # get name of file for eventStatusDumpJsonFile
        eventstatusjson = os.path.join(self.workdir,harvester_config.payload_interaction.eventStatusDumpJsonFile)
        # get name of file for workerAttributesFile
        workerAttributesFile = os.path.join(self.workdir,harvester_config.payload_interaction.workerAttributesFile)
        # get head of storage area for input and output data (preparator basePath)
        '''
        # does not work
        print type(self.queueConfig)
        print self.queueConfig
        print type(self.queueConfig['preparator'])
        print self.queueConfig['preparator']
        datadir =  self.queueConfig['preparator'].basePath
        print ("preparator basePath : {0}".format(datadir))
        '''
        # json file for job specs
        jsonJobSpecFileName = harvester_config.payload_interaction.jobSpecFile
        print("{0} : {1}".format("json file for job specs",jsonJobSpecFileName))
        jsonFilePath = os.path.join(self.workdir, jsonJobSpecFileName)
        print ('looking for attributes file {0}'.format(jsonFilePath))
        if not os.path.exists(jsonFilePath):
            # not found
            print 'not found'
            raise

        try:
            data = None
            with open(jsonFilePath) as data_file:
                data = json.load(data_file)
                #pprint(data)
        except:
            print('failed to load {0}'.format(jsonFilePath))
            raise

        jobs_list=[]
        if data != None :
            aprun_cmd = ""
            for job in data.keys():
                print "Panda Job ID {0} : ".format(job)
                jobs_list.append(job)
                #print json.dumps(data[job])
                jobspec_json_file_name = os.path.join(self.workdir,"jobspec_{0}.json".format(job))
                with open(jobspec_json_file_name,'w') as outfile:
                    outfile.write(json.dumps(data[job]))
                # have pilot run in the workdir
                # create an empty file who name contains the PanDAJobID
                PanDAJobID = os.path.join("{0}".format(self.workdir),"PanDAJobID.{0}".format(job))
                touch(PanDAJobID)
                print "touch {0}".format(PanDAJobID)
                #DPB# create subdirectory for the pilot
                #DPBdirectory = os.path.join("{0}".format(self.workdir),"{0}".format(job))
                #DPBprint directory
                #DPBtry: 
                #DPB    if not os.path.exists(directory): 
                #DPB        os.makedirs(directory)
                #DPB        os.chmod(directory, 0775)
                #DPBexcept OSError:
                #DPB    if not os.path.isdir(directory):
                #DPB        raise

                # now create the bash shell script files that will be fed to aprun commands
                print "create_job_shell_script(job,data[job],eventstatusjson,datapath)"
                try:
                    self.create_job_shell_script(job,data[job],eventstatusjson,workerAttributesFile,self.dataPath)
                except:
                    print "Failed to create shell script"
                    raise
                aprun_cmd += "/bin/sh {0}/execute_pilot_{1}.sh".format(self.workdir,job)
                #DPBaprun_cmd += "aprun -n 1 -N 1 /bin/bash {0}/execute_pilot_{1}.sh & ".format(self.workdir,job)
                #DPBaprun_cmd += " wait"
            print aprun_cmd
            args = shlex.split(aprun_cmd)
            print "About to run : {0}".format(aprun_cmd)
            p = subprocess.Popen(args)
            o,e = p.communicate()
            c = p.returncode
            print "Job ended with status: %s" %(c)
            print "Job stdout:\n%s" % o
            print "Job stderr:\n%s" % e
            '''
rgs = shlex.split(aprun_cmd)
                print "About to run : {0}".format(aprun_cmd)
                c, o, e = self.call(args)                        
                print "Job ended with status: %s" %(c)
                print "Job stdout:\n%s" % o
                print "Job stderr:\n%s" % e
            except Exceptions as err :
                print "failed to run command {0}".format(aprun_cmd)
                print "error: " %err
                print "Job ended with status: %s" %(c)
                print "Job stdout:\n%s" % o
                print "Job stderr:\n%s" % e                        
                raise
           '''


# main
if __name__ == "__main__":
    # parse option
    parser = argparse.ArgumentParser()
    parser.add_argument('--workdir', action='store', dest='workdir', default=None,
                        help='working directory/ accessspoint for worker')

    options = parser.parse_args()
    print options

    timeNow = datetime.datetime.utcnow()
    print "{0} NERSC_single_job_per_node: INFO    start".format(str(timeNow))

    nersc_single_job_per_node = Singlejobpernode(workdir=options.workdir)
    nersc_single_job_per_node.start()

    timeNow = datetime.datetime.utcnow()
    print "{0} NERSC_single_job_per_node: INFO    terminated".format(str(timeNow))
