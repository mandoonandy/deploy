#!/bin/bash -ex
#
# ./deployandtest.sh [aws|gcp|metal|openstack]
#
#
# Note: Tests can skipped by setting $SKIP_SF_TESTS
#

#### Required settings
CLOUD=${1:-$CLOUD}
if [ -z "$CLOUD" ]
then
  echo ==== CLOUD must be specified: aws, aws-single-node, gcp, metal, openstack
  echo ==== eg.  ./deployandtest/sh gcp
  exit 1
fi

if [ "$CLOUD" == "gcp" ] && [ -z "$GCP_PROJECT" ]
then
  echo ===== Must specify GCP project in \$GCP_PROJECT
  exit 1
  VARIABLES="$VARIABLES project=$GCP_PROJECT"
fi

if [ "$CLOUD" == "aws" ] || [ "$CLOUD" == "aws-single-node" ]
then
  if [ -z "$AWS_REGION" ]
  then
    echo ===== Must specify AWS region project in \$GCP_REGION
    exit 1
  fi
  VARIABLES="$VARIABLES aws_region=$AWS_REGION"

  if [ -z "$AWS_SSH_KEY_NAME" ]
  then
    echo ===== Must specify AWS Instance SSH key name in \$AWS_SSH_KEY_NAME
    exit 1
  fi
  VARIABLES="$VARIABLES aws_ssh_key_name=$AWS_SSH_KEY_NAME"

  if [ -z "$AWS_VPC_SECURITY_GROUP_ID" ]
  then
    echo ===== Must specify AWS VPC Security Group ID in \$AWS_VPC_SECURITY_GROUP_ID
    exit 1
  fi
  VARIABLES="$VARIABLES aws_vpc_security_group_id=$AWS_VPC_SECURITY_GROUP_ID"
fi


#### Default settings
BOOTDELAY="${BOOTDELAY:-2}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Ukoh5vie}"
FLOATING_IP_BLOCK="${FLOATING_IP_BLOCK:-10.10.0.0/24}"
UNIQIFIER="${UNIQIFIER:-$USER"-"`date "+%y%m%d"`"-"`pwgen --no-capitalize -n1`"-"}"


# Setup variables for consumption by ansible and terraform
cwd=`pwd`
TERRAFORM_VARS="-var=uniqifier=$UNIQIFIER"

ANSIBLE_VARS="$ANSIBLE_VARS cloud=$CLOUD"
ANSIBLE_VARS="$ANSIBLE_VARS bootdelay=$BOOTDELAY"
ANSIBLE_VARS="$ANSIBLE_VARS ansible_root=$cwd"
ANSIBLE_VARS="$ANSIBLE_VARS uniqifier=$UNIQIFIER"
ANSIBLE_VARS="$ANSIBLE_VARS ADMIN_PASSWORD=$ADMIN_PASSWORD"
ANSIBLE_VARS="$ANSIBLE_VARS floating_network_ipblock=$FLOATING_IP_BLOCK"

for var in $VARIABLES
do
  TERRAFORM_VARS="$TERRAFORM_VARS -var=$var"
  ANSIBLE_VARS="$ANSIBLE_VARS $var"
done

ansible-playbook -i hosts --extra-vars "$ANSIBLE_VARS" deploy.yml

if [ -e terraform/$CLOUD/local.yml ]
then
  ansible-playbook -i hosts --extra-vars "$ANSIBLE_VARS" terraform/$CLOUD/local.yml
fi

# Old fashioned ansible CI
if [ "%$SKIP_SF_TESTS%" == "%%" ]
then
  ansible-playbook -i hosts --extra-vars "$ANSIBLE_VARS" ../ansible-ci/pretest.yml
  for playbook in `ls ../ansible-ci/tests/test_*.yml | grep -v test_final.yml | shuf`
  do
    ansible-playbook -i hosts --extra-vars "$ANSIBLE_VARS" $playbook
  done

  ansible-playbook -i hosts --extra-vars "$ANSIBLE_VARS" ../ansible-ci/tests/test_final.yml

  # New fangled python CI
  ansible-playbook -i hosts --extra-vars "$ANSIBLE_VARS" test.yml
fi
