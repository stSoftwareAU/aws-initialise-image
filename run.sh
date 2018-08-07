set -e
#update and install
sudo yum -y update
sudo yum -y install jq
curl -O https://bootstrap.pypa.io/get-pip.py
python get-pip.py --user
export PATH=~/.local/bin:$PATH
pip install awscli --upgrade --user
#get private key from aws secrets manager
secret_JS=$(aws secretsmanager get-secret-value --secret-id angus-ssh-key --region ap-southeast-2)
key_pairs_JS=$( iq -r '.SecretString' <<< "${secret_JS}")
private_key_64=$(jq -r '.private_key' <<< "${key_pairs_JS}")
echo "${private_key_64}" | base64 -i --decode | zcat > .ssh/id_rsa
chmod 600 .ssh/id_rsa
#clone st setup from git hub
git clone git@github.com:stSoftwareAU/st-setup.git
#st-setup/autodeploy $1
