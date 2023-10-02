#!/usr/bin/env bash

sudo apt update;
sudo apt install pv;

curl -L -o trivy_0.41.0_Linux-64bit.tar.gz https://github.com/aquasecurity/trivy/releases/download/v0.41.0/trivy_0.41.0_Linux-64bit.tar.gz;
tar -xzf trivy_0.41.0_Linux-64bit.tar.gz trivy;
rm trivy_0.41.0_Linux-64bit.tar.gz;
sudo mv trivy /bin; 

curl -L -o copa_0.2.0_linux_amd64.tar.gz https://github.com/project-copacetic/copacetic/releases/download/v0.2.0/copa_0.2.0_linux_amd64.tar.gz;
tar -xzf copa_0.2.0_linux_amd64.tar.gz copa;
rm copa_0.2.0_linux_amd64.tar.gz;
sudo mv copa /bin;


curl -L -o buildkit-v0.11.6.linux-amd64.tar.gz https://github.com/moby/buildkit/releases/download/v0.11.6/buildkit-v0.11.6.linux-amd64.tar.gz;
tar -xzf buildkit-v0.11.6.linux-amd64.tar.gz;
rm buildkit-v0.11.6.linux-amd64.tar.gz;

curl -L -o notation_1.0.0_linux_amd64.tar.gz https://github.com/notaryproject/notation/releases/download/v1.0.0/notation_1.0.0_linux_amd64.tar.gz;
tar -xzf notation_1.0.0_linux_amd64.tar.gz;
rm notation_1.0.0_linux_amd64.tar.gz;
sudo mv notation /bin;

curl -L -o notation-azure-kv_1.0.1_linux_amd64.tar.gz https://github.com/Azure/notation-azure-kv/releases/download/v1.0.1/notation-azure-kv_1.0.1_linux_amd64.tar.gz;
tar -xzf notation-azure-kv_1.0.1_linux_amd64.tar.gz;
rm notation-azure-kv_1.0.1_linux_amd64.tar.gz;

mkdir -p "${HOME}/.config/notation/plugins/azure-kv";
mv notation-azure-kv "${HOME}/.config/notation/plugins/azure-kv/"

type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
&& sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& sudo apt update \
&& sudo apt install gh -y

curl -s https://fluxcd.io/install.sh | sudo bash