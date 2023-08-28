#!/bin/bash

VAR_FILE=.vars

firewall-cmd --add-port=8080-8083/tcp --permanent
firewall-cmd --reload



# This crazy stuff is because it didn't work with just removing the file and restarting the service...
systemctl stop fdo-aio
sleep 1
rm -rf /etc/fdo/aio/*
dnf install -y fdo-admin-cli fdo-manufacturing-server
# touch /usr/libexec/fdo/fdo-manufacturing-client && chmod 755 /usr/libexec/fdo/fdo-manufacturing-client
systemctl enable --now fdo-aio
rm -rf /etc/fdo/aio/*
sleep 1
systemctl restart fdo-aio


#mkdir /root/fdo-keys
#fdo-admin-tool generate-key-and-cert diun --destination-dir fdo-keys
#fdo-admin-tool generate-key-and-cert manufacturer --destination-dir fdo-keys
#fdo-admin-tool generate-key-and-cert device-ca --destination-dir fdo-keys
#fdo-admin-tool generate-key-and-cert owner --destination-dir fdo-keys





sleep 5

yes | cp -f serviceinfo_api_server.yml.example serviceinfo_api_server.yml
if [ -f /etc/fdo/aio/configs/serviceinfo_api_server.yml ]
then
    service_info_auth_token=$(grep service_info_auth_token /etc/fdo/aio/configs/serviceinfo_api_server.yml | awk '{print $2}')
    admin_auth_token=$(grep admin_auth_token /etc/fdo/aio/configs/serviceinfo_api_server.yml | awk '{print $2}')
    sed -i "s|service_info_auth_token:*.*|service_info_auth_token: ${service_info_auth_token}|g" serviceinfo_api_server.yml
    sed -i "s|admin_auth_token:*.*|admin_auth_token: ${admin_auth_token}|g" serviceinfo_api_server.yml
fi

sed -i "s|ssh-rsa AAAA|${SSHKEY}|g" serviceinfo_api_server.yml 
sed -i "s|<ACM_REGISTRATION_TOKEN>|${ACM_REGISTRATION_TOKEN}|g" serviceinfo_api_server.yml 
sed -i "s|<ACM_REGISTRATION_HOST>|${ACM_REGISTRATION_HOST}|g" serviceinfo_api_server.yml 

rm -rf  /etc/fdo/aio/configs/serviceinfo_api_server.yml
mkdir -p /etc/fdo/aio/configs
cp -f serviceinfo_api_server.yml  /etc/fdo/aio/configs/serviceinfo_api_server.yml

rm -rf /etc/fdo-configs
cp -r fdo-configs /etc/

sleep 1 

systemctl restart fdo-aio
