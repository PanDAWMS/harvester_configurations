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

log = logging.getLogger("Theta_single_job_per_node")

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
        self.dataPath = '/projects/AtlasADSP/atlas/harvester/rucio'
        self.dbProxy = DBProxy()

    def call(self, arguments, timeout=None, terminate_timeout=5):
        log.info("calling " + " ".join(pipes.quote(x) for x in arguments))
        child = psutil.Popen(arguments, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        o = CollectStream(child.stdout, child)
        e = CollectStream(child.stderr, child)

        o.start()
        e.start()

        if timeout:
            end = time.time() + timeout
        while child.is_running():
            if timeout and end < time.time():
                log.info("child timed out, terminating")
                self.terminate_child(child)
                end = time.time() + terminate_timeout
                break

        while child.is_running():
            if terminate_timeout and end < time.time():
                log.info("child termination timed out, killing")
                self.kill_child(child)
                break

            rc = child.wait()

            return rc, o.buffer, e.buffer

    # setup environment
    def setupenv(self):
        pass

    # show envar variables
    def showenv(self):
        paramlist=[]

        for param in os.environ.keys():
            paramlist.append(param)

        paramlist.sort()
        sys.stdout.write( "\n === Environmental Paramaters === \n" )
        for param in paramlist:
            sys.stdout.write( "%15s %s = %s\n" % (name,param,os.environ[param]))

    def getCVMFSPath(self):
        """ Return the proper cvmfs path """
        return  os.environ.get('ATLAS_SW_BASE', '/cvmfs')


    def getModernASetup(self, swbase=None):
        """ Return the full modern setup for asetup """


        # Handle nightlies correctly, since these releases will have different initial paths
        path = "%s/atlas.cern.ch/repo" % (self.getCVMFSPath())
        if os.path.exists(path):
            # Handle nightlies correctly, since these releases will have different initial paths
            path = "%s/atlas.cern.ch/repo" % (self.getCVMFSPath())
            #if swbase:
            #    path = getInitialDirs(swbase, 3) # path = "/cvmfs/atlas-nightlies.cern.ch/repo"
            #    # correct for a possible change of the root directory (/cvmfs)
            #    path = path.replace("/cvmfs", self.getCVMFSPath())
            #else:
            #    path = "%s/atlas.cern.ch/repo" % (self.getCVMFSPath())
            cmd = "export ATLAS_LOCAL_ROOT_BASE=%s/ATLASLocalRootBase;" % (path)
            cmd += "source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh --quiet;"
            cmd += "source $AtlasSetup/scripts/asetup.sh"

            return cmd
        else:
            # if HPC_SW_INSTALL_AREA is set and swbase is valid  then override appdir setting
            if os.environ.has_key('HPC_SW_INSTALL_AREA') and (swbase != "NULL" or swbase != None):
                # note we are over loading swbase=job.release
               if swbase.startswith('21'):
                  appdir = "%s/%s/AtlasSetup" %(os.environ['HPC_SW_INSTALL_AREA'],'.'.join(x for x in swbase.split('.')[0:2]))
               elif swbase.startswith('19'):
                  appdir = '%s/%s/%s/AtlasSetup' % (os.environ['HPC_SW_INSTALL_AREA'],'x86_64-slc6-gcc47-opt',swbase)
            else:
                appdir = ""

            if appdir == "":
                if os.environ.has_key('HPC_SW_INSTALL_AREA') and (swbase != "NULL" or swbase != None):
                    # note we are over loading swbase=job.release
                    appdir = "%s/%s/AtlasSetup" %(os.environ['HPC_SW_INSTALL_AREA'],swbase)
                elif os.environ.has_key('VO_ATLAS_SW_DIR'):
                    appdir = os.environ['VO_ATLAS_SW_DIR']
            if appdir != "":
                cmd = "source %s/scripts/asetup.sh" % appdir
                return cmd
        return ''

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
            cmd = ""
            cmd= "#!/bin/bash;"
            #DPBcmd += "cd {0};".format(pilot_directory)
            # add environment setup to shell script
            #cmd += "#by Hand Hack for now ;"
            cmd += 'echo [$SECONDS] starting subjob script;'
            cmd += 'echo current dir: $PWD;'
            cmd += "export ATHENA_PROC_NUMBER=128;"
            cmd += " ;"
            cmd += "WORKDIR=%s;" % self.workdir
            cmd += " ;"
            cmd += "export HARVESTER_DIR=/projects/AtlasADSP/atlas/harvester;"
            cmd += "source $HARVESTER_DIR/setup.sh;"
            
            cmd += "export RUCIO_ACCOUNT=pilot;"
            cmd += "export X509_USER_PROXY=$HARVESTER_DIR/globus/x509up_usathpc_vomsproxy;"
            cmd += " ;"
            cmd += "echo ATHENA_PROC_NUMBER:   $ATHENA_PROC_NUMBER;"
            cmd += "echo HARVESTER_DIR:   $HARVESTER_DIR;"
            cmd += "echo RUCIO_ACCOUNT:   $RUCIO_ACCOUNT;"
            cmd += "echo X509_USER_PROXY: $X509_USER_PROXY;"
            cmd += "echo X509_CERT_DIR:   $X509_CERT_DIR;"
            cmd += ";";
            #
            release = jobjson['homepackage'].split('/')[1]
            #asetup_path = self.getModernASetup(release)
            asetup_options = " " + jobjson['homepackage'].replace("/"," ") + " " 
            # Local software path
            swbase = os.environ['VO_ATLAS_SW_DIR'] + '/software'
            swbase.replace('//','/')
            cmtconfig = jobjson['cmtConfig']

            cmd += "source $AtlasSetup/scripts/asetup.sh"
            cmd += " " + jobjson['homepackage'].replace("/"," ") 
        
            asetup_options += " --cmtconfig=" + cmtconfig
            asetup_options += ' --makeflags=\"$MAKEFLAGS\"'
            asetup_options += ' --cmtextratags=ATLAS,useDBRelease'
#???        swbase = os.environ['HPC_SW_INSTALL_AREA']
            releasebase = '.'.join(x for x in release.split('.')[0:2])
            swreleasebase = os.path.join(swbase,releasebase)
            asetup_options += ' --releasesarea=%s' % swreleasebase
            asetup_options += ' --cmakearea=%s/sw/lcg/contrib/CMake' % swreleasebase
            asetup_options += ' --gcclocation=%s/sw/lcg/releases/gcc/4.9.3/x86_64-slc6' % swreleasebase
            asetup_options += ';'

            #cmd += asetup_path + asetup_options

            cmd += ";"
            cmd += "localSetupEmi;"
            cmd += " ;"
            #cmd += "export LD_LIBRARY_PATH=$VO_ATLAS_SW_DIR/ldpatch:$LD_LIBRARY_PATH;"
            cmd += "export DBBASEPATH=/projects/AtlasADSP/atlas/cvmfs/atlas.cern.ch/repo/sw/database/DBRelease/current;"
            cmd += "export CORAL_DBLOOKUP_PATH=$DBBASEPATH/XMLConfig;"
            cmd += "export CORAL_AUTH_PATH=$DBBASEPATH/XMLConfig;"
            cmd += "export DATAPATH=$DBBASEPATH:$DATAPATH;"
            cmd += " ;"
            cmd += "mkdir -p $WORKDIR/poolcond;"
            cmd += "cp -v $DBBASEPATH/poolcond/*.xml $WORKDIR/poolcond;"
            cmd += " ;"
            cmd += "export DATAPATH=$WORKDIR:$DATAPATH;"
            cmd += "unset FRONTIER_SERVER;"
            cmd += "env | sort ;"
            cmd += "echo ;"
            cmd += "echo PYTHON Version:   $(python -V);"
            cmd += "echo PYTHONPATH:       $PYTHONPATH;"
            cmd += "echo LD_LIBRARY_PATH:  $LD_LIBRARY_PATH;"
            cmd += "echo PATH:             $PATH;"
            cmd += "echo NUM_NODES:        $NUM_NODES;"
            cmd += "echo ATHENA_PROC_NUMBER:    $ATHENA_PROC_NUMBER;"
            cmd += "echo ;"
            cmd += "env | grep COBALT;"
            cmd += "echo ;"

            cmd = cmd.replace(";","\n")
            #DPB
            """
            trf = jobjson['transformation']
            localpars = jobjson['jobPars'].split()
            cmd += ';' + trf
            cmd = cmd.replace(";",";\n")
            for par in localpars:
                if '--DBRelease' not in par and 'current' not in par:
                    cmd += ' ' + par
                else:
                    cmd += ';%s %s' % (trf,jobjson['jobPars'])
            """
            #DPB
            cmd = cmd.replace("--DBRelease=current", "").replace('--DBRelease=\"default:current\"', '').replace("--DBRelease='default:current'", '').replace('--DBRelease="default:current"', '').replace('--DBRelease=\'default:current\'', ''
)
            
            cmd += "tar xzvf /projects/AtlasADSP/atlas/harvester/minipilot.tgz \n"
            cmd += "python ./pilot.py --queue ALCF_Theta --queuedata /projects/AtlasADSP/atlas/harvester/queuedata_ALCF_Theta.json --job_tag prod --job_description {0}/jobspec_{1}.json --simulate_rucio --no_job_update --harvester --harvester_workdir {2} --harvester_datadir {3} --harvester_eventStatusDumpJsonFile {4} --harvester_workerAttributesFile {5}\n ".format(self.workdir,PandajobID,self.workdir,self.dataPath,eventstatusjson,workerAttributesFile)
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
                aprun_cmd += "/bin/bash {0}/execute_pilot_{1}.sh ".format(self.workdir,job)
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
            try:
                args = shlex.split(aprun_cmd)
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
    #parser.add_argument('--accesspoint', action='store', dest='accesspoint', default=None,
    #                    help='accesspoint for worker')

    options = parser.parse_args()
    print options
 
    timeNow = datetime.datetime.utcnow()
    print "{0} Theta_single_job_per_node: INFO    start".format(str(timeNow))

    theta_single_job_per_node = Singlejobpernode(workdir=options.workdir)
    theta_single_job_per_node.start()

    timeNow = datetime.datetime.utcnow()
    print "{0} Theta_single_job_per_node: INFO    terminated".format(str(timeNow))
