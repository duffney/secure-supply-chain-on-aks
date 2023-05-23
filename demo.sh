#!/bin/bash

. ./util.sh
source ./demo.env

run 'clear'

desc "Push a change to start the build process"
run "echo >> README.md"
run "git add .; git commit -m 'Demo: Live from Microsoft Build!'; git push"

desc 'Scan the image for OS vulnerabilities: scanner options vuln,config,secret,license'
run './trivy image --exit-code 0 --format json --output ./patch.json --scanners vuln --vuln-type os --ignore-unfixed  $IMAGE'

desc "Review vulnerable packages found in the image"
run "cat patch.json | jq '.Results[0].Vulnerabilities[] | .PkgID' | sort | uniq"

sudo ./buildkitd &> /dev/null & 
desc "Use Copacetic to update the vulnerable packages in the image."
run "sudo ./copa patch -i ${IMAGE} -r ./patch.json -t v0.1-alpha-patched"
sudo pkill buildkitd

desc "Show the patched image"
run "docker images | grep patched"

desc "Run Trivy on the patched image"
run "./trivy image --severity HIGH --scanners vuln ${IMAGE}-patched"

desc "Push the patched image to ACR"
run "docker push ${IMAGE}-patched"

desc "Sign the patched image"
run "./notation sign --key $CERT_NAME ${IMAGE}-patched -u $TOKEN_NAME -p $TOKEN_PASSWORD"

desc "View signature metadata in Azure portal"
run "xdg-open https://portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.ContainerRegistry%2Fregistries"

desc "Modify the app deployment manifests to use the signed image"
run "sed -i 's/v0\.1-alpha/v0.1-alpha-patched/' ./manifests/deployment-app.yaml"
run "code ./manifests/deployment-app.yaml"

desc "Pull, tag, and push the postgres image to ACR"
run "docker pull postgres:15.0-alpine"
run "docker tag postgres:15.0-alpine ${ACR_NAME}.azurecr.io/postgres:15.0-alpine"
run "docker push ${ACR_NAME}.azurecr.io/postgres:15.0-alpine"

desc "Sign postgres:15.0-alpine image"
run "./notation sign --key $CERT_NAME ${ACR_NAME}.azurecr.io/postgres:15.0-alpine -u $TOKEN_NAME -p $TOKEN_PASSWORD"

desc "Modify the db deployment manifests to use the signed image"
run "sed -i 's/postgres:15.0-alpine/${ACR_NAME}.azurecr.io\/postgres:15.0-alpine/g' ./manifests/deployment-db.yaml"
run "code ./manifests/deployment-db.yaml"

desc "Install Gatekeeper on AKS"
run "helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts"
run "helm install gatekeeper/gatekeeper --name-template=gatekeeper --namespace gatekeeper-system --create-namespace --set enableExternalData=true --set validatingWebhookTimeoutSeconds=5 --set mutatingWebhookTimeoutSeconds=2"

desc "Install Ratify on AKS"
run "helm repo add ratify https://deislabs.github.io/ratify"
run "helm install ratify ratify/ratify --atomic --namespace gatekeeper-system --set akvCertConfig.enabled=true --set akvCertConfig.vaultURI=${VAULT_URI} --set akvCertConfig.cert1Name=${CERT_NAME} --set akvCertConfig.tenantId=${TENANT_ID} --set oras.authProviders.azureWorkloadIdentityEnabled=true --set azureWorkloadIdentity.clientId=${CLIENT_ID}"

desc "Apply the Ratify constraint"
run "kubectl apply -f ./manifests/template.yaml"
run "kubectl apply -f ./manifests/constraint.yaml"

desc "View the Ratify constraint"
run "code ./manifests/constraint.yaml"

desc "Run an unsign image"
run "kubectl run unsigned --image ${IMAGE}"
kubectl delete pod unsigned >> /dev/null 2>&1

desc "Check the Ratify logs"
run "kubectl logs deployment/ratify --namespace gatekeeper-system"

desc "Run the azure-voting-app-rust application with signed images"
run "kubectl apply -f ./manifests"

desc "Check if verification was successful"
run "kubectl logs deployment/ratify --namespace gatekeeper-system"

desc "Delete the azure-voting-app-rust"
run "kubectl delete -f ./manifests"

sed -i "s/${ACR_NAME}\.azurecr\.io\/postgres:15\.0-alpine/postgres:15\.0-alpine/g" ./manifests/deployment-db.yaml
sed -i 's/v0\.1-alpha-patched/v0.1-alpha/' ./manifests/deployment-app.yaml

desc "Open GitHub Action workflow"
run "code ./.github/workflows/main.yml"