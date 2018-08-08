# aws-initialise-image
Public bootstrap script for AWS images. 

## Generate and Store a New SSH Key Pair 
1. To generate a ssh private key use ssh-keygen in the command line and follow the prompts, be sure **not** to set a passphrase for the new key. For more information refer to [this useful GitHub article](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/).

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```
2. Once you have a private ssh key we need to compress it so that it will fit into the secret manager's not so generous character cap and encode it in base 64 to ensure integrity of the key's formatting ect. 

```bash
gzip -fc id_rsa | base64 -w 0 > id_rsa_gz_b64.txt
```
3. Now we need to store the key in the aws secrets manager service! Log into aws with an account that has permission to create new secrets, the relevant IAM policy is **SecretsManagerReadWrite**. Click Services>Secrets Manager>Store a new secret. You will be given a couple of options for what kind of secret to store, click 'other type of secrets'. There will be two text boxes to fill on this page: the left one is the name used to refer to the secret value within the secret, use private_key, paste the ssh private key into the right box. 

4. Click next and enter a name and description for the secret. Click next to review what you've done, scroll down and click store secret. Done! 

## Code Function and Documentation
This code retrieves a ssh private key from the aws secrets manager service. The private key is used to ssh into the stsoftware private repository to download and install company code. 

```bash
secret_JS=$(aws secretsmanager get-secret-value --secret-id github --region ap-southeast-2)
```
Secrets manager stores secrets in pairs as "\<name\>" : "\<secret-value\>" in JSON format, the following command retrieves the secret value named "private_key" from the secret.

```bash
key_pairs_JS=$(jq -r '.SecretString' <<< "${secret_JS}")
private_key_64=$(jq -r '.private_key' <<< "${key_pairs_JS}")
```

The private key is compressed and encoded in base 64 so it must be decoded and then decompressed **in that order**. 

```bash
echo "${private_key_64}" | base64 -i --decode | zcat > /home/ec2-user/.ssh/id_rsa
```
