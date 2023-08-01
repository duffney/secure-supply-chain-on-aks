# Build a secure pipeline with GitHub Actions

<!-- blog post -->

In this section, you'll build a pipeline with GitHub Actions that will build, scan, sign, and deploy the Azure Voting app to your Azure Kubernetes Service cluster. To follow along, you'll need to fork this repository to your GitHub account.

## Login into the GitHub CLI

First, you'll need to sign into the GitHub CLI. Run the following command and follow the prompts to sign in:

```bash
gh auth login
```

<div class="tip" data-title="Tip">

> There are several ways to authenticate with the GitHub CLI. To help you choose the best option for your environment, see the [GitHub CLI authentication documentation](https://cli.github.com/manual/gh_auth_login).

</div>

## Refresh Azure resources variables

Next, you'll need to refresh the environment variables for the Azure resources you created earlier in this workshop. Run the following commands to refresh the environment variables:

```bash
subscriptionId=$(az account show --query id --output tsv);
cd terraform/;
export GROUP_NAME="$(terraform output -raw rg_name)"
export AKS_NAME="$(terraform output -raw aks_name)"
export VAULT_URI="$(terraform output -raw akv_uri)"
export AKV_NAME="$(terraform output -raw akv_name)"
export ACR_NAME="$(terraform output -raw acr_name)"
export CERT_NAME="$(terraform output -raw cert_name)"
export TENANT_ID="$(terraform output -raw tenant_id)"
export CLIENT_ID="$(terraform output -raw wl_client_id)"
cd ..
```

## Create an Azure Service Principal

First, you'll need to create a Service Principal for the GitHub Actions workflow to use to authenticate to Azure.

Run the following command to create a Service Principal:
<!-- TODO: replace with fed creds -->
```bash
spDisplayName='github-workflow-sp'
credJSON=$(az ad sp create-for-rbac --name $spDisplayName --role contributor \
--scopes /subscriptions/$subscriptionId/resourceGroups/$GROUP_NAME \
--sdk-auth)
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


Next, you'll need to create an access policy for the Service Principal that grants key sign and secert get permssions on the Azure Key Vault instance.

Run the following command to create an access policy for the Service Principal:

```bash
objectId=$(az ad sp list --display-name $spDisplayName --query '[].id' --output tsv);
az keyvault set-policy --name $AKV_NAME --object-id $objectId --key-permissions sign --secret-permissions get
```

### Create the AZURE_CREDENTIALS secret

```bash
gh secret set AZURE_CREDENTIALS --body "$credJSON"
```



### Create Azure resource variables

```bash
KEY_ID=$(az keyvault certificate show --name $CERT_NAME --vault-name $AKV_NAME --query kid -o tsv)
gh variable set ACR_NAME --body "$ACR_NAME";
gh variable set CERT_NAME --body "$CERT_NAME";
gh variable set KEY_ID --body "$KEY_ID";
```

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
