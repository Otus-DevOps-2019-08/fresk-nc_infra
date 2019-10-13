#!/bin/bash

set -e

app_ip=$(gcloud compute instances describe reddit-app --zone europe-west1-b --format json | jq '.networkInterfaces[0].accessConfigs[0].natIP' | tr -d '"')
db_ip=$(gcloud compute instances describe reddit-db --zone europe-west1-b --format json | jq '.networkInterfaces[0].accessConfigs[0].natIP' | tr -d '"')

inventory=$(
    jq -n --arg app_ip $app_ip --arg db_ip $db_ip '{
        "app": {
            "vars": {},
            "hosts": [ $app_ip ]
        },
        "db": {
            "vars": {},
            "hosts": [ $db_ip ]
        },
        "_meta": {
            "hostvars": {}
        }
    }'
)

echo $inventory
