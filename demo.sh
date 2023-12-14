. ./util.sh

run 'clear'

desc 'Loading demo environment variables...'
export IMAGE='azure-voting-app-rust:v0.1-alpha'
cd terraform/
export GROUP_NAME="$(terraform output -raw rg_name)"
export AKS_NAME="$(terraform output -raw aks_name)"
export VAULT_URI="$(terraform output -raw akv_uri)"
export KEYVAULT_NAME="$(terraform output -raw akv_name)"
export ACR_NAME="$(terraform output -raw acr_name)"
export CERT_NAME="$(terraform output -raw cert_name)"
export TENANT_ID="$(terraform output -raw tenant_id)"
export CLIENT_ID="$(terraform output -raw wl_client_id)"
cd ..
az acr login --name $ACR_NAME >> /dev/null 2>&1

desc 'Build & pull container images'
run 'docker build -t azure-voting-app-rust:v0.1-alpha .'
run 'docker pull postgres:15.0-alpine'

desc 'List Docker images'
run 'docker images'

desc 'Scan the azure-voting-app-rust images'
run 'sudo trivy image azure-voting-app-rust:v0.1-alpha'

desc 'Adjust severity levels'
run "sudo trivy image --severity CRITICAL ${IMAGE}"

desc 'Filter vulnerabilities by type'
run "sudo trivy image --vuln-type os --severity CRITICAL ${IMAGE}"

desc 'Export a vulnerability report'
run "sudo trivy image --exit-code 0 --format json --output ./patch.json --scanners vuln --vuln-type os --ignore-unfixed  ${IMAGE}" 

desc 'Review vulnerable packages found in the image'
run "cat patch.json | jq '.Results[0].Vulnerabilities[] | .PkgID' | sort | uniq"

desc 'Tag and push azure-voting-app-rust to ACR'
ACR_IMAGE=${ACR_NAME}.azurecr.io/azure-voting-app-rust:v0.1-alpha
run "docker tag ${IMAGE} ${ACR_IMAGE}"
run "docker push ${ACR_IMAGE}"

sudo ./bin/buildkitd &> /dev/null & # why does this still output?
desc "Patch container image with Copacetic"
run "sudo copa patch -i ${ACR_IMAGE} -r ./patch.json -t v0.1-alpha-1"
sudo pkill buildkitd >> /dev/null 2>&1
ACR_IMAGE_PATCHED=${ACR_NAME}.azurecr.io/azure-voting-app-rust:v0.1-alpha-1

desc "Re-scan the patched image"
run "sudo trivy image --severity CRITICAL --scanners vuln ${ACR_IMAGE_PATCHED}"

desc "Push the patched image to ACR"
run "docker push ${ACR_IMAGE_PATCHED}"

desc 'Tag and push Postgres image to ACR'
run "docker tag postgres:15.0-alpine ${ACR_NAME}.azurecr.io/postgres:15.0-alpine" 
run "docker push ${ACR_NAME}.azurecr.io/postgres:15.0-alpine"

KEY_ID=$(az keyvault certificate show --name $CERT_NAME --vault-name $KEYVAULT_NAME --query kid -o tsv)
desc 'Add a signing key to Notation CLI'
run "notation key add --plugin azure-kv ${CERT_NAME} --id ${KEY_ID} --default"

desc 'List the Notation key'
run 'notation key list'

desc 'Get the Docker image digest'
run "docker image inspect --format='{{index .RepoDigests 0}}' ${ACR_IMAGE_PATCHED}"
run "docker image inspect --format='{{index .RepoDigests 1}}' ${ACR_NAME}.azurecr.io/postgres:15.0-alpine"
export APP_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $ACR_IMAGE_PATCHED)
export DB_DIGEST=$(docker image inspect --format='{{range $digest := .RepoDigests}}{{println $digest}}{{end}}' ${ACR_NAME}.azurecr.io/postgres:15.0-alpine | sort | tail -1)

desc 'Sign the azure-voting-app-rust image'
run "notation sign ${APP_DIGEST}"

desc 'Sign the Postgres image'
run "notation sign ${DB_DIGEST}"

az aks get-credentials --resource-group ${GROUP_NAME} --name ${AKS_NAME}
desc 'Deploy unsigned app images'
run "kubectl apply -f manifests/"
kubectl delete manifest/ >> /dev/null 2>&1

# desc 'Check Ratify logs for blocked pod deployment'
# run "kubectl logs deployment/ratify --namespace gatekeeper-system | grep voting"

desc "Modify the app deployment manifests to use the signed image"
run "sed -i \"s|azure-voting-app-rust:v0.1-alpha|${APP_DIGEST}|\" ./manifests/deployment-app.yaml"
run "code ./manifests/deployment-app.yaml"

desc "Modify the db deployment manifests to use the signed image"
run "sed -i \"s|postgres:15.0-alpine|${DB_DIGEST}|\" ./manifests/deployment-db.yaml"
run "code ./manifests/deployment-db.yaml"

desc 'Deploy signed app images'
run "kubectl apply -f manifests/"

desc 'Sleep 10 seconds, wait for pods'
sleep 10
desc 'Check deployment status'
run "kubectl get pods"

desc 'Review Ratify constraints'
run "code ./manifests/constraint.yaml"

desc 'Review Ratify template'
run "code ./manifests/template.yaml"

desc 'Check ingress status'
run "kubectl get ingress"

desc 'Test the app'

desc 'Game Over: End of demo'