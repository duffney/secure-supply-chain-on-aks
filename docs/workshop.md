---
short_title: Securing container deployments on Azure Kubernetes Service with open-source tools
description: Learn how to use open-source tools to secure your container deployments on Azure Kubernetes Service.
type: workshop
authors: Josh Duffney 
contacts: '@joshduffney'
# banner_url: assets/copilot-banner.jpg
duration_minutes: 45
audience: devops engineers, devs, site reliability engineers, security engineers
level: intermediate
tags: azure, github actions, notary, ratify, secure supply chain, kubernetes, helm, terraform, gatekeeper, azure kubernetes service, azure key vault, azure container registry
published: false
wt_id: 
sections_title:
  - Introduction
---

# Securing container deployments on Azure Kubernetes Service with open-source tools

In this workshop, you'll learn how to use open-source tools; Trivy, Notary, and Ratify to secure your container deployments on Azure Kubernetes Service.

Trivy will be used to scan container images for vulnerabilities. Notary will be used to sign and verify container images. And Ratify will be used to automate the signing and verification process of container images deployed to Azure Kubernetes Service.

## Objectives

You'll learn how to:
- Deploy Azure resources with Terraform
- Scan container images for vulnerabilities
- Sign and verify container images
- Prevent unsigned container images from being deployed to Azure Kubernetes Service

## Prerequisites

| | |
|----------------------|------------------------------------------------------|
| GitHub account       | [Get a free GitHub account](https://github.com/join) |
| Azure account        | [Get a free Azure account](https://azure.microsoft.com/free) |
| Azure CLI            | [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Terraform            | [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) |
| Helm                 | [Install Helm](https://helm.sh/docs/intro/install/) |
| Docker               | [Install Docker](https://docs.docker.com/get-docker/) |
| kubectl              | [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) |

---

## Deploying Azure Resources with Terraform

Terrafom is an open-source infrastructure as code tool that allows you to define and provision Azure resources. In this section, you'll use Terraform to deploy the following Azure resources:

- Resource Group
- Azure Kubernetes Service
- Azure Key Vault
- Azure Container Registry
- Azure User Assigned Managed Identity
- Azure Federated Credential

In addition to deploying the resources, you'll also create a Service Principal and assign it the Contributor role to the Resource Group. The Service Principal will be used to authenticate Terraform to Azure.

### Log into Azure with the Azure CLI.

First, log into Azure with the Azure CLI.

```bash
az login
```

### Create a Service Principal

Next, create a Service Principal for Terraform to use to authenticate to Azure.

```bash
subscription_id=$(az account show --query id -o tsv)

az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subscription_id"
```

<details>
<summary>Example Output</summary>

```output
{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "azure-cli-2024-04-19-19-38-16",
  "name": "http://azure-cli-2024-04-19-19-38-16",
  "password": "QVexZdqvcPxx%4HJ^ZY",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
```

</details>

Take note of the `appId`, `password`, and `tenant` values and store them in a secure location. You'll need them later.

### Assign the User Access Administrator role to the Service Principal

Next, assign the User Access Administrator role to the Service Principal. This role will allow Terraform to create the federated identity credential used by the workload identity.

```bash
az role assignment create --role "User Access Administrator" --assignee  "00000000-0000-0000-0000-000000000000" --scope "/subscriptions/$subscription_id"
```

Replace `00000000-0000-0000-0000-000000000000` with the `appId` value from the previous step.

### Export the Service Principal credentials as environment variables

Next, export the Service Principal credentials as environment variables. These variables will be used by Terraform to authenticate to Azure.

```bash
export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
export ARM_CLIENT_SECRET="QVexZdqvcPxx%4HJ^ZY"
export ARM_SUBSCRIPTION_ID=$subscription_id
export ARM_TENANT_ID="00000000-0000-0000-0000-000000000000"
```

Replace `00000000-0000-0000-0000-000000000000` with the `appId`, `password`, and `tenant` values from the previous step.

### Sign into Azure CLI with the Service Principal

Change the Azure CLI login from your user to the service principal you just created. This allows Terraform to consistently configure access polices to Azure Key Vault for the current user.

```bash
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
```

### Deploy the Terraform configuration

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


<div class="info" data-title="warning">

> Certain Azure resources need to be globally unique. If you receive an error that a resource already exists, you may need to change the name of the resource in the `terraform.tfvars` file.

</div>

### Export Terraform output as environment variables

As part of the Terraform deployment, several output variables were created. These variables will be used by the other tools in this workshop. 

Run the following command to export the Terraform output as environment variables:

<details>
<summary>bash</summary>

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

</details>

<details>

<summary>PowerShell</summary>

```pwsh
$GROUP_NAME="$(terraform output -raw resource_group_name)"
$AKS_NAME="$(terraform output -raw aks_cluster_name)"
$VAULT_URI="$(terraform output -raw key_vault_uri)"
$KEYVAULT_NAME="$(terraform output -raw key_vault_name)"
$ACR_NAME="$(terraform output -raw acr_name)"
$CERT_NAME="$(terraform output -raw ratify_certificate_name)"
$TENANT_ID="$(terraform output -raw tenant_id)"
$CLIENT_ID="$(terraform output -raw workload_identity_client_id)"
```

</details>

### Enable the Web App Routing Addon

Web app routing is used to expose the Azure Voting app to the internet. You'll need to enable the Web App Routing Addon on your cluster for the ingress of the Azure Voting app to work.

Run the following command to enable the Web App Routing Addon on your cluster:

```bash
az aks addon enable --name $AKS_NAME --resource-group $GROUP_NAME --addon web_application_routing
```

Before continuing, change back to the root of this repository:

```bash
cd ..
```

---

## Scanning Container Images for Vulnerabilities

Image scanning is a critical part of the container lifecycle. In this section, you'll use Trivy to scan a container image for vulnerabilities and secrets.

### Build the Azure Voting App container image

Within this repository, there is a `Dockerfile` that will build a container image that hosts the Azure Voting App. The Azure Voting App is a simple Rust application that allows users to vote on their favorite pet.

Run the following command to build the container image from the root of this repository:

```bash
docker build -t azure-voting-app-rust:v0.1-alpha .
```

### Pull PostgreSQL container image from Docker Hub

The Azure Voting App requires a PostgreSQL database to store the votes. Run the following command to pull the PostgreSQL container image from Docker Hub:

```bash
docker pull postgres:15.0-alpine
```

### Download Trivy

Installing Trivy is as simple as downloading the binary for your operating system. Browse to the [Trivy Installation page](https://aquasecurity.github.io/trivy/v0.40/getting-started/installation/) and download the binary for your operating system.

### Use Trivy to scan for vulnerabilities

Once you've downloaded Trivy, you can use it to scan container images for vulnerabilities.

Run the following command to scan the `azure-voting-app-rust` container image for vulnerabilities:

```bash
trivy image azure-voting-app-rust:v0.1-alpha;
trivy image postgres:15.0-alpine
```

You can adjust the severity level of the vulnerabilities that Trivy reports by using the `--severity` flag. For example, to only report vulnerabilities that are `CRITICAL`, you would run the following command:

```bash
trivy image --severity CRITICAL azure-voting-app-rust:v0.1-alpha
```

<details>
<summary>Example Output</summary>

```output
2023-04-28T10:16:06.201-0500    INFO    Vulnerability scanning is enabled
2023-04-28T10:16:06.201-0500    INFO    Secret scanning is enabled
2023-04-28T10:16:06.201-0500    INFO    If your scanning is slow, please try '--scanners vuln' to disable secret scanning
2023-04-28T10:16:06.201-0500    INFO    Please see also https://aquasecurity.github.io/trivy/v0.40/docs/secret/scanning/#recommendation for faster secret detection
2023-04-28T10:16:09.391-0500    INFO    Detected OS: debian
2023-04-28T10:16:09.391-0500    INFO    Detecting Debian vulnerabilities...
2023-04-28T10:16:09.416-0500    INFO    Number of language-specific files: 0

azure-voting-app-rust:v0.1-alpha (debian 11.2)

Total: 14 (CRITICAL: 14)
.......................
.......................
```

</details>


<div class="info" data-title="note">

> Outdated container images are a common source of vulnerabilities. Besure to regularly update your container images to the latest version.

</div>

### Adding exemptions for vulnerabilities

Often times, vulnerabilites that pop up during a security scan don't apply to the application running on the system. When this is the case it's necessary to add an exemption to Trivy so the scanner will ignore the vulnerability.

Create a file called `.trivyignore` at the root of the repository. Within the file add a comment for why an exemption is being made followed by the CVE number of the vulnerability.

<details>
<summary>.trivyignore example</summary>

```output
# No impact
CVE-2019-8457
```

</details>

Run the following command to scan the `azure-voting-app-rust` container image for vulnerabilities and ignore the CVEs listed in the `.trivyignore` file:

```bash
trivy image azure-voting-app-rust:v0.1-alpha
```

Notice that the vulnerabilities listed in the `.trivyignore` file are no longer reported.

### Build and push the container images to Azure Container Registry

Next, you'll build the container images that will be used in this workshop.

Run the following command to build the `azure-voting-app-rust` container image and push it to the Azure Container Registry:

```bash
az acr build --registry $ACR_NAME -t azure-voting-app-rust:v0.1-alpha .
```

Run the following command to build the `postgres` container image and push it to the Azure Container Registry:

```bash
docker tag postgres:15.0-alpine $ACR_NAME.azurecr.io/postgres:15.0-alpine
docker push $ACR_NAME.azurecr.io/postgres:15.0-alpine
```

<div class="info" data-title="note">

> If you encounter an authentication error, run `az acr login --name $ACR_NAME` command to authenticate to the Azure Container Registry then try the `docker push` command again.

</div>


---

## Signing Container Images

In this section, you'll use Notary to sign the `azure-voting-app-rust` and `postgres:15.0-alpine` container images. Notary is a CNCF project that provides a way to digitally sign container images. You'll use Notary's command line tool, Notation, to sign and verify container images.

### Installing Notation

Notation is a command line tool from the CNCF Notary project that allows you to sign and verify container images. Installing Notation is as simple as downloading the binary for your operating system. Browse to the [Notary Installation page](https://github.com/notaryproject/notation/releases). Download the binary for your operating system and add it to your `PATH` environment variable.

<details>
<summary>Install Notation on Linux</summary>

```output
# Download the binary
curl -Lo notation.tar.gz https://github.com/notaryproject/notation/releases/download/v1.0.0-rc.4/notation_1.0.0-rc.4_linux_amd64.tar.gz

# Extract the Notation CLI
[ -d ~/bin ] || mkdir ~/bin
tar xvzf notation.tar.gz -C ~/bin notation
rm -rf notation.tar.gz

# Add Notation to that PATH environment variable.
export PATH="$HOME/bin:$PATH"
notation version
```

</details>

<details>
<summary>Install Notation on Windows</summary>

```output
# Download the binary
Invoke-WebRequest -Uri 'https://github.com/notaryproject/notation/releases/download/v1.0.0-rc.4/notation_1.0.0-rc.4_windows_amd64.zip' -OutFile 'notation_1.0.0-rc.4_windows_amd64.zip'


# Extract the Notation CLI
if(!(Test-Path ~/bin)) { New-Item -ItemType Directory -Path ~/bin | Out-Null }
Expand-Archive ./notation_1.0.0-rc.4_windows_amd64.zip ~/bin
Remove-Item ./notation_1.0.0-rc.4_windows_amd64.zip

# Add Notation to that PATH environment variable.
$env:PATH = "$($HOME)/bin;$($env:PATH)"
notation version
```

</details>

### Install the Azure Key Vault plugin for Notation

Notation supports a number of different key management systems. In this workshop, you'll use Azure Key Vault to store the keys used to sign container images. To use Azure Key Vault with Notation, you'll need to install the Azure Key Vault plugin for Notation.

Run the following command to install the Azure Key Vault plugin for Notation:

<details>

<summary>Linux</summary>

```bash
curl -Lo notation-azure-kv.tar.gz \
https://github.com/Azure/notation-azure-kv/releases/download/v0.5.0-rc.1/notation-azure-kv_0.5.0-rc.1_Linux_amd64.tar.gz

[ -d ~/.config/notation/plugins/azure-kv ] || mkdir -p ~/.config/notation/plugins/azure-kv
tar xvzf notation-azure-kv.tar.gz -C ~/.config/notation/plugins/azure-kv notation-azure-kv > /dev/null 2>&1
rm -rf notation-azure-kv.tar.gz
```

</details>

<details>

<summary>Windows</summary>

```powershell
Invoke-WebRequest -Uri 'https://github.com/Azure/notation-azure-kv/releases/download/v0.5.0-rc.1/notation-azure-kv_0.5.0-rc.1_Windows_amd64.zip' -OutFile notation-azure-kv_0.5.0-rc.1_Windows_amd64.zip

if(!(Test-Path $env:APPDATA/notation/plugins/azure-kv)) { New-Item -ItemType Directory -Path $env:APPDATA/notation/plugins/azure-kv | Out-Null }
Expand-Archive ./notation-azure-kv_0.5.0-rc.1_Windows_amd64.zip $env:APPDATA/notation/plugins/azure-kv
Remove-Item ./notation-azure-kv_0.5.0-rc.1_Windows_amd64.zip
```

</details>



### Adding a key to Notary

As part of the Terraform deployment, a self-signed certificate was created and stored in Azure Key Vault. You'll use this certificate to sign container images. The key identifier for the certificate is used to add the certificate to Notary with the `notation key add` command.

Run the following `azcli` command to retrieve the key identifier for the certificate:

```bash
keyId=$(az keyvault certificate show --name $CERT_NAME --vault-name $KEYVAULT_NAME --query kid -o tsv)
```

Run the following command to add the certificate to Notary:

```bash
notation key add --plugin azure-kv $CERT_NAME --id $keyId
```

To verify the key was added successfully, run the following command:

```bash
notation key list
```

### Creating an Azure Container Registry token

In order to sign a container image, you'll need to create a token for the Azure Container Registry. This token will be used by the Notary CLI to authenticate with the Azure Container Registry and sign the container image.

Run the following command to create a token for the Azure Container Registry:

```bash
tokenName=exampleToken
tokenPassword=$(az acr token create \
    --name $tokenName \
    --registry $ACR_NAME \
    --scope-map _repositories_admin \
    --query 'credentials.passwords[0].value' \
    --only-show-errors \
    --output tsv)
```

### Signing the container image with Notation

Now that you have a token for the Azure Container Registry, you can use Notation to sign the `azure-voting-app-rust` and `postgres:15.0-alpine` container images.

Run the following command to sign the container image:

```bash
notation sign --key $CERT_NAME $ACR_NAME.azurecr.io/azure-voting-app-rust:v0.1-alpha -u $tokenName -p $tokenPassword

notation sign --key $CERT_NAME $ACR_NAME.azurecr.io/postgres:15.0-alpine -u $tokenName -p $tokenPassword
```

---

## Deploy Gatekeeper and Ratify

In this section, you'll deploy Gatekeeper and Ratify to your Azure Kubernetes Service cluster. Gatekeeper is an open-source project from the CNCF that allows you to enforce policies on your Kubernetes cluster. Ratify is a tool that allows you to deploy policies and constraints that prevent unsigned container image from being deployed to Kubernetes.

### Get the Kubernetes credentials

Run the following command to get the Kubernetes credentials for your cluster:

```bash
az aks get-credentials --resource-group ${GROUP_NAME} --name ${AKS_NAME}
```

### Deploy Gatekeeper

Run the following command to deploy Gatekeeper to your cluster:

```bash
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

helm install gatekeeper/gatekeeper  \
--name-template=gatekeeper \
--namespace gatekeeper-system --create-namespace \
--set enableExternalData=true \
--set validatingWebhookTimeoutSeconds=5 \
--set mutatingWebhookTimeoutSeconds=2
```

### Deploy Ratify

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

### Deploy Ratfiy policies

Once Ratify is deployed, you'll need to deploy the policies and constraints that prevent unsigned container images from being deployed to Kubernetes.

Run the following command to deploy the Ratify policies to your cluster:

```bash
kubectl apply -f https://deislabs.github.io/ratify/library/default/template.yaml
kubectl apply -f https://deislabs.github.io/ratify/library/default/samples/constraint.yaml
```

---

## Deploy the Azure Voting App

Now that the container images are signed, you can redeploy the Azure Voting app to your cluster.

Open the `deployment-app.yml` and `deployment-db.yml` files in the `azure-voting-app-rust` directory. Replace the `image` property with the fully qualified name of the container image in your Azure Container Registry.

<details>
<summary>deployment-app.yml</summary>

```yaml
    spec:
      containers:
      - image: exampleacr12345678.azurecr.io/azure-voting-app-rust:v0.1-alpha
        name: azure-voting-app-rust
```

</details>

<details>
<summary>deployment-db.yml</summary>

```yaml
    spec:
      containers:
      - image: exampleacr12345678.azurecr.io/postgres:15.0-alpine
        name: postgres
```

</details>

Run the following command to deploy the Azure Voting app to your cluster:

```bash
cd manifest
kubectl apply -f .
```

---

## Build a CI CD Pipeline with GitHub Actions

In this section, you'll build a CI/CD pipeline with GitHub Actions that will build, scan, sign, and deploy the Azure Voting app to your Azure Kubernetes Service cluster. To follow along, you'll need to fork this repository to your GitHub account.

### Create an Azure Service Principal for the GitHub Actions workflow

First, you'll need to create a Service Principal for the GitHub Actions workflow to use to authenticate to Azure.

Run the following command to create a Service Principal:

```bash
az ad sp create-for-rbac --name "azure-voting-app-rust-sdk" --role contributor \
    --scopes /subscriptions/$subscriptionId/resourceGroups/$GROUP_NAME \
    --sdk-auth
```

<details>

<summary>Example Output</summary>

```output
{
  "clientId": "00000000-0000-0000-0000-000000000000",
  "clientSecret": "00000000-0000-0000-0000-000000000000",
  "subscriptionId": "00000000-0000-0000-0000-000000000000",
  "tenantId": "00000000-0000-0000-0000-000000000000",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

</details>

Take note of the JSON output and store it in a secure location. You'll use it later to create a GitHub secret.

### Create an Access Policy for the Service Principal

Next, you'll need to create an access policy for the Service Principal that grants key sign and secert get permssions on the Azure Key Vault instance.

Run the following command to create an access policy for the Service Principal:

```bash
objectId=${az ad sp list --display-name azure-voting-app-rust-sdk --query '[].id' --output tsv}
az keyvault set-policy --name $KEYVAULT_NAME --object-id $objectId --key-permissions sign --secret-permissions get
```

### Create the AZURE_CREDENTIALS secret


Go to [GitHub](https://github.com) and browse to the repository you forked earlier. Next, click `Secrets and variables` > `Settings` > `Actions`. Then on the `Actions` page, click `New repository secret`.

In the `Name` field, enter `AZURE_CREDENTIALS`. In the `Value` field, enter the JSON output from the previous step. Then click `Add secret`.

### Add the signing certificate keyId as a secret

Click `New repository secret`, then in the `Name` field, enter `SIGN_CERT_KEY_ID`. In the `Value` field, enter the signing certificate keyId. Then click `Add secret`.

If you don't remember the signing certificate keyId, you can run the following command to retrieve it:

```bash
az keyvault certificate show --name $CERT_NAME --vault-name $KEYVAULT_NAME --query kid -o tsv
```

### Add the Azure Container Registry token as a secret

Click `New repository secret`, then in the `Name` field, enter `TOKEN_USERNAME`. In the `Value` field, enter the name of Azure Container Registry token. Then click `Add secret`.


Next, click `New repository secret`, then in the `Name` field, enter `TOKEN_PASSWORD`. In the `Value` field, enter the password of Azure Container Registry token. Then click `Add secret`.


Both the `TOKEN_USERNAME` and `TOKEN_PASSWORD` secrets were created when you deployed Ratify earlier in this workshop. If you don't remember the token name or password, you can run displaying the values of the variables you exported earlier in this workshop:

```bash
echo $tokenName
echo $tokenPassword
```

## Modify the GitHub Actions workflow

Within the `.github/workflows/main.yml` file, you'll find a GitHub Actions workflow that builds, scans, signs, and deploys the Azure Voting app to your Azure Kubernetes Service cluster.

Take a moment to review the workflow and familiarize yourself with the steps.

In order for the workflow to work for your environment, you'll need to modify the following variables:

- `RG_NAME` - The name of your Azure Resource Group
- `ACR_NAME` - The name of your Azure Container Registry
- `AKV_NAME` - The name of your Azure Key Vault
- `AKS_NAME` - The name of your Azure Kubernetes Service cluster
- `CERT_NAME` - The name of your signing certificate

Open the `.github/workflows/main.yml` file and replace the above environment variables with the values for your environment.

<details>

<summary>Example GitHub Actions workflow env variables</summary>

```yaml
env:
  RG_NAME: example-rg12345678
  ACR_NAME: exampleacr12345678
  AKV_NAME: examplekv12345678
  AKS_NAME: exampleaks12345678
  CERT_NAME: examplecert12345678
```

</details>

If you've been following along with this workshop, you'll likely have to update the `sed` command in the `deploy` job to match the name of your Azure Container Registry. Review the `deploy` job and update the `sed` command to match the name of your Azure Container Registry.

<details>

<summary>Example GitHub Actions workflow sed commands</summary>

```yaml
sed -i 's/exampleacr12345678/${{ env.ACR_NAME }}/g;s/v0.1-alpha/${{ github.sha }}/g' deployment-app.yaml
sed -i 's/exampleacr12345678/${{ env.ACR_NAME }}/g' deployment-db.yaml
```

Replace `exampleacr12345678` with the name of your Azure Container Registry.

</details>

## Trigger the GitHub Actions workflow

Now that you've modified the GitHub Actions workflow, you can trigger it by pushing a change to the repository.

Run the following command to push a change to the repository:

```bash
git commit -am "Trigger GitHub Actions workflow"
git push
```

Browse to the `Actions` tab in your repository and you should see the workflow running.

## Verify the Azure Voting app is deployed

Once the workflow has completed, you can verify the Azure Voting app is deployed to your cluster.

Run the following command to get the external IP address of the Azure Voting app:

```bash
kubectl get ingress azure-voting-app-rust
```

Browse to the external IP address of the Azure Voting app and you should see the Azure Voting app.

<div class="info" data-title="note">

> If you don't see the Azure Voting app, it may take a few minutes for the external IP address to be assigned.

</div>

---
