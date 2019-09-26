#!/bin/bash

set -e

gcloud compute instances create reddit-app \
  --boot-disk-size=15GB \
  --image=reddit-full-1569449699 \
  --machine-type=g1-small \
  --tags=puma-server \
  --zone=europe-west1-b \
  --restart-on-failure
