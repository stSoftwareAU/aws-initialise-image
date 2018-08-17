#!/bin/bash
set -e

#format and mount encrypted drive
mv /home/ec2-user /root/
mkfs -t ext4 /dev/xvdb
mount /dev/xvdb /home
mv /root/ec2-user /home/

#update and install necessary packages
yum -y install jq git

curl -O https://bootstrap.pypa.io/get-pip.py
python get-pip.py --user
export PATH=~/.local/bin:$PATH
pip install awscli --upgrade --user

rm -f get-pip.py

#get secrets from secrets manager
secret_JS=$(aws secretsmanager get-secret-value --secret-id "${1}-boot_secrets" --region ap-southeast-2)
key_pairs_JS=$(jq -r '.SecretString' <<< "${secret_JS}")

#make and configure aws_cli config and credentials files
mkdir -p /home/ec2-user/.aws

echo "[default]
output = json
region = ap-southeast-2" > /home/ec2-user/.aws/config

aws_access_key_id=$(jq -r '.aws_access_key_id' <<< "${key_pairs_JS}")
aws_secret_access_key=$(jq -r '.aws_secret_access_key' <<< "${key_pairs_JS}")

echo "[default]
aws_access_key_id = ${aws_access_key_id}
aws_secret_access_key = ${aws_secret_access_key}" > /home/ec2-user/.aws/credentials

chmod 700 /home/ec2-user/.aws
chmod 600 /home/ec2-user/.aws/*
chown -R ec2-user:ec2-user /home/ec2-user/.aws

#add github private ssh key and fingerprint
mkdir -p /home/ec2-user/.ssh

private_key_64=$(jq -r '.github_private_key' <<< "${key_pairs_JS}")
echo "${private_key_64}" | base64 -i --decode | zcat > /home/ec2-user/.ssh/id_rsa

chmod 600 /home/ec2-user/.ssh/id_rsa
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Don't do this yet (doesn't seem to work)
#jq -r '.github_fingerprint' <<< "${key_pairs_JS}" >> /home/ec2-user/.ssh/known_hosts
set +e
sudo -u ec2-user ssh -o StrictHostKeyChecking=no -T git@github.com
set -e 

#clone st setup from git hub
sudo -u ec2-user git clone git@github.com:stSoftwareAU/st-setup.git /home/ec2-user/st-setup
sudo -u ec2-user /home/ec2-user/st-setup/auto-deploy.sh $1 UAT
