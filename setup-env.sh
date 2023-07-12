source ./demo.env

docker pull postgres:15.0-alpine
docker tag postgres:15.0-alpine "$ACR_NAME.azurecr.io/postgres:15.0-alpine"
docker push "$ACR_NAME.azurecr.io/postgres:15.0-alpine"