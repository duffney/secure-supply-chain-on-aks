flux create secret git aks-store-demo \
  --url=$GITHUB_REPO_URL \
  --username=$GITHUB_USER \
  --password=$GITHUB_TOKEN


image repository

flux create image repository store-front \
  --image=s3cexampleacr.azurecr.io/azure-voting-app-rust \
  --interval=1m \
  --export > ./clusters/dev/aks-store-demo-store-front-image.yaml

image policy

flux create image policy store-front \
  --image-ref=store-front \
  --select-semver='>=1.0.0-0' \ # update this to get the latest patched version
  --export > ./clusters/dev/aks-store-demo-store-front-image-policy.yaml

image update automation

flux create image update store-front \
  --interval=1m \
  --git-repo-ref=azure-voting \
  --git-repo-path="./manifests" \
  --checkout-branch=main \
  --author-name=fluxcdbot \
  --author-email=fluxcdbot@users.noreply.github.com \
  --commit-template="{{range .Updated.Images}}{{println .}}{{end}}" \
  --export > ./clusters/dev/azure-voting-image-update.yaml

Mark the manifests

image: # {"$imagepolicy": "flux-system:store-front"}

https://github.com/pauldotyu/aks-store-demo-manifests/blob/istio/overlays/dev/kustomization.yaml