### Deploy the Azure resources with Terraform

First, log into Azure with the Azure CLI.

```bash
az login
```

Next, deploy the Terraform configuration. This will create the Azure resources needed for this workshop.

```bash
cd terraform;
terraform init;
terraform apply
```

<details>
<summary>Example Output</summary>

```output
azurerm_resource_group.rg: Creating...
azurerm_resource_group.rg: Creation complete after 1s [id=/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg]
azurerm_key_vault.kv: Creating...
azurerm_key_vault.kv: Creation complete after 4s [id=https://kv.vault.azure.net]
azurerm_user_assigned_identity.ua: Creating...
azurerm_user_assigned_identity.ua: Creation complete after 1s [id=/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/ua]
azurerm_container_registry.acr: Creating...
```

</details>


<div class="warning" data-title="warning">

> Certain Azure resources need to be globally unique. If you receive an error that a resource already exists, you may need to change the name of the resource in the `terraform.tfvars` file.

</div>

Run the following command to export the Terraform output as environment variables:

```bash
export GROUP_NAME="$(terraform output -raw rg_name)"
export AKS_NAME="$(terraform output -raw aks_name)"
export VAULT_URI="$(terraform output -raw akv_uri)"
export KEYVAULT_NAME="$(terraform output -raw akv_name)"
export ACR_NAME="$(terraform output -raw acr_name)"
export CERT_NAME="$(terraform output -raw cert_name)"
export TENANT_ID="$(terraform output -raw tenant_id)"
export CLIENT_ID="$(terraform output -raw wl_client_id)"
```

Before continuing, change back to the root of the repository.

```bash
cd ..
```

### Deploy Ratify to the AKS cluster

Gatekeeper is an open-source project from the CNCF that allows you to enforce policies on your Kubernetes cluster and Ratify is a tool that allows you to deploy policies and constraints that prevent unsigned container image from being deployed to Kubernetes.

Run the following command to get the Kubernetes credentials for your cluster:

```bash
az aks get-credentials --resource-group ${GROUP_NAME} --name ${AKS_NAME}
```

Next, run the following command to deploy Gatekeeper to your cluster:

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

helm install gatekeeper/gatekeeper  \
--name-template=gatekeeper \
--namespace gatekeeper-system --create-namespace \
--set enableExternalData=true \
--set validatingWebhookTimeoutSeconds=5 \
--set mutatingWebhookTimeoutSeconds=2
```

Run the following command to deploy Ratify to your cluster:

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

Once Ratify is deployed, you'll need to deploy the policies and constraints that prevent unsigned container images from being deployed to Kubernetes.

Run the following command to deploy the Ratify policies to your cluster:

<!-- TODO: Write custom template block deployment and pods -->

```bash
kubectl apply -f https://deislabs.github.io/ratify/library/default/template.yaml
kubectl apply -f https://deislabs.github.io/ratify/library/default/samples/constraint.yaml
```

Verify Ratify is running with the following command:

```bash
kubectl get pods --namespace gatekeeper-system
```

<detials>
<summary>Example Output</summary>

```output
NAME                                            READY   STATUS    RESTARTS      AGE
gatekeeper-audit-769879bb55-bdsr5               1/1     Running   1 (34m ago)   34m
gatekeeper-controller-manager-d8c9c5cd5-bstmb   1/1     Running   0             34m
gatekeeper-controller-manager-d8c9c5cd5-dzk2f   1/1     Running   0             34m
gatekeeper-controller-manager-d8c9c5cd5-qftxt   1/1     Running   0             34m
ratify-88b59894d-w5nxl                          1/1     Running   0             31m
```

</details>