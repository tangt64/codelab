#!/bin/bash

dnf install git tar -y
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
mkdir ~/bin
sh get_helm.sh
mv /usr/local/bin/helm ~/bin