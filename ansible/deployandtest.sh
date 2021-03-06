#!/bin/bash -e
#
# ./deployandtest.sh [aws|aws-single-node|gcp|metal|openstack|shakenfist]
#
#
# Note: Tests can be skipped by setting $SKIP_SF_TESTS
#

#### Required settings
TERRAFORM_VARS=""
ANSIBLE_VARS=""
VERBOSE="-v"

#### AWS
if [ "$CLOUD" == "aws" ] || [ "$CLOUD" == "aws-single-node" ]
then
  if [ -z "$AWS_REGION" ]
  then
    echo ===== Must specify AWS region in \$AWS_REGION
    exit 1
  fi
  VARIABLES="$VARIABLES region=$AWS_REGION"

  if [ -z "$AWS_AVAILABILITY_ZONE" ]
  then
    echo ===== Must specify AWS availability zone in \$AWS_AVAILABILITY_ZONE
    exit 1
  fi
  VARIABLES="$VARIABLES availability_zone=$AWS_REGION"

  if [ -z "$AWS_VPC_ID" ]
  then
    echo ===== Must specify AWS VPC ID in \$AWS_VPC_ID
    exit 1
  fi
  VARIABLES="$VARIABLES vpc_id=$AWS_VPC_ID"

  if [ -z "$AWS_SSH_KEY_NAME" ]
  then
    echo ===== Must specify AWS Instance SSH key name in \$AWS_SSH_KEY_NAME
    exit 1
  fi
  VARIABLES="$VARIABLES ssh_key_name=$AWS_SSH_KEY_NAME"
fi

#### Google Cloud
if [ "$CLOUD" == "gcp" ]
then
  if [ -z "$GCP_PROJECT" ]
  then
    echo ===== Must specify GCP project in \$GCP_PROJECT
    exit 1
  fi
  VARIABLES="$VARIABLES project=$GCP_PROJECT"
fi

#### Openstack
if [ "$CLOUD" == "openstack" ]
then
  if [ -z "$OS_SSH_KEY_NAME" ]
  then
    echo ===== Must specify Openstack SSH key name in \$OS_SSH_KEY_NAME
    exit 1
  fi
  VARIABLES="$VARIABLES ssh_key_name=$OS_SSH_KEY_NAME"

  if [ -z "$OS_FLAVOR_NAME" ]
  then
    echo ===== Must specify Openstack instance flavor name in \$OS_FLAVOR_NAME
    exit 1
  fi
  VARIABLES="$VARIABLES os_flavor=$OS_FLAVOR_NAME"

  if [ -z "$OS_EXTERNAL_NET_NAME" ]
  then
    echo ===== Must specify Openstack External network name in \$OS_EXTERNAL_NET_NAME
    exit 1
  fi
  VARIABLES="$VARIABLES os_external_net_name=$OS_EXTERNAL_NET_NAME"
fi

#### Metal
if [ "$CLOUD" == "metal" ]
then
  if [ -z "$METAL_IP_SF1" ]
  then
    echo ===== Must specify the Node 1 machine IP in \$METAL_IP_SF1
    exit 1
  fi
  VARIABLES="$VARIABLES metal_ip_sf1=$METAL_IP_SF1"

  if [ -z "$METAL_IP_SF2" ]
  then
    echo ===== Must specify the Node 2 machine IP in \$METAL_IP_SF2
    exit 1
  fi
  VARIABLES="$VARIABLES metal_ip_sf2=$METAL_IP_SF2"

  if [ -z "$METAL_IP_SF3" ]
  then
    echo ===== Must specify the Node 3 machine IP in \$METAL_IP_SF3
    exit 1
  fi
  VARIABLES="$VARIABLES metal_ip_sf3=$METAL_IP_SF3"
fi

#### Shakenfist
if [ "$CLOUD" == "shakenfist" ]
then
  if [ -z "$SHAKENFIST_KEY" ]
  then
    echo ===== Must specify the Shaken Fist system key to use in \$SHAKENFIST_KEY
    exit 1
  fi
  VARIABLES="$VARIABLES system_key=$SHAKENFIST_KEY"

  if [ -z "$SHAKENFIST_SSH_KEY" ]
  then
    echo ===== Must specify a SSH public key\'s text in \$SHAKENFIST_SSH_KEY
  fi
  TERRAFORM_VARS="$TERRAFORM_VARS -var=ssh_key=\"$SHAKENFIST_SSH_KEY\""
  ANSIBLE_VARS="$ANSIBLE_VARS ssh_key=\"$SHAKENFIST_SSH_KEY\""
fi

#### Check that a valid cloud was specified
if [ -z "$VARIABLES" ]
then
{
  echo ====
  echo ==== CLOUD should be specified: aws, aws-single-node, gcp, metal, openstack, shakenfist
  echo ==== eg.  ./deployandtest/sh gcp
  echo ====
  echo ==== Continuing, because you might know what you are doing...
  echo
} 2> /dev/null
fi

#### Configure system/admin key from Vault key path or specified password
if [ -n "$VAULT_SYSTEM_KEY_PATH" ]
then
  if [ -n "$ADMIN_PASSWORD" ]
  then
    echo ===== Specify either ADMIN_PASSWORD or VAULT_SYSTEM_KEY_PATH \(not both\)
    exit 1
  fi

  ANSIBLE_VARS="$ANSIBLE_VARS vault_system_key_path=$VAULT_SYSTEM_KEY_PATH"
fi

set -x

#### Release selection, git or a version from pypi
if [ -z "$RELEASE" ]
then
  # This is the latest version from pypi
  RELEASE=`curl -s https://pypi.org/simple/shakenfist/ | grep whl | sed -e 's/.*shakenfist-//' -e 's/-py3.*//' | tail -1`
fi

cwd=`pwd`
if [ `echo $RELEASE | cut -f 1 -d ":"` == "git" ]
then
  for repo in shakenfist client-python ansible-modules
  do
    if [ ! -e ../gitrepos/$repo ]
    then
      git clone https://github.com/shakenfist/$repo ../gitrepos/$repo
    else
      
      cd ../gitrepos/$repo
      git fetch
    fi
    cd $cwd
  done

  branch=`echo $RELEASE | cut -f 2 -d ":"`

  cd ../gitrepos/shakenfist
  if [ `git branch | grep -c $branch` -lt 1 ]
  then
    echo "===== Requested branch ($branch) does not exist for shakenfist/shakenfist"
    exit 1
  fi
  git checkout $branch
  cd $cwd
  
  for repo in client-python ansible-modules
  do
    cd ../gitrepos/$repo
    if [ `git branch | grep -c $branch` -gt 1 ]
    then
      git checkout $branch
    fi
    cd $cwd
  done

  RELEASE="git"
else
  # NOTE(mikal): this is a hack until we use ansible galaxy for these modules
  for repo in ansible-modules
  do
    if [ ! -e ../gitrepos/$repo ]
    then
      git clone https://github.com/shakenfist/$repo ../gitrepos/$repo
    else
      cd ../gitrepos/$repo
      git fetch
    fi
    cd $cwd
    cd ../gitrepos/$repo
    if [ `git branch | grep -c $branch` -gt 1 ]
    then
      git checkout $branch
    fi
    cd $cwd
  done
fi
VARIABLES="$VARIABLES release=$RELEASE"

#### Mode selection, deploy or hotfix at this time
if [ -z "$MODE" ]
then
  MODE="deploy"
fi

#### Default settings
BOOTDELAY="${BOOTDELAY:-2}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Ukoh5vie}"
FLOATING_IP_BLOCK="${FLOATING_IP_BLOCK:-10.10.0.0/24}"
UNIQIFIER="${UNIQIFIER:-$USER"-"`date "+%y%m%d"`"-"`pwgen --no-capitalize -n1`"-"}"
KSM_ENABLED="${KSM_ENABLED:-1}"

# Setup variables for consumption by ansible and terraform
cwd=`pwd`
TERRAFORM_VARS="$TERRAFORM_VARS -var=uniqifier=$UNIQIFIER"

ANSIBLE_VARS="$ANSIBLE_VARS cloud=$CLOUD"
ANSIBLE_VARS="$ANSIBLE_VARS bootdelay=$BOOTDELAY"
ANSIBLE_VARS="$ANSIBLE_VARS ansible_root=$cwd"
ANSIBLE_VARS="$ANSIBLE_VARS uniqifier=$UNIQIFIER"
ANSIBLE_VARS="$ANSIBLE_VARS admin_password=$ADMIN_PASSWORD"
ANSIBLE_VARS="$ANSIBLE_VARS floating_network_ipblock=$FLOATING_IP_BLOCK"
ANSIBLE_VARS="$ANSIBLE_VARS mode=$MODE"
ANSIBLE_VARS="$ANSIBLE_VARS ksm_enabled=$KSM_ENABLED"

echo "VARIABLES: $VARIABLES"

for var in $VARIABLES
do
  TERRAFORM_VARS="$TERRAFORM_VARS -var=$var"
  ANSIBLE_VARS="$ANSIBLE_VARS $var"
done

ansible-playbook $VERBOSE -i hosts --extra-vars "$ANSIBLE_VARS" deploy.yml $@

if [ -e terraform/$CLOUD/local.yml ]
then
  ansible-playbook $VERBOSE -i hosts --extra-vars "$ANSIBLE_VARS" terraform/$CLOUD/local.yml $@
fi

# Old fashioned ansible CI
if [ "%$SKIP_SF_TESTS%" == "%%" ]
then
  ansible-playbook $VERBOSE -i hosts --extra-vars "$ANSIBLE_VARS" ../ansible-ci/pretest.yml $@
  for playbook in `ls ../ansible-ci/tests/test_*.yml | grep -v test_final.yml | shuf`
  do
    ansible-playbook $VERBOSE -i hosts --extra-vars "$ANSIBLE_VARS" $playbook $@
  done

  ansible-playbook $VERBOSE -i hosts --extra-vars "$ANSIBLE_VARS" ../ansible-ci/tests/test_final.yml $@

  # New fangled python CI
  ansible-playbook $VERBOSE -i hosts --extra-vars "$ANSIBLE_VARS" test.yml $@
fi
