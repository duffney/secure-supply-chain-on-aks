source ./demo.env
# sed -i "s/${ACR_NAME}\.azurecr\.io\/postgres:15\.0-alpine/postgres:15\.0-alpine/g" ./manifests/deployment-db.yaml
sed -i 's/brk264hacr\.azurecr\.io\/postgres:15\.0-alpine/postgres:15.0-alpine/g' manifests/deployment-db.yaml
sed -i 's/v0\.1-alpha-patched/v0.1-alpha/' ./manifests/deployment-app.yaml
kubectl delete ConstraintTemplate ratifyverification
kubectl delete ConstraintTemplate ratifyverificationdeployment
helm uninstall gatekeeper -n gatekeeper-system
helm uninstall ratify --namespace gatekeeper-system
docker rmi -f $(docker images -aq)
# delete postgres image from ACR
az acr repository delete --name $ACR_NAME --image postgres:15.0-alpine --yes
# delete patched image from ACR
az acr repository delete --name $ACR_NAME --image ${IMAGE}-patched --yes