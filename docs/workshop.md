---
short_title: Securing container deployments on Azure Kubernetes Service with open-source tools
description: Learn how to use open-source tools to secure your container deployments on Azure Kubernetes Service.
type: workshop
authors: Josh Duffney 
contacts: '@joshduffney'
banner_url: assets/copilot-banner.jpg
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


<div class="info" data-title="Note">

> Certain Azure resources need to be globally unique. If you receive an error that a resource already exists, you may need to change the name of the resource in the `terraform.tfvars` file.

</div>

### Export Terraform output as environment variables

As part of the Terraform deployment, several output variables were created. These variables will be used by the other tools in this workshop. 

Run the following command to export the Terraform output as environment variables:

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

---

## Scanning Container Images for Vulnerabilities

Image scanning is a critical part of the container lifecycle. In this section, you'll use Trivy to scan a container image for vulnerabilities and secrets.

### Build the container image

Within this repository, there is a `Dockerfile` that will build a container image that hosts the Azure Voting App. The Azure Voting App is a simple Rust application that allows users to vote on their favorite pet.

Run the following command to build the container image from the root of this repository:

```bash
docker build -t azure-voting-app-rust:v0.1-alpha .
```

### Download Trivy

Installing Trivy is as simple as downloading the binary for your operating system. Browse to the [Trivy Installation page](https://aquasecurity.github.io/trivy/v0.40/getting-started/installation/) and download the binary for your operating system.

### Use Trivy to scan for vulnerabilities and secrets

Once you've downloaded Trivy, you can use it to scan container images for vulnerabilities.

Run the following command to scan the `azure-voting-app-rust` container image for vulnerabilities:

```bash
trivy image azure-voting-app-rust:v0.1-alpha
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

You'll notice from the output that Trivy reports 14 vulnerabilities, all of which are `CRITICAL`. 

### Update the second stage of the Dockerfile

The `azure-voting-app-rust` container image is built in two stages. The first stage builds the application and the second stage copies the application into a new container image. The second stage is where the vulnerabilities are introduced because it's using an outdated base image.

Open the `Dockerfile` in your favorite editor and update the second stage to use the `debian:bullseye-20230411` base image.

```dockerfile
###############
## run stage ##
###############
FROM debian:bullseye-20230411
```

Rebuild the container image with the updated `Dockerfile`:

```bash
docker build -t azure-voting-app-rust:v0.1-alpha .
```

Next, clear the Trivy cache and scan the updated container image:

```bash
trivy image --clear-cache;
trivy image --severity CRITICAL azure-voting-app-rust:v0.1-alpha
```

```bash
trivy --exemption-file=exemptions.yaml image --severity CRITICAL azure-voting-app-rust:v0.1-alpha
```

<details>
<summary>Example Output</summary>

```output
2023-04-28T10:17:05.643-0500    INFO    Vulnerability scanning is enabled
2023-04-28T10:17:05.643-0500    INFO    Secret scanning is enabled
2023-04-28T10:17:05.643-0500    INFO    If your scanning is slow, please try '--scanners vuln' to disable secret scanning
2023-04-28T10:17:05.643-0500    INFO    Please see also https://aquasecurity.github.io/trivy/v0.40/docs/secret/scanning/#recommendation for faster secret detection
2023-04-28T10:17:08.867-0500    INFO    Detected OS: debian
2023-04-28T10:17:08.867-0500    INFO    Detecting Debian vulnerabilities...
2023-04-28T10:17:08.891-0500    INFO    Number of language-specific files: 0

azure-voting-app-rust:v0.1-alpha (debian 11.6)

Total: 1 (CRITICAL: 1)

┌──────────┬───────────────┬──────────┬───────────────────┬───────────────┬────────────────────────────────────────────────────────┐
│ Library  │ Vulnerability │ Severity │ Installed Version │ Fixed Version │                         Title                          │
├──────────┼───────────────┼──────────┼───────────────────┼───────────────┼────────────────────────────────────────────────────────┤
│ libdb5.3 │ CVE-2019-8457 │ CRITICAL │ 5.3.28+dfsg1-0.8  │               │ sqlite: heap out-of-bound read in function rtreenode() │
│          │               │          │                   │               │ https://avd.aquasec.com/nvd/cve-2019-8457              │
└──────────┴───────────────┴──────────┴───────────────────┴───────────────┴────────────────────────────────────────────────────────┘
```

</details>


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

---

## Signing Container Images