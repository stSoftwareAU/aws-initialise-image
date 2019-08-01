#!/bin/bash
set -e

#format and mount encrypted drive
mv /home/ec2-user /root/
mkfs -t ext4 /dev/sdb
mount /dev/sdb /home
mv /root/ec2-user /home/

uuid=`file -Ls /dev/sdb | sed -n "s/^.*\(UUID=\S*\).*$/\1/p"`
echo "${uuid}     /home   ext4    defaults,nofail        0       2" >> /etc/fstab

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
private_key_64=$(jq -r '.github_private_key' <<< "${key_pairs_JS}")
echo "${private_key_64}" | base64 -i --decode | zcat > /home/ec2-user/.ssh/id_rsa

echo "
github.com,192.30.255.113,192.30.255.112 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+P\
XYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4E\
VVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0e\
OzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
" >> /home/ec2-user/.ssh/known_hosts

chmod 600 /home/ec2-user/.ssh/*
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

AREA=${2:-"UAT"}
REPO="st-setup"
if [ "${AREA}" != "UAT" ]; then
    REPO="${AREA}-setup"
fi

#clone st setup from git hub
sudo -u ec2-user git clone git@github.com:stSoftwareAU/${REPO}.git /home/ec2-user/st-setup

#make root launch script
cat > /root/launch.sh << EOF
#!/bin/bash
set -e

counter=0
while [ ! -f "/home/ec2-user/st-setup/launch.sh" ]
do
  counter=$(( $counter + 1))
  if [ $counter -gt 20 ]; then
    echo "can't find /home/ec2-user/st-setup/launch.sh"
    /sbin/shutdown -h now
  fi
  echo "file does not exist, wait 1 sec"
  sleep 1
done

if ! sudo -u ec2-user /home/ec2-user/st-setup/launch.sh "\$@"; then 
    >&2 echo "could not launch \$@"
    /sbin/shutdown -h now
fi
EOF

chmod 700 /root/launch.sh

#create image
sudo -u ec2-user /home/ec2-user/st-setup/auto-deploy.sh $1 ${AREA}
