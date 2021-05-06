# Notes
- The scratch volume name must be "pilot-dir" in order for Harvester to apply the size limit from AGIS/CRIC, pro-rating it by the corecount. 
  - A unified queue with 8 cores and 80 GB disk will request 80 GB for 8-core jobs, but only 10 GB for 1-core jobs. 
