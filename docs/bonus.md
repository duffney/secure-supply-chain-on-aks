# Build a secure pipeline with GitHub Actions

<!-- blog post -->

In this workshop, you will learn how to build a secure pipeline using GitHub Actions to build, scan, sign, and deploy the Azure Voting app to your Azure Kubernetes Service cluster. To get started, make sure to fork this repository to your GitHub account.

## Login into the GitHub CLI

First, you'll need to sign into the GitHub CLI. Run the following command and follow the prompts to sign in:

```bash
gh auth login
```

<div class="tip" data-title="Tip">

> TIP: There are several ways to authenticate with the GitHub CLI. To help you choose the best option for your environment, see the [GitHub CLI authentication documentation](https://cli.github.com/manual/gh_auth_login).

</div>

## Refresh Azure resources variables

Next, refresh the environment variables for the Azure resources created earlier in this workshop. Run the following commands to refresh the environment variables:


```bash
export SUBSCRIPTION_ID=$(az account show --query id --output tsv);
cd terraform/;
export GROUP_NAME="$(terraform output -raw rg_name)"
export AKV_NAME="$(terraform output -raw akv_name)"
export ACR_NAME="$(terraform output -raw acr_name)"
export CERT_NAME="$(terraform output -raw cert_name)"
cd ..
```

## Create an Azure Service Principal

First, you'll need to create a Service Principal for the GitHub Actions workflow to use to authenticate to Azure.

Run the following command to create a Service Principal:
<!-- TODO: replace with fed creds -->
<!-- TODO: Remove contrib role with acrpull,acrpush -->
```bash
spDisplayName='github-workflow-sp';
credJSON=$(az ad sp create-for-rbac --name $spDisplayName --role contributor \
--scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$GROUP_NAME \
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
az keyvault set-policy --name $AKV_NAME --object-id $objectId --certificate-permissions get --key-permissions sign --secret-permissions get
```

> NOTE: These permissions are used to get the secret from the signing certificate.

### Create the AZURE_CREDENTIALS secret

Create a Service Principal for the GitHub Actions workflow to authenticate with Azure. Execute the following command to create a Service Principal:

```bash
gh secret set AZURE_CREDENTIALS --body "$credJSON"
```

### Create Azure resource variables

Create the following GitHub secrets to store the Azure resource variables:

```bash

gh variable set ACR_NAME --body "$ACR_NAME";
gh variable set CERT_NAME --body "$CERT_NAME";
gh variable set KEY_ID --body "$KEY_ID";
```

### Trigger the GitHub Actions workflow

Now that you've modified the GitHub Actions workflow, you can trigger it by pushing a change to the repository.

Run the following command to push a change to the repository:

```bash
#Push a change to start the build process
echo >> README.md
git add .; git commit -m 'Demo: Lets do it live!'; git push
```

Browse to the `Actions` tab in your repository and you should see the workflow running. Wait for the workflow to complete. Then check the logs for the message 'Successfully signed...' in the logs to confirm the image was signed.

---
