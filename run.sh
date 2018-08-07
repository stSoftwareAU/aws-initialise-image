set -e
#update and install
yum -y update
yum -y install jq git

curl -O https://bootstrap.pypa.io/get-pip.py
python get-pip.py --user
export PATH=~/.local/bin:$PATH
pip install awscli --upgrade --user

rm get-pip.py

#get private key from aws secrets manager
secret_JS=$(aws secretsmanager get-secret-value --secret-id angus-ssh-key --region ap-southeast-2)
key_pairs_JS=$(jq -r '.SecretString' <<< "${secret_JS}")
private_key_64=$(jq -r '.private_key' <<< "${key_pairs_JS}")

mkdir -p /home/ec2_user/.ssh
echo "${private_key_64}" | base64 -i --decode | zcat > /home/ec2-user/.ssh/id_rsa
chown -R ec2-user:ec2-user /home/ec2_user/.ssh

chmod 600 /home/ec2-user/.ssh/id_rsa
#clone st setup from git hub
sudo -u ec2-user git clone git@github.com:stSoftwareAU/st-setup.git
#sudo -u ec2-user st-setup/autodeploy $1
