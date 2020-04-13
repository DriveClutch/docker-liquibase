#!/bin/bash

set -e 

CLUSTER=$2
SERVICE=$3

echo "SHUTTING DOWN $SERVICE IN $CLUSTER"
/app/ecs-set-desired -cluster $CLUSTER -service $SERVICE -desired 0