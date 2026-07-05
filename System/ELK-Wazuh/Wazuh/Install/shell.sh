# Install 
sudo bash Wazuh_Node/Install/install.sh


# Cấu hình Wazuh Manager SSL (ossec.conf) 
sudo nano /var/ossec/etc/ossec.conf 

# Tạo SSL certificates cho Wazuh authd 
    # Tạo CA key & cert 
sudo openssl genrsa -out /var/ossec/etc/sslmanager.key 4096 
sudo openssl req -x509 -new -nodes -key /var/ossec/etc/sslmanager.key -sha256 -days 3650 -subj '/CN=wazuh-manager/O=SIEM/C=VN' -out /var/ossec/etc/sslmanager.cert 
    # Phân quyền cho các file SSL
sudo bash -c "chown wazuh:wazuh /var/ossec/etc/sslmanager.*"
sudo bash -c " chmod 640 /var/ossec/etc/sslmanager.*"

# Khởi động Wazuh Manager

# Cấu hình /etc/filebeat/filebeat.yml 
sudo nano /etc/filebeat/filebeat.yml

# Copy Logstash certificate từ VM2 sang VM1 
# Chạy trên VM1: 
chmod 600 /tmp/key.pem # Phải có key để copy file qua SCP
sudo mkdir -p /etc/filebeat/certs 
scp azureuser@10.0.0.4:/etc/logstash/certs/logstash.crt /tmp/logstash.crt 
sudo cp /tmp/logstash.crt /etc/filebeat/certs/ 
 
# Khởi động Filebeat 

# Cấu hình NGINX reverse proxy cho Kibana
sudo nano /etc/nginx/sites-available/kibana  

# Enable site 
sudo ln -s /etc/nginx/sites-available/kibana /etc/nginx/sites-enabled/ 
sudo rm -f /etc/nginx/sites-enabled/default 

# Self-signed certificate (dùng IP hoặc nội bộ) 
sudo mkdir -p /etc/nginx/ssl 
 
# Tạo self-signed cert với SAN 
sudo openssl req -x509 -newkey rsa:4096 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -days 3650 -nodes -subj '/CN=10.0.0.5/O=SIEM/C=VN' -addext 'subjectAltName=IP:10.0.0.5,DNS:nginx.org' 
 
sudo bash -c "chmod 600 /etc/nginx/ssl/nginx.key"
sudo bash -c "chmod 644 /etc/nginx/ssl/nginx.crt"

# Test & khởi động NGINX 
sudo nginx -t 
sudo systemctl enable nginx 
sudo systemctl restart nginx 
sudo systemctl status nginx 

# Cấu hình /etc/nginx/nginx.conf tổng quát 
sudo nano /etc/nginx/nginx.conf

# Cấu hình Wazuh API
sudo nano /var/ossec/api/configuration/api.yaml

# Tạo SSL cert cho Wazuh API
sudo mkdir -p /var/ossec/api/configuration/ssl
sudo openssl req -x509 -newkey rsa:4096 -keyout /var/ossec/api/configuration/ssl/server.key -out /var/ossec/api/configuration/ssl/server.crt -days 3650 -nodes -subj '/CN=wazuh-api/O=SIEM/C=VN'
sudo bash -c "chown wazuh:wazuh /var/ossec/api/configuration/ssl/server.*"
sudo systemctl restart wazuh-manager

# Đổi mật khẩu mặc định (mặc định là "wazuh"):
sudo /var/ossec/framework/python/bin/python3 /var/ossec/api/scripts/change_credentials.py -u wazuh -p <NEW_SECURE_PASSWORD>

# Thiết lập WireGuard VPN Peer giữa Wazuh_Node (VM1) và Local Client (Victim) để đảm bảo kết nối an toàn giữa Agent và Manager qua VPN thay vì qua Internet công cộng.
# Tạo key pair cho Wazuh_Node (VM1)
sudo mkdir -p /etc/wireguard 
sudo bash -c "chmod 700 /etc/wireguard" 

cd /etc/wireguard 
wg genkey | sudo tee /etc/wireguard/wazuh_private.key | wg pubkey | sudo tee /etc/wireguard/wazuh_public.key 
sudo bash -c "chmod 600 /etc/wireguard/wazuh_private.key"

# Xem key (cần cho peers) 
sudo cat /etc/wireguard/wazuh_public.key 
sudo cat /etc/wireguard/wazuh_private.key 
# Tạo cấu hình /etc/wireguard/wg0.conf trên Wazuh_Node (VM1)
sudo nano /etc/wireguard/wg0.conf  
sudo bash -c "chmod 600 /etc/wireguard/wg0.conf"
 
# Khởi động WireGuard 
sudo systemctl enable wg-quick@wg0 
sudo systemctl start wg-quick@wg0 

# Kiểm tra interface 
sudo wg show 
ip addr show wg0 

# UFW trên VM1 
sudo ufw allow 51820/udp 
sudo ufw reload 

