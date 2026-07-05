# Install 
sudo bash ELK_Node/Install/install.sh

# Tạo chứng chỉ SSL cho Elasticsearch: 

    # Tạo CA certificate 
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil ca --out /etc/elasticsearch/certs/elastic-stack-ca.p12 --pass ''
    # Tạo certificate cho Elasticsearch
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert --ca /etc/elasticsearch/certs/elastic-stack-ca.p12 --ca-pass '' --out /etc/elasticsearch/certs/elastic-certificates.p12 --pass ''
    # Tạo PEM certificates (cho Kibana & Logstash) 
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert --ca /etc/elasticsearch/certs/elastic-stack-ca.p12 --ca-pass '' --pem --out /etc/elasticsearch/certs/elastic-certs.zip 
    # Giải nén PEM certificates
sudo unzip /etc/elasticsearch/certs/elastic-certs.zip -d /etc/elasticsearch/certs/
    # Phân quyền cho các file chứng chỉ
sudo chown -R elasticsearch:elasticsearch /etc/elasticsearch/certs/
sudo bash -c "chmod 640 /etc/elasticsearch/certs/*.p12"
sudo bash -c "chmod 640 /etc/elasticsearch/certs/instance/*.crt"

# Cấu hình Elasticsearch 
sudo nano /etc/elasticsearch/elasticsearch.yml

# Xóa mật khẩu cấu hình SSL trong Keystore
# (Nếu lệnh báo Setting [...] does not exist, cứ kệ nó và chạy tiếp lệnh, vì đang rà soát để xóa sạch mật khẩu sai).
sudo /usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.http.ssl.keystore.secure_password
sudo /usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.http.ssl.truststore.secure_password
sudo /usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.transport.ssl.keystore.secure_password
sudo /usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.transport.ssl.truststore.secure_password

# Khởi động và đặt mật khẩu: 
sudo systemctl daemon-reload 
sudo systemctl enable elasticsearch 
sudo systemctl start elasticsearch 
 
    # Kiểm tra trạng thái 
sudo systemctl status elasticsearch 

    # Đặt mật khẩu cho built-in users (lưu lại output!) 
sudo /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto 
    # Hoặc đặt thủ công: 
sudo /usr/share/elasticsearch/bin/elasticsearch-setup-passwords interactive 
    # Nếu muốn reset lại mật khẩu của từng user, có thể dùng lệnh sau:
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u kibana_system
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u logstash_system

# Test kết nối SSL 
curl --cacert /etc/elasticsearch/certs/instance/instance.crt -u elastic:NnRH6hu*6CL=mjUvTmZr https://localhost:9200
    # Hoặc nếu đã cài đặt CA certificate vào hệ thống, có thể dùng lệnh sau:
curl -k -u 'elastic:NnRH6hu*6CL=mjUvTmZr' https://localhost:9200

# Tạo Kibana encryption keys (tự động) 
sudo /usr/share/kibana/bin/kibana-encryption-keys generate 
    # Sau khi chạy lệnh này, lưu lại kết quả output, vì nó sẽ hiển thị encryption key, cần copy key này vào kibana.yml.
    # Hoặc tạo thủ công:
sudo /usr/share/kibana/bin/kibana-encryption-keys generate --count 1 --out /etc/kibana/kibana_encryption_key.txt
    # Lưu ý: Nếu đã tạo thủ công, cần copy nội dung của file kibana_encryption_key.txt vào kibana.yml nhé.

# Cấu hình Kibana
sudo nano /etc/kibana/kibana.yml

# Tạo certificates cho Logstash Beats input (TLS) 
sudo mkdir -p /etc/logstash/certs 
 
# Tạo self-signed cert cho Logstash (nhận kết nối từ Filebeat) 
sudo openssl req -x509 -newkey rsa:4096 -keyout /etc/logstash/certs/logstash.key -out /etc/logstash/certs/logstash.crt -days 3650 -nodes -subj '/CN=elk-node/O=SIEM/C=VN' -addext 'subjectAltName=IP:10.0.0.4' 
    # Phân quyền cho Logstash user có thể đọc được các file chứng chỉ này
sudo chown -R logstash:logstash /etc/logstash/certs/ 
sudo bash -c "chmod 640 /etc/logstash/certs/logstash.key"
sudo bash -c "chmod 640 /etc/logstash/certs/logstash.crt"

# Create a /etc/logstash/templates/ directory and download the template as wazuh.json using the following commands:
sudo mkdir /etc/logstash/templates
sudo curl -o /etc/logstash/templates/wazuh.json https://packages.wazuh.com/integrations/elastic/4.x-8.x/dashboards/wz-es-4.x-8.x-template.json

#Tạo pipeline Logstash: 
sudo nano /etc/logstash/conf.d/wazuh.conf 

# Cấu hình logstash.yml 
sudo nano /etc/logstash/logstash.yml

# Copy CA certificate từ Elasticsearch sang Logstash để Logstash có thể trust được Elasticsearch khi gửi dữ liệu đi:
sudo cp /etc/elasticsearch/certs/instance/instance.crt /etc/logstash/certs/
sudo chown logstash:logstash /etc/logstash/certs/instance.crt
sudo bash -c "chmod 640 /etc/logstash/certs/instance.crt"

# Copy CA certificate từ Elasticsearch sang Kibana để Kibana có thể trust được:
sudo mkdir -p /etc/kibana/certs 
sudo cp /etc/elasticsearch/certs/instance/instance.crt /etc/kibana/certs/ 
sudo chown -R kibana:kibana /etc/kibana/certs 
sudo bash -c "chmod 640 /etc/kibana/certs/instance.crt"

# Configuring the Wazuh alerts index pattern in Elastic
# Verifying the integration
# Elastic dashboards
wget https://packages.wazuh.com/integrations/elastic/4.x-8.x/dashboards/wz-es-4.x-8.x-dashboards.ndjson
# Navigate to Management > Stack management in Kibana.
# Click on Saved Objects and click Import.
# Click on the Import icon, browse your files, and select the dashboard file.
# Click the Import button to start importing.