# az login > /dev/null 2>&1

# sudo apt -y install xdg-utils;
cd terraform/;
terraform init && terraform apply --auto-approve;
export GROUP_NAME="$(terraform output -raw rg_name)"
export AKS_NAME="$(terraform output -raw aks_name)"
export VAULT_URI="$(terraform output -raw akv_uri)"
export KEYVAULT_NAME="$(terraform output -raw akv_name)"
export ACR_NAME="$(terraform output -raw acr_name)"
export CERT_NAME="$(terraform output -raw cert_name)"
export TENANT_ID="$(terraform output -raw tenant_id)"
export CLIENT_ID="$(terraform output -raw wl_client_id)"
cd ..
az acr login --name $ACR_NAME >> /dev/null 2>&1;

az aks get-credentials --resource-group ${GROUP_NAME} --name ${AKS_NAME}

helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

helm install gatekeeper/gatekeeper  \
--name-template=gatekeeper \
--namespace gatekeeper-system --create-namespace \
--set enableExternalData=true \
--set validatingWebhookTimeoutSeconds=5 \
--set mutatingWebhookTimeoutSeconds=2

helm repo add ratify https://deislabs.github.io/ratify

helm install ratify \
    ratify/ratify --atomic \
    --namespace gatekeeper-system \
    --set akvCertConfig.enabled=true \
    --set featureFlags.RATIFY_CERT_ROTATION=true \
    --set akvCertConfig.vaultURI=${VAULT_URI} \
    --set akvCertConfig.cert1Name=${CERT_NAME} \
    --set akvCertConfig.tenantId=${TENANT_ID} \
    --set oras.authProviders.azureWorkloadIdentityEnabled=true \
    --set azureWorkloadIdentity.clientId=${CLIENT_ID}

# kubectl apply -f https://deislabs.github.io/ratify/library/default/template.yaml
# kubectl apply -f https://deislabs.github.io/ratify/library/default/samples/constraint.yaml

kubectl apply -f  manifests/template.yaml
kubectl apply -f  manifests/constraint.yaml

kubectl get pods --namespace gatekeeper-system