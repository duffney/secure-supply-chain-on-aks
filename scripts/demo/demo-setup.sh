# BRK264H
# source ./demo.env

# docker pull postgres:15.0-alpine
# docker tag postgres:15.0-alpine "$ACR_NAME.azurecr.io/postgres:15.0-alpine"
# docker push "$ACR_NAME.azurecr.io/postgres:15.0-alpine"

# ----

sudo apt update
sudo apt -y install pv
sudo apt -y install xdg-utils
# start devcontainer
# deploy terraform
# build and pull azure voting app images
docker build -t azure-voting-app-rust:v0.1-alpha .
docker pull postgres:15.0-alpine
# pushd pop to terraform run terrtaform init pop back to root
