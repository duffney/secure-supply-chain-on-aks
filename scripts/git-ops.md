prerequisites:
- Create access token on github
- Setup the Azure environment
- Configure the GitHub action workflow

## Setup local env

```bash
git clone 
```

## Install Flux and Kustomize

#TODO: Add to install-dev-tools.sh
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
```

## Boostrap FluxCD on your Cluster
  
  ```bash
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>

flux bootstrap github \
  --token-auth \
  --owner=$GITHUB_USER \
  --repository=secure-supply-chain-on-aks \
  --branch=copaGitOps \
  --path=clusters/my-cluster \
  --personal
```

```bash
git pull
```

### Create a Source for the azure-voting app

```bash
flux create secret git azure-voting \
  --url=https://github.com/duffney/secure-supply-chain-on-aks \
  --username=$GITHUB_USER \
  --password=$GITHUB_TOKEN
```

```bash
flux create source git azure-voting \
  --url=https://github.com/duffney/secure-supply-chain-on-aks/ \
  --branch=GitOps \
  --interval=1m \
  --secret-ref azure-voting \
  --export > ./clusters/my-cluster/azure-voting-source.yaml

#TODO --secret-ref 

flux get sources git
```

### Create a Kustomization for the azure-voting app

```bash

flux create kustomization azure-voting \
  --source=azure-voting \
  --path="./manifests" \
  --prune=true \
  --wait=true \
  --interval=1m \
  --retry-interval=2m \
  --health-check-timeout=3m \
  --export > ./clusters/my-cluster/azure-voting-kustomization.yaml

flux get kustomizations
```

```bash
git add ; git commit -m "Add azure-voting app" ; git push
```

<!-- ../kustomize create --autodetect
add namesace -->

### View FluxCD logs & events

```bash
flux events
flux logs
```

### View the azure-voting app

```bash
kubectl get pods
kubectl get ingress
```

