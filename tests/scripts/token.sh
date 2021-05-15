#!/usr/bin/env sh
export IAM_CLIENT_ID=test-idp
export IAM_CLIENT_SECRET=942bd24a-915e-4e44-bc16-c577495c0692
export IAM_USER_NAME=mostrandommofo
export IAM_USER_PASSWORD=Inkpen12!
export IAM_REALM_NAME=test-idp
export IAM_URL=http://localhost:8098

RESPONSE=`curl -s \
   -u ${IAM_CLIENT_ID}:${IAM_CLIENT_SECRET} \
   -d username=${IAM_USER_NAME} \
   -d password=${IAM_USER_PASSWORD} \
   -d grant_type=password \
   -d scope=offline_access \
   ${IAM_URL}/auth/realms/${IAM_REALM_NAME}/protocol/openid-connect/token`;

echo -e "access token:";
echo ${RESPONSE} | jq -j -r .access_token;
echo -e "\n\nrefresh token:";
echo ${RESPONSE} | jq -j -r .refresh_token;
echo -e ""
