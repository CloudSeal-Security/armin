#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if ! (( $# ))
then
    echo "usage: $0 <base-href>"
    exit 1
fi

npm install
sudo  npm install -g @angular/cli@16.0.0-next.0
# WARN: deployUrl deprecated since Angular 13, pending decommission in future ng CLI
ng build ziti-console --base-href "$1" --deploy-url "$1" --configuration "production"

sudo rm -fr /opt/openziti/share/console/*
sudo cp -r ./dist/app-ziti-console/* /opt/openziti/share/console/
sudo systemctl restart ziti-controller.service
