az login > /dev/null 2>&1

# sudo apt -y install xdg-utils;
cd terraform/;
terraform init && terraform apply --auto-approve;
export ACR_NAME="$(terraform output -raw acr_name)";
az acr login $ACR_NAME;