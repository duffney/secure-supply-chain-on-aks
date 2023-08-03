---
short_title: Securing container deployments on Azure Kubernetes Service with open-source tools
description: Learn how to use open-source tools to secure your container deployments on Azure Kubernetes Service.
type: workshop
authors: Josh Duffney 
contacts: '@joshduffney'
# banner_url: assets/copilot-banner.jpg
duration_minutes: 30
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

![Secure Supply Chain](/imgs/secure-supply-chain-on-aks-overview.png)

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


In order to begin this workshop, you'll need to setup the Azure environment and deploy Gatekeeper and Ratify to your AKS cluster.

Follow the [setup](setup.md) instructions to deploy and configure the infrastructure.

---

## Start the dev container

A local development environment is provided for this workshop using a dev container. It includes all the tools you need to successfully participate in the workshop.

Follow the steps below to fork the repository and open it in VS Code:

1. Fork the repository by navigating to the original repository URL: https://github.com/duffney/secure-supply-chain-on-aks.git. Click on the "Fork" button in the top right corner of the GitHub page. This will create a copy of the repository under your GitHub account.

2. Once the repository is forked, navigate to your forked repository on GitHub. The URL should be https://github.com/your-username/secure-supply-chain-on-aks.git, where "your-username" is your GitHub username.

3. Click on the "Code" button, and copy the URL provided (which will be the URL of your forked repository).

4. Open your terminal or command prompt and run the following command to clone your forked repository:

    ```bash
    git clone https://github.com/your-username/secure-supply-chain-on-aks.git
    ```

5. Change the working directory to the cloned repository:

    ```bash
    cd secure-supply-chain-on-aks
    ```

6. Open the repository in VS Code:

    ```bash
    code . 
    ```

7. VS Code will prompt you to reopen the repository in a dev container. Click **Reopen in Container**. This will take a few minutes to build the dev container.

<div class="tip" data-title="Tip">

> If you don't see the prompt, you can open the command palette by hitting `Ctrl+Shift+P` on Windows or `Cmd+Shift+P` on Mac and search for **Dev Containers: Reopen in Container**.

</div>

---

## Scanning container images for vulnerabilities

<!-- Demo starts here -->

Containerization has become an integral part of modern software development and deployment. However, with the increased adoption of containers, there comes a need for ensuring their security. 

In this section, you'll learn how to use Trivy to scan a container image for vulnerabilities.

### Build and pull the Azure Voting App container images

Before you begin, there is a `Dockerfile` that will build a container image that hosts the Azure Voting App. 

The Azure Voting App is a simple Rust application that allows users to vote between the two options presented and stores the results in a database.

Run the following command to build the Azure Voting web app container image 

```bash
docker build -t azure-voting-app-rust:v0.1-alpha .
```

Next pull the `PostgreSQL` container image from Docker Hub. This will be used to store the votes.

```bash
docker pull postgres:15.0-alpine
```

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
trivy image --vuln-type os --severity CRITICAL $IMAGE
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

sudo copa patch -i ${ACR_IMAGE} -r ./patch.json -t v0.1-alpha
```

Once the patching process is complete, there will be a newly patched container image on your local machine. You can view the patched image by running the following command:

```bash
docker images | grep patched
```

To confirm that Copacetic patched the container image, rerun the `trivy image` command on the patched image:

```bash
trivy image --severity CRITICAL --scanners vuln ${ACR_IMAGE}
```

<details>
<summary>Example Output</summary>

```output
2023-07-14T17:45:27.463Z        INFO    Vulnerability scanning is enabled
2023-07-14T17:45:30.157Z        INFO    Detected OS: debian
2023-07-14T17:45:30.157Z        INFO    Detecting Debian vulnerabilities...
2023-07-14T17:45:30.165Z        INFO    Number of language-specific files: 0

s3cexampleacr.azurecr.io/azure-voting-app-rust:v0.1-alpha

Total: 1 (CRITICAL: 1)
```

</details>

Lastly, push the patched image tag to the Azure Container Registry:

```bash
docker push ${ACR_IMAGE}
```

### Tag and push the Postgres image to ACR

You just pushed a patched version of the `azure-voting-app-rust` image to Azure Container Registry. But the app won't run witout a valid database container. So, next you'll tag and push a version of the Postgres SQL container to your ACR instance.

```bash
docker tag postgres:15.0-alpine $ACR_NAME.azurecr.io/postgres:15.0-alpine
docker push $ACR_NAME.azurecr.io/postgres:15.0-alpine
```

---

## Signing container images with Notation

In this section, you'll learn how to use Notation, a command-line tool from the CNCF Notary project, to sign and verify container images, which adds an extra layer of security to your deployment pipeline.

### Why Sign Container Images?

On the surface, signing container images just seems like more work. But, signing container images is crucial for several reasons:

* **Image Integrity**: Signing verifies that the image hasn't been tampered with or altered since the signature was applied. It ensures that the image you deploy is the exact image you intended to use.
* **Authentication**: Signature validation confirms the authenticity of the image, providing a level of trust in the source.
* **Security and Compliance**: By ensuring image integrity and authenticity, signing helps meet security and compliance requirements, especially in regulated industries.

### Adding a key to Notary

To sign container images with Notation, you need to add a key to the Notary configuration. As part of your infrastructure setup, you created a certificate and stored it in Azure Key Vault. You'll use the KEY_ID of that certificate to identify the certificate used for the digital signatures of your container images.

To get the `KEY_ID` from Azure Key Vault, run the following command:

```bash
KEY_ID=$(az keyvault certificate show --name $CERT_NAME --vault-name $AKV_NAME --query kid -o tsv)
```

Next, add the certificate to Notary using the notation key add command:

```bash
notation key add --plugin azure-kv default --id $KEY_ID --default
```

You can verify that the key was added successfully by running:

```bash
notation key list
```

### Getting the Docker Image Digest

It's possible to sign the container image using the image tag, but it's better to use the image digest. The Docker Image Digest is a unique identifer generated by the SHA256 cryptographic hash function which makes it immutable. If the image is altered in any way, the digest will change and the signature will no longer be valid.

To get the digest of the `azure-voting-app-rust` image, run the following command:

```bash
APP_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $ACR_NAME.azurecr.io/azure-voting-app-rust:v0.1-alpha)

DB_DIGEST=$(docker inspect --format='{{index .RepoDigests 1}}' $ACR_NAME.azurecr.io/postgres:15.0-alpine)
```

<div class="info" data-title="note">

> **Tip**: If you want to always get the most recent RepoDigest, you can use the following command-line trickery:

```bash
docker image inspect --format='{{range $digest := .RepoDigests}}{{println $digest}}{{end}}' <imageName:tag> | sort | tail -1
```

</div>

### Signing the container image with Notation

With the key added to Notary, you can now sign your container images. Let's sign the azure-voting-app-rust and postgres:15.0-alpine images pushed to your Azure Container Registry.

To sign the images, use the following commands:

```bash
notation sign $APP_DIGEST;
notation sign $DB_DIGEST 
```

These commands will apply signatures to the specified images, ensuring their integrity and authenticity.

---

## Preventing unsigned container images from being deployed with Ratify

In this section, you'll learn how to use Ratify to prevent unsigned container images from being deployed to your AKS cluster.

### Deploy Unsigned App Images

The first step is to deploy the app images without any signing. 

Use the following command to apply the manifests:

```bash
kubectl apply -f manifests/
```

Next, check the Ratify logs for the blocked deployment:

```bash
kubectl logs -n gatekeeper-system deployment/ratify
```

<details>
<summary>Example Output</summary>

```output
time="2023-07-26T17:42:33Z" level=error msg="failed to mutate image reference azure-voting-app-rust:v0.1-alpha: HEAD \"https://registry-1.docker.io/v2/library/azure-voting-app-rust/manifests/v0.1-alpha\": response status code 401: Unauthorized"
time="2023-07-26T17:42:33Z" level=warning msg="failed to resolve the subject descriptor from store oras with error HEAD \"https://registry-1.docker.io/v2/library/azure-voting-app-rust/manifests/v0.1-alpha\": response status code 401: Unauthorized\n"
```

</details>

Clean up the failed deployment by running the following command:

```bash
kubectl delete -f manifests/
```

### Deploy Signed App Images

Now that you've seen how Ratify prevents unsigned images from being deployed, let's deploy the signed images.

Use the following command to update the manifests with the signed image tags:

<!-- TODO: remove -patched -->
```bash
sed -i "s|azure-voting-app-rust:v0.1-alpha|$ACR_NAME.azurecr.io/azure-voting-app-rust:v0.1-alpha|" ./manifests/deployment-app.yaml

sed -i "s|postgres:15.0-alpine|$ACR_NAME.azurecr.io/postgres:15.0-alpine|g" manifests/postgres.yaml
```

Next, apply the manifests:

```bash
kubectl apply -f manifests/
```

Lastly, check the pods to confirm that the app is running:

```bash
kubectl get pods
```

<details>

<summary>Example Output</summary>

```output
NAME                               READY   STATUS    RESTARTS   AGE
azure-voting-app-7fb9f67f6-zl64t   1/1     Running   0          17s
azure-voting-db-699fcf6bcd-g4nhz   1/1     Running   0          17s
```

</details>

To understand why Ratify allowed the signed images to be deployed you can take a look at the constraints and templates that were applied to the cluster.

```bash
code manifests/constraints.yaml
code manifests/templates.yaml
```

After a few minutes, check the status of the ingress resource to get the public IP address of the app:

```bash
kubectl get ingress
```

<details>

<summary>Example Output</summary>

```output
NAME               CLASS                                HOSTS   ADDRESS         PORTS   AGE
azure-voting-app   webapprouting.kubernetes.azure.com   *       4.236.203.158   80      60s
```

</details>

Open a browser and navigate to the IP address of the app. You should see the Azure Voting App.

---

References:
- [Build, sign, and verify container images using Notary and Azure Key Vault](https://learn.microsoft.com/azure/container-registry/container-registry-tutorial-sign-build-push)
- [Ratify on Azure: Allow only signed images to be deployed on AKS with Notation and Ratify](https://github.com/deislabs/ratify/blob/main/docs/quickstarts/ratify-on-azure.md)