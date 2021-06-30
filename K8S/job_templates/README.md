# Notes
- The scratch volume name must be "pilot-dir" in order for Harvester to apply the size limit from AGIS/CRIC, pro-rating it by the corecount. 
  - A unified queue with 8 cores and 80 GB disk will request 80 GB for 8-core jobs, but only 10 GB for 1-core jobs. 
- Harvester sets `activeDeadlineSeconds` in the _pod_ spec of jobs, equal to the "maxtime" field from CRIC, which acts as a walltime limit on the pod execution.
  - Note that `activeDeadlineSeconds` works differently if applied in the [job spec](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/job-v1/#lifecycle) as opposed to [pod spec](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#lifecycle). The startTime of a job is when it is created (submitted), whereas the startTime of a pod is when it starts running on a node, so if `activeDeadlineSeconds` is applied to a job it limits the total job duration, which includes wait time in the queue as well as execution time.
