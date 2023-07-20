. ./util.sh
# source ./demo.env

run 'clear'

# TODO: Add loading progress bar
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

# desc 'Build & pull container images'
# run 'docker build -t azure-voting-app-rust:v0.1-alpha .'
# run 'docker pull postgres:15.0-alpine'

# desc 'List Docker images'
# run 'docker images'

# desc 'Scan the azure-voting-app-rust images'
# run 'trivy image azure-voting-app-rust:v0.1-alpha'

# desc 'Adjust severity levels'
# run "trivy image --severity CRITICAL ${IMAGE}"

# desc 'Filter vulnerabilities by type'
# run "trivy image --vuln-type os --severity CRITICAL ${IMAGE}"

# desc 'Export a vulnerability report'
# run "trivy image --exit-code 0 --format json --output ./patch.json --scanners vuln --vuln-type os --ignore-unfixed  ${IMAGE}" 

# desc 'Review vulnerable packages found in the image'
# run "cat patch.json | jq '.Results[0].Vulnerabilities[] | .PkgID' | sort | uniq"

# desc 'Tag and push azure-voting-app-rust to ACR'
ACR_IMAGE=${ACR_NAME}.azurecr.io/azure-voting-app-rust:v0.1-alpha
# run "docker tag ${IMAGE} ${ACR_IMAGE}"
# run "docker push ${ACR_IMAGE}"

# sudo ./bin/buildkitd &> /dev/null & 
# desc "Patch container image with Copacetic"
# run "sudo copa patch -i ${ACR_IMAGE} -r ./patch.json -t v0.1-alpha-patched"
# sudo pkill buildkitd

# desc "Show the patched image"
# run "docker images | grep patched"

# desc "Re-scan the patched image"
# run "trivy image --severity CRITICAL --scanners vuln ${ACR_IMAGE}-patched"

# desc "Push the patched image to ACR"
# run "docker push ${ACR_IMAGE}-patched"

# desc 'Tag and push Postgres image to ACR'
# run "docker tag postgres:15.0-alpine ${ACR_NAME}.azurecr.io/postgres:15.0-alpine" 
# run "docker push ${ACR_NAME}.azurecr.io/postgres:15.0-alpine"

# KEY_ID=$(az keyvault certificate show --name $CERT_NAME --vault-name $KEYVAULT_NAME --query kid -o tsv)
# desc 'Add a signing key to Notation CLI'
# run "notation key add --plugin azure-kv ${CERT_NAME} --id ${KEY_ID} --default"

# desc 'List the Notation key'
# run 'notation key list'

# desc 'Sign the azure-voting-app-rust image'
# run "notation sign ${ACR_IMAGE}-patched"

# desc 'Sign the Postgres image'
# run "notation sign ${ACR_NAME}.azurecr.io/postgres:15.0-alpine"
# TODO: Move Ratify install into setup
az aks get-credentials --resource-group ${GROUP_NAME} --name ${AKS_NAME}
# desc 'Add Gatekeeper Helm repo'
# run 'helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts'

# desc 'Install Gatekeeper on the AKS cluster'
# run "helm install gatekeeper/gatekeeper  \
# --name-template=gatekeeper \
# --namespace gatekeeper-system --create-namespace \
# --set enableExternalData=true \
# --set validatingWebhookTimeoutSeconds=5 \
# --set mutatingWebhookTimeoutSeconds=2"

desc 'Add Ratify Helm repo'
run 'helm repo add ratify https://deislabs.github.io/ratify'

desc 'Install Ratify on the AKS cluster'
run "helm install ratify \
ratify/ratify --atomic \
--namespace gatekeeper-system \
--set akvCertConfig.enabled=true \
--set akvCertConfig.vaultURI=${VAULT_URI} \
--set akvCertConfig.cert1Name=${CERT_NAME} \
--set akvCertConfig.tenantId=${TENANT_ID} \
--set oras.authProviders.azureWorkloadIdentityEnabled=true \
--set azureWorkloadIdentity.clientId=${CLIENT_ID}"

desc 'Verify Ratify is running'
run 'kubectl get pods --namespace gatekeeper-system'

desc 'Deploy the Ratify policies'
run 'kubectl apply -f https://deislabs.github.io/ratify/library/default/template.yaml'
run 'kubectl apply -f https://deislabs.github.io/ratify/library/default/samples/constraint.yaml'

desc "Run an unsign image"
run "kubectl run unsigned --image ${IMAGE}"
kubectl delete pod unsigned >> /dev/null 2>&1

desc "Check logs for blocked pod deployment"
run "kubectl logs deployment/ratify --namespace gatekeeper-system"