cd terraform/
export ACR_NAME="$(terraform output -raw acr_name)"
ACR_IMAGE=${ACR_NAME}.azurecr.io/azure-voting-app-rust:v0.1-alpha
terraform destroy --auto-approve
cd ..

sed -i "s|${ACR_IMAGE}|azure-voting-app-rust:v0.1-alpha|" ./manifests/deployment-app.yaml
sed -i "s|${ACR_NAME}.azurecr.io\/postgres:15.0-alpine|postgres:15.0-alpine|" ./manifests/deployment-db.yaml

docker rmi -f $(docker images -aq)