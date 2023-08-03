# TODO
. ./util.sh

run 'clear'

desc 'Sign into gh cli'
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
run 