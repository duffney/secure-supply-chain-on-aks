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

# Securing container deployments on Azure Kubernetes Service by using open-source tools

In this workshop, you'll learn how to use open-source tools; Trivy, Copacetic, Notary, and Ratify to secure your container deployments on Azure Kubernetes Service.

## Objectives

You'll learn how to:
- Use Trivy to scan container images for vulnerabilities
- Automate container image patching with Copacetic
- Sign container images with Notation 
- Prevent unsigned container images from being deployed with Ratify 

## Prerequisites

| | |
|----------------------|------------------------------------------------------|
| GitHub account       | [Get a free GitHub account](https://github.com/join) |
| Azure account        | [Get a free Azure account](https://azure.microsoft.com/free) |
| Visual Studio Code   | [Install VS Code](https://code.visualstudio.com/download) |

---

## Set up your environment

In order to complete this workshop, you'll need to set up your environment. This includes cloning the workshop repository, building the Azure Voting App container images, and deploying the Azure resources with Terraform.

### Start the dev container

The provided repository includes a dev container that installs all the necessary tools required for the workshop. A dev container is essentially a Docker container that comes preloaded with all the tools you need to successfully participate in the workshop.

Clone the workshop repository and open the repository in VS Code.

```bash
git clone https://github.com/duffney/secure-supply-chain-on-aks.git
```

Next, open the repository in VS Code.

```bash
cd secure-supply-chain-on-aks
code .
```

VS Code will prompt you to reopen the repository in a dev container. Click **Reopen in Container**. This will take a few minutes to build the dev container.

<div class="tip" data-title="Tip">

> If you don't see the prompt, you can open the command palette by hitting `Ctrl+Shift+P` on Windows or `Cmd+Shift+P` on Mac and search for **Dev Containers: Reopen in Container**.

</div>

### Build and pull the Azure Voting App container images

Within this repository, there is a `Dockerfile` that will build a container image that hosts the Azure Voting App. 

The Azure Voting App is a simple Rust application that allows users to vote between the two options presented and stores the results in a database.

Run the following command to build the Azure Voting web app container image 

```bash
docker build -t azure-voting-app-rust:v0.1-alpha .
```

Next pull the `PostgreSQL` container image from Docker Hub. This will be used to store the votes.

```bash
docker pull postgres:15.0-alpine
```

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

---

## Scanning container images for vulnerabilities

<!-- Demo starts here -->

Containerization has become an integral part of modern software development and deployment. However, with the increased adoption of containers, there comes a need for ensuring their security. 

In this section, you'll learn how to use Trivy to scan a container image for vulnerabilities.

### Running Trivy for Vulnerability Scans

Trivy is an open-source vulnerability scanner specifically designed for container images. It provides a simple and efficient way to detect vulnerabilities in containerized applications. 

Trivy leverages a comprehensive vulnerability database and checks container images against known security issues, including vulnerabilities in the operating system packages, application dependencies, and other components.

Run the following command to scan the `azure-voting-app-rust` container image for vulnerabilities:

```bash
IMAGE=azure-voting-app-rust:v0.1-alpha;
trivy image $IMAGE;
```

<detials>
<summary>Example Output</summary>

```output
2023-07-14T17:08:57.400Z        INFO    Vulnerability scanning is enabled
2023-07-14T17:08:57.401Z        INFO    Secret scanning is enabled
2023-07-14T17:08:57.401Z        INFO    If your scanning is slow, please try '--scanners vuln' to disable secret scanning
2023-07-14T17:08:57.401Z        INFO    Please see also https://aquasecurity.github.io/trivy/v0.41/docs/secret/scanning/#recommendation for faster secret detection
2023-07-14T17:08:57.418Z        INFO    Detected OS: debian
2023-07-14T17:08:57.418Z        INFO    Detecting Debian vulnerabilities...
2023-07-14T17:08:57.448Z        INFO    Number of language-specific files: 0

azure-voting-app-rust:v0.1-alpha (debian 11.2)
==============================================
Total: 154 (UNKNOWN: 0, LOW: 76, MEDIUM: 27, HIGH: 37, CRITICAL: 14)
...........................................................
...........................................................
```

</details>

Trivy will start scanning the specified container image for vulnerabilities. It will analyze the operating system, application packages, and libraries within the container to identify any known security issues.

### Adjusting Severity Levels

Trivy allows you to customize the severity level of the reported vulnerabilities. By default, it provides information about vulnerabilities of all severity levels. However, you can narrow down the results based on your requirements.

For example, if you only want to see vulnerabilities classified as CRITICAL, you can modify the command as follows:

```bash
trivy image --severity CRITICAL $IMAGE
```

</details>

### Filtering vulnerabilities by type

By default, Trivy scans for vulnerabilities in all components of the container image, including the operating system packages, application dependencies, and libraries. However, you can narrow down the results by specifying the type of vulnerabilities you want to see.

For example, if you only want to see vulnerabilities in the operating system packages, you can modify the command as follows:

```bash
trivy image --vuln-type os $IMAGE
```

### Chosing a scanner

Trivy supports four scanner options; vuln, config, secret, and license. Vuln is the default scanner and it scans for vulnerabilities in the container image. Config scans for misconfiguration in infrastructure as code configurations, like Terraform. Secret scans for sensitive information and secrets in the project files. And license scans for software license issues.

You can specify the scanner you want to use by using the `--scanners` option. For example, if you only want to use the vuln scanner, you can modify the command as follows:

```bash
trivy image --scanners vuln $IMAGE
```

### Exporting a vulnerability report

Seeing the vulnerability reports in the terminal is useful, but it's not the most convenient way to view the results. Trivy allows you to export the vulnerability report in a variety of formats, including JSON, HTML, and CSV.

Run the following command to export the vulnerability report in JSON format:

```bash
trivy image --exit-code 0 --format json --output ./patch.json --scanners vuln --vuln-type os --ignore-unfixed  $IMAGE
```

Having a point-in-time report of the vulnerabilites discovered in your container is certainly a nice to have, but wouldn't it be even more awesome if that report was used to automatically add patched layers to the container image?

---

## Using Copacetic to patch container images

Copacetic is an open-source tool that helps you patch container images for vulnerabilities. It uses Trivy vulnerability reports to identify the vulnerabilities in the container image and adds patched layers to the image to fix the vulnerabilities.

In this section, you'll use Copacetic to patch the `azure-voting-app-rust` container image for vulnerabilities.

### Build and push the container images 

A currently limitation of Copacetic is that it can only patch container images that are stored in a remote container registry. So, you'll need to push the `azure-voting-app-rust` container image to the Azure Container Registry.

Run the following commands to build the `azure-voting-app-rust` container image and push it to the Azure Container Registry:

```bash
az acr build --registry $ACR_NAME -t azure-voting-app-rust:v0.1-alpha .
```

<div class="info" data-title="note">

> If you encounter an authentication error, run `az acr login --name $ACR_NAME` command to authenticate to the Azure Container Registry then try the `docker push` command again.

</div>

### Patching the container image

Now that you have your container images built and pushed to the Azure Container Registry, let's proceed with patching them.

First, start the Copacetic buildkit daemon by running the following command:

```bash
sudo ./bin/buildkitd &> /dev/null & 
```

Next, run `copa` to patch the `azure-voting-app-rust` container image:

```bash
ACR_IMAGE=${ACR_NAME}.azurecr.io/azure-voting-app-rust:v0.1-alpha

sudo copa patch -i ${ACR_IMAGE} -r ./patch.json -t v0.1-alpha-patched
```

Once the patching process is complete, there will be a newly patched container image on your local machine. You can view the patched image by running the following command:

```bash
docker images | grep patched
```

To confirm that Copacetic patched the container image, rerun the `trivy image` command on the patched image:

```bash
trivy image --severity CRITICAL --scanners vuln ${ACR_IMAGE}-patched
```

<details>
<summary>Example Output</summary>

```output
2023-07-14T17:45:27.463Z        INFO    Vulnerability scanning is enabled
2023-07-14T17:45:30.157Z        INFO    Detected OS: debian
2023-07-14T17:45:30.157Z        INFO    Detecting Debian vulnerabilities...
2023-07-14T17:45:30.165Z        INFO    Number of language-specific files: 0

s3cexampleacr.azurecr.io/azure-voting-app-rust:v0.1-alpha-patched (debian 11.2)

Total: 1 (CRITICAL: 1)
```

</details>

Lastly, push the patched image tag to the Azure Container Registry:

```bash
docker push ${ACR_IMAGE}-patched
```

---

## Signing container images with Notation

Next, tag the `postgres:15.0-alpine` container image and push it to the Azure Container Registry: 

```bash
docker tag postgres:15.0-alpine $ACR_NAME.azurecr.io/postgres:15.0-alpine
docker push $ACR_NAME.azurecr.io/postgres:15.0-alpine
```
<!-- blog post -->

In this section, you'll use Notary to sign the `azure-voting-app-rust` and `postgres:15.0-alpine` container images. 

Notation is a command line tool from the CNCF Notary project that allows you to sign and verify container images. 

You'll use Notary's command line tool, Notation, to sign and verify container images.

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

<!-- blog post Merge with TF config for post -->

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

### Deploy the Azure Voting App

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