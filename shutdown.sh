#!/bin/bash

set -e 

PROFILE=$1
CLUSTER=$2
SERVICE=$3

/app/ecs-set-desired -profile $PROFILE -cluster $CLUSTER -service $SERVICE -desired 0