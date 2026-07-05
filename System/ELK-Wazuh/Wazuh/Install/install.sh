#!/bin/bash

# Cài đặt các gói cần thiết 
# sudo apt-get update && sudo apt-get upgrade -y 
# sudo apt-get install -y apt-transport-https curl wget gnupg lsb-release software-properties-common unzip 

# Cài đặt Wazuh Manager 
# Thêm Wazuh GPG key và repository 
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --dearmor -o /usr/share/keyrings/wazuh.gpg 
echo 'deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main' | sudo tee /etc/apt/sources.list.d/wazuh.list 
sudo apt-get update 
sudo apt-get install -y wazuh-manager 

# Xác nhận version
sudo /var/ossec/bin/wazuh-control info

# Cài đặt Filebeat: 
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic-keyring.gpg 
echo 'deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main' | sudo tee /etc/apt/sources.list.d/elastic-8.x.list 
sudo apt-get update 
sudo apt-get install -y filebeat 

# Cài đặt Wazuh module cho Filebeat 
sudo curl -s https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.3.tar.gz | sudo tar -xvz -C /usr/share/filebeat/module 

# Cài đặt NGINX & Certbot 
sudo apt-get install -y nginx certbot python3-certbot-nginx 
 
# Kiểm tra 
sudo nginx -v 
nginx -version 

# Cài WireGuard 
sudo apt-get update 
sudo apt-get install -y wireguard wireguard-tools 
 
# Bật IP forwarding 
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf 
echo 'net.ipv4.conf.all.proxy_arp=1' | sudo tee -a /etc/sysctl.conf 
sudo sysctl -p 




