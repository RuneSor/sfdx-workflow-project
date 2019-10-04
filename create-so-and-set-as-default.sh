#!/bin/sh
# Rune Sorensen - rune.sorensen@fluidogroup.com

start=$(date +%s)

DURATION=30

if [ "$#" -eq 1 ]; then
  DURATION=$1
fi
# ..uncomment below lines and fill inn needed  env.var values for use locally
# export SF_CONSUMER_KEY={insert connectedApp consumer key}
# export SF_USERNAME=user.name@example.com
# export SF_HUBORG_ALIAS=hubOrgAlias
# export SF_SO_ALIAS=scratchOrg-$start

# uncomment and update if you need to decrypt the server.key.enc file
# export DECRYPTION_KEY={key here}
# export DECRYPTION_IV={iv here}
# openssl enc -nosalt -aes-256-cbc -d -in assets/server.key.enc -out assets/server.key -base64 -K $DECRYPTION_KEY -iv $DECRYPTION_IV

sfdx force:auth:jwt:grant -i $SF_CONSUMER_KEY -f assets/server.key -u $SF_USERNAME -d -a $SF_HUBORG_ALIAS
sfdx force:org:create -v $SF_HUBORG_ALIAS -s -f config/project-scratch-def.json -a $SF_SO_ALIAS -d $DURATION
sfdx force:user:password:generate -u $SF_SO_ALIAS --json

# store creds in assets/scratchOrgs
sfdx force:org:display --verbose --json > assets/scratchOrgs/$SF_SO_ALIAS.json
sfdx force:org:open -r -u $SF_SO_ALIAS --json > assets/scratchOrgs/$SF_SO_ALIAS-easyLogin.json


# sfdx force:user:permset:assign -n PermsetName

sfdx force:org:open -u $SF_SO_ALIAS

echo 
end=$(date +%s)
seconds=$(echo "$end - $start" | bc)
echo 
echo 
awk -v t=$SECONDS 'BEGIN{t=int(t*1000); printf "Total ScratchOrg creation time: %d:%02d:%02d\n", t/3600000, t/60000%60, t/1000%60}'
echo 
