#!/bin/bash
set -e

#format and mount encrypted drive
mv /home/ec2-user /root/
mkfs -t ext4 /dev/xvdb
mount /dev/xvdb /home
mv /root/ec2-user /home/

#update and install necessary packages
yum -y update
yum -y install jq git

curl -O https://bootstrap.pypa.io/get-pip.py
python get-pip.py --user
export PATH=~/.local/bin:$PATH
pip install awscli --upgrade --user

rm -f get-pip.py

#get the private key from secrets manager
secret_JS=$(aws secretsmanager get-secret-value --secret-id github --region ap-southeast-2)
key_pairs_JS=$(jq -r '.SecretString' <<< "${secret_JS}")
private_key_64=$(jq -r '.private_key' <<< "${key_pairs_JS}")

mkdir -p /home/ec2-user/.ssh
echo "${private_key_64}" | base64 -i --decode | zcat > /home/ec2-user/.ssh/id_rsa

#add github finger print
jq -r '.fingerprint' <<< "${key_pairs_JS}" >> /home/ec2-user/.ssh/known_hosts

chmod 600 /home/ec2-user/.ssh/id_rsa
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

#clone st setup from git hub
sudo -u ec2-user git clone git@github.com:stSoftwareAU/st-setup.git /home/ec2-user/st-setup
sudo -u ec2-user /home/ec2-user/st-setup/auto-deploy.sh $1 UAT
