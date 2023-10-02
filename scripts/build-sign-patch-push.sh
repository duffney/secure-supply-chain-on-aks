cd terraform/;
ACR_NAME="$(terraform output -raw acr_name)"
CERT_NAME="$(terraform output -raw cert_name)"
KEYVAULT_NAME="$(terraform output -raw akv_name)"
cd ..

ACR_IMAGE=${ACR_NAME}.azurecr.io/azure-voting-app-rust:v0.1-alpha
docker build -t $ACR_IMAGE .
docker push $ACR_IMAGE 


trivy image --exit-code 0 --format json --output ./patch.json --scanners vuln --vuln-type os --ignore-unfixed $ACR_IMAGE
sudo ./bin/buildkitd &> /dev/null &
sudo copa patch -i ${ACR_IMAGE} -r ./patch.json -t v0.1-alpha-1
ACR_IMAGE_PATCHED=${ACR_NAME}.azurecr.io/azure-voting-app-rust:v0.1-alpha-1
docker push $ACR_IMAGE_PATCHED

KEY_ID=$(az keyvault certificate show --name $CERT_NAME --vault-name $KEYVAULT_NAME --query kid -o tsv)
notation key add --plugin azure-kv $CERT_NAME --id $KEY_ID --default
APP_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $ACR_IMAGE_PATCHED)
notation sign $APP_DIGEST

docker pull postgres:15.0-alpine
docker tag postgres:15.0-alpine $ACR_NAME.azurecr.io/postgres:15.0-alpine
docker push ${ACR_NAME}.azurecr.io/postgres:15.0-alpine

DB_DIGEST=$(docker image inspect --format='{{range $digest := .RepoDigests}}{{println $digest}}{{end}}' ${ACR_NAME}.azurecr.io/postgres:15.0-alpine | sort | tail -1)
notation sign $DB_DIGEST