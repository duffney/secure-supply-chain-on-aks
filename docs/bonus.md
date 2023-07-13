## Build a CI CD Pipeline with GitHub Actions

<!-- blog post -->

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

### Modify the GitHub Actions workflow

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

### Trigger the GitHub Actions workflow

Now that you've modified the GitHub Actions workflow, you can trigger it by pushing a change to the repository.

Run the following command to push a change to the repository:

```bash
git commit -am "Trigger GitHub Actions workflow"
git push
```

Browse to the `Actions` tab in your repository and you should see the workflow running.

### Verify the Azure Voting app is deployed

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
