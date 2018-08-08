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

echo "<<<DEBUG>>>"
ls -laR /home/ec2-user/
#cat  /home/ec2-user/.ssh/id_rsa

mkdir -p /home/ec2-user/.ssh
echo "${private_key_64}" | base64 -i --decode | zcat > /home/ec2-user/.ssh/id_rsa

#github finger print
echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCP\
y6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81\
eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUU\
mpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWl\
g7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> /home/ec2-user/.ssh/known_hosts

chmod 600 /home/ec2-user/.ssh/id_rsa
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

#clone st setup from git hub
sudo -u ec2-user git clone git@github.com:stSoftwareAU /home/ec2-user/aws-initialise-image
#sudo -u ec2-user /home/ec2-user/aws-initialise-image/autodeploy $1
