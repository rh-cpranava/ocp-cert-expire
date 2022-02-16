# OCP Certificate Expiry script for OCP 4.x

Script to check if the certs in OCP 4.x would expire in a given time duration

## Requirements:
* Cluster-admin privileges 
* Logged into the oc cli

## Usage:
* The script takes one argument to check if the cert would continue to be valid post that
* If no argument is provided, the script checks the current expiry state of the certs

### Example:
```
./cert-expire.sh 365
```
