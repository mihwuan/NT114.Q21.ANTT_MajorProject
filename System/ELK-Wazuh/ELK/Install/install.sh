#!/bin/bash

# Cài đặt các gói cần thiết 
sudo apt-get install -y apt-transport-https curl wget gnupg lsb-release software-properties-common unzip 
# Cài đặt Java (OpenJDK 17) 
sudo apt-get install -y openjdk-17-jdk 
java -version 
# Đặt JAVA_HOME 
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' | sudo tee -a /etc/environment 
source /etc/environment

# Cai dat gioi han he thong
sudo tee -a /etc/security/limits.conf << 'EOF'
elasticsearch soft nofile 65536
elasticsearch hard nofile 65536
logstash soft nofile 65536
logstash hard nofile 65536
EOF
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Thêm Elastic GPG key 
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch |  sudo gpg --dearmor -o /usr/share/keyrings/elastic-keyring.gpg 
# Thêm repository 
echo 'deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main' | sudo tee /etc/apt/sources.list.d/elastic-8.x.list 
sudo apt-get update 
# Cài đặt Elasticsearch
sudo apt-get install -y elasticsearch
# Cài đặt Kibana
sudo apt-get install -y kibana 
# Cài đặt Logstash
sudo apt-get install -y logstash

# Cài plugins
sudo /usr/share/logstash/bin/logstash-plugin install logstash-input-opensearch
sudo /usr/share/logstash/bin/logstash-plugin install logstash-output-elasticsearch