# Trên máy Local Client (Victim): Cài đặt WireGuard và tạo cặp khóa (key pair):
sudo apt-get install -y wireguard wireguard-tools
sudo mkdir -p /etc/wireguard
wg genkey | sudo tee /etc/wireguard/agent_private.key | wg pubkey | sudo tee /etc/wireguard/agent_public.key
sudo chmod 600 /etc/wireguard/agent_private.key
# Xem public key của Agent để lát nữa khai báo lên Server:
cat /etc/wireguard/agent_public.key

# Thêm Agent vào WireGuard Server (VM1 trên Azure): Trên VM1 (wazuh-node) thêm peer cho Agent vào cấu hình WireGuard:
sudo wg set wg0 peer <AGENT_PUBLIC_KEY> allowed-ips 10.10.0.10/32
sudo wg-quick save wg0

# Cấu hình file wg0.conf trên Local Client: Tạo file cấu hình /etc/wireguard/wg0.conf trên máy Client:
sudo nano /etc/wireguard/wg0.conf

# Nội dung mẫu cho wg0.conf trên Client:
[Interface]
Address = 10.10.0.10/24
PrivateKey = <AGENT_PRIVATE_KEY>

[Peer]
PublicKey = <VM1_PUBLIC_KEY>
Endpoint = <IP_PUBLIC_VM1>:51820
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
Lưu ý: Thay <IP_PUBLIC_VM1> và <VM1_PUBLIC_KEY> bằng thông tin thực tế của máy chủ Wazuh trên Azure.

# Khởi động kết nối VPN:
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Trên Client
# Cài đặt NGINX (Trên máy Local):
sudo apt-get install -y nginx
sudo systemctl start nginx

# Khai báo đường dẫn log cho Wazuh Agent: Mở lại file ossec.conf trên máy local:
sudo nano /var/ossec/etc/ossec.conf
  #Thêm đoạn sau vào cuối file (ngay trên thẻ </ossec_config>):
XML
  <!-- Đọc log truy cập của NGINX -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/nginx/access.log</location>
  </localfile>
  # Khởi động lại Agent để áp dụng:
sudo systemctl restart wazuh-agent


# Thiết lập VPN site-to-site giữa Wazuh_Node (VM1) và pfSense local:

azureuser@Wazuh:~$ sudo mkdir -p /etc/wireguard && sudo chmod 700 /etc/wireguard
azureuser@Wazuh:~$ wg genkey | sudo tee /etc/wireguard/vm1_private.key | wg pubkey | sudo tee /etc/wireguard/vm1_public.key
5NBWIFx7tBdH4wNfrW3QBx9sdDm09b1EMMqY/dhsoFs=
azureuser@Wazuh:~$ sudo chmod 600 /etc/wireguard/vm1_private.key
azureuser@Wazuh:~$ echo "=== VM1 Public Key ==="
=== VM1 Public Key ===
azureuser@Wazuh:~$ cat /etc/wireguard/vm1_public.key
cat: /etc/wireguard/vm1_public.key: Permission denied
azureuser@Wazuh:~$ sudo cat /etc/wireguard/vm1_public.key
5NBWIFx7tBdH4wNfrW3QBx9sdDm09b1EMMqY/dhsoFs=
azureuser@Wazuh:~$ sudo cat /etc/wireguard/vm1_private.key
eIcZvTgdx/X0l2UaXVp+MMiMMta4lwwNdG+wy3kiAkk=
azureuser@Wazuh:~$

Public key  của pfsense WireGuard: GcBrvL7DEfHxSjEBFXNRyXzw82ktubaLlTtlaW08zyE=

# Tạo file cấu hình wg0.conf trên VM1 (Wazuh_Node):
sudo nano /etc/wireguard/wg0.conf 
[Interface]
# Địa chỉ IP của đường hầm phía Azure
Address = 10.10.0.2/24
ListenPort = 51820
# Thay đoạn này bằng nội dung file vm1_private.key vừa tạo
PrivateKey = eIcZvTgdx/X0l2UaXVp+MMiMMta4lwwNdG+wy3kiAkk=

# Cấu hình iptables để NAT và Forwarding traffic giữa đường hầm (wg0) và mạng Azure (eth0)
PostUp = iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT; iptables -A FORWARD -i eth0 -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -o eth0 -j ACCEPT; iptables -D FORWARD -i eth0 -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# Đây là Gateway đầu kia (pfSense)
PublicKey = GcBrvL7DEfHxSjEBFXNRyXzw82ktubaLlTtlaW08zyE=
# Cho phép định tuyến toàn bộ các dải mạng Local đi vào đường hầm này
AllowedIPs = 192.168.21.0/24, 192.168.51.0/24, 192.168.69.0/24, 192.168.96.0/24, 10.81.51.0/24, 10.10.0.1/24
PersistentKeepalive = 25


# 5. Phân quyền và khởi động [cite: 1800-1804]
sudo chmod 600 /etc/wireguard/wg0.conf
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0



# Trên máy Wazuh_Node (VM1): Thêm rule để phát hiện log NGINX:
sudo nano /var/ossec/etc/rules/local_rules.xml
