. ./util.sh

run 'clear'

# desc 'Sign into gh cli'
run 'gh auth login'

desc 'Refresh Azure resources variables...'
export SUBSCRIPTION_ID=$(az account show --query id --output tsv);
cd terraform/;
export GROUP_NAME="$(terraform output -raw rg_name)"
export AKV_NAME="$(terraform output -raw akv_name)"
export ACR_NAME="$(terraform output -raw acr_name)"
export CERT_NAME="$(terraform output -raw cert_name)"
cd ..

desc 'Create an Azure Service Principal'
spDisplayName=github-workflow-sp
run "az ad sp create-for-rbac --name $spDisplayName --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/${GROUP_NAME} --sdk-auth"
credJSON=$(az ad sp create-for-rbac --name $spDisplayName --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$GROUP_NAME --sdk-auth --only-show-errors) >> /dev/null 2>&1

desc 'Create an access policy for the signing cert'
objectId=$(az ad sp list --display-name $spDisplayName --query '[].id' --output tsv)
run "az keyvault set-policy --name ${AKV_NAME} --object-id ${objectId} --certificate-permissions get --key-permissions sign --secret-permissions get"

desc "Create the AZURE_CREDENTIALS secret"
run "gh secret set AZURE_CREDENTIALS --body \"${credJSON}\""

desc "Create GitHub Action variables"
KEY_ID=$(az keyvault certificate show --name $CERT_NAME --vault-name $AKV_NAME --query kid -o tsv)
run "gh variable set ACR_NAME --body \"$ACR_NAME\""
run "gh variable set CERT_NAME --body \"$CERT_NAME\""
run "gh variable set KEY_ID --body \"$KEY_ID\""

desc "Trigger the GitHub Actions workflow"
run "echo >> README.md"
run "git add README.md; git commit -m \"Demo: Let's do it LIVE!\"; git push"

desc "Check workflow status"
run "echo 'https://aka.ms/secure-supply-chain-on-aks'"