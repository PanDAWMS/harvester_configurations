# Harvester queue configuration files
This repository contains the queue configurations for the different harvester instances. The name of the configuration file must match the harvester instance ID that you declared in your panda_harvester.cfg file. 
```
#########################
#
# Master parameters
#

[master]

...
# harvester id - unique id as registered also in panda server
harvester_id = <harvester instance name>
```
E.g. if I set *harvester_id = harvester_john_doe*, the file must be named *harvester_john_doe.json*.
