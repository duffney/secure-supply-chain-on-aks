#!/bin/bash

start_time=$(date +%s)

# Your command here
# ./trivy image brk264hacr.azurecr.io/azure-voting-app-rust:v0.1-alpha --scanners vuln
image=brk264hacr.azurecr.io/azure-voting-app-rust:v0.1-alpha
# ./trivy image $image --scanners vuln --vuln-type os --severity HIGH,CRITICAL
./trivy image --exit-code 0 --format json --output patch.json --scanners vuln --vuln-type os --ignore-unfixed $image

end_time=$(date +%s)
duration=$((end_time - start_time))

echo "Command duration: $duration seconds"
