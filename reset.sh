cd terraform/
export ACR_NAME="$(terraform output -raw acr_name)"
ACR_IMAGE=${ACR_NAME}.azurecr.io/azure-voting-app-rust:v0.1-alpha
terraform destroy --auto-approve
cd ..

ACR_IMAGE_PATCHED=${ACR_NAME}.azurecr.io/azure-voting-app-rust:v0.1-alpha-1
APP_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $ACR_IMAGE_PATCHED)
sed -i "s|${APP_DIGEST}|azure-voting-app-rust:v0.1-alpha|" ./manifests/deployment-app.yaml

DB_DIGEST=$(docker image inspect --format='{{range $digest := .RepoDigests}}{{println $digest}}{{end}}' ${ACR_NAME}.azurecr.io/postgres:15.0-alpine | sort | tail -1)
sed -i "s|${DB_DIGEST}|postgres:15.0-alpine|" ./manifests/deployment-db.yaml

docker rmi -f $(docker images -aq)