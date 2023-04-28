# Securing Container Deployments on AKS with Open Source Tools​

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [Helm](https://helm.sh/docs/intro/install/)
- [docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Create a Service Principal

```bash
subscription_id=$(az account show --query id -o tsv)
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subscription_id"
```

# export TF env vars

```bash
export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"

export ARM_CLIENT_SECRET="00000000-0000-0000-0000-000000000000"

export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"

export ARM_TENANT_ID="00000000-0000-0000-0000-000000000000"
```

## sign in as the service principal

```bash
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
```

## Deploy Azure Resources

```bash
terraform init;
terraform apply
```

<!-- Starting point for Breakout Demo -->


```bash
export GROUP_NAME="$(terraform output -raw resource_group_name)"
export AKS_NAME="$(terraform output -raw aks_cluster_name)"
export VAULT_URI="$(terraform output -raw key_vault_uri)"
export KEYVAULT_NAME="$(terraform output -raw key_vault_name)"
export ACR_NAME="$(terraform output -raw acr_name)"
export CERT_NAME="$(terraform output -raw ratify_certificate_name)"
export TENANT_ID="$(terraform output -raw tenant_id)"
export CLIENT_ID="$(terraform output -raw workload_identity_client_id)"
```

## Deploy Gatekeeper and Ratify

```bash
az aks get-credentials --resource-group ${GROUP_NAME} --name ${AKS_NAME}
```

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

helm install gatekeeper/gatekeeper  \
--name-template=gatekeeper \
--namespace gatekeeper-system --create-namespace \
--set enableExternalData=true \
--set validatingWebhookTimeoutSeconds=5 \
--set mutatingWebhookTimeoutSeconds=2
```

```bash
helm repo add ratify https://deislabs.github.io/ratify

helm install ratify \
    ratify/ratify --atomic \
    --namespace gatekeeper-system \
    --set akvCertConfig.enabled=true \
    --set akvCertConfig.vaultURI=${VAULT_URI} \
    --set akvCertConfig.cert1Name=${CERT_NAME} \
    --set akvCertConfig.tenantId=${TENANT_ID} \
    --set oras.authProviders.azureWorkloadIdentityEnabled=true \
    --set azureWorkloadIdentity.clientId=${CLIENT_ID}
```


```bash
#deploy polices
kubectl apply -f https://deislabs.github.io/ratify/library/default/template.yaml
kubectl apply -f https://deislabs.github.io/ratify/library/default/samples/constraint.yaml
```

## Install and Configure Notary

```bash
keyId=$(az keyvault certificate show --name $CERT_NAME --vault-name $KEYVAULT_NAME --query kid -o tsv)

./notation key add --plugin azure-kv $CERT_NAME --id $keyId
```

<!-- TODO install notary and insall KV plugin -->

```bash
## create acr token
tokenName=exampleToken
tokenPassword=$(az acr token create \
    --name $tokenName \
    --registry $ACR_NAME \
    --scope-map _repositories_admin \
    --query 'credentials.passwords[0].value' \
    --only-show-errors \
    --output tsv)
```

## Build and sign a container image

```bash
ACR_REPO=net-monitor
IMAGE_SOURCE=https://github.com/wabbit-networks/net-monitor.git#main
IMAGE_TAG=v1
IMAGE=${ACR_REPO}:$IMAGE_TAG

az acr build --registry $ACR_NAME -t $IMAGE $IMAGE_SOURCE

# TODO PUSH unsigned image to ACR
ACR_REPO_UNSIGHNED=net-monitor-unsigned
IMAGE_UNSIGNED=${ACR_REPO_UNSIGHNED}:$IMAGE_TAG

az acr build --registry $ACR_NAME -t $IMAGE_UNSIGNED $IMAGE_SOURCE
```

```bash
./notation sign --key $CERT_NAME $ACR_NAME.azurecr.io/$IMAGE -u $tokenName -p $tokenPassword
```

```bash
kubectl run net-monitor --image=$ACR_NAME.azurecr.io/$IMAGE;
sleep 5;
kubectl get pods; 


kubectl run net-monitor-unsigned --image=$ACR_REPO_UNSIGHNED.azurecr.io/$IMAGE;
sleep 5;
kubectl get pods -n demo;
```
