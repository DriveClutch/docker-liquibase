#!/bin/bash

set -e 

PROFILE=$1
CLUSTER=$2
SERVICE=$3

echo "SHUTTING DOWN $SERVICE IN $CLUSTER"
/app/ecs-set-desired -profile $PROFILE -cluster $CLUSTER -service $SERVICE -desired 0