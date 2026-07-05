# Tren VM Suricata (Ubuntu 22.04, VMnet3 + VMnet5)
sudo apt-get update && sudo apt-get install -y suricata suricata-update
# Cau hinh /etc/suricata/suricata.yaml
# af-packet:
#   - interface: ens33  # interface huong ve LAN/DMZ
#     cluster-id: 99
#     cluster-type: cluster_flow
#     defrag: yes
# Cap nhat rules
sudo suricata-update update-sources
sudo suricata-update enable-source et/open
sudo suricata-update
# Khoi dong
sudo systemctl enable suricata && sudo systemctl start suricata
# Cau hinh output JSON (cho Filebeat doc)
# /etc/suricata/suricata.yaml
# outputs:
#   - eve-log:
#       enabled: yes
#       filetype: regular
#       filename: /var/log/suricata/eve.json
#       types:
#         - alert
#         - dns
#         - http

# 1. Cài đặt các gói hỗ trợ cần thiết
sudo apt update
sudo apt install -y curl gnupg2

# 2. Thêm khóa GPG của Zeek
curl -fsSL https://download.opensuse.org/repositories/security:zeek/xUbuntu_22.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/zeek.gpg > /dev/null

# 3. Thêm repository vào danh sách nguồn của apt
echo 'deb http://download.opensuse.org/repositories/security:/zeek/xUbuntu_22.04/ /' | sudo tee /etc/apt/sources.list.d/zeek.list

# 4. Cập nhật lại danh sách gói
sudo apt update
sudo apt-get install -y zeek
# Cau hinh /etc/zeek/node.cfg
# [zeek]
# type=standalone
# host=localhost
# interface=ens33
# Cau hinh /etc/zeek/networks.cfg
# 192.168.0.0/16   Internal
# Kich hoat JSON logs
echo '@load policy/tuning/json-logs' | sudo tee -a /usr/share/zeek/site/local.zeek
#Phien ban 2.0 | VMware Local + Cloud Azure
sudo zeekctl deploy
sudo zeekctl status

# Cài đặt Wazuh Agent trên VM1 (Azure) để kết nối với Wazuh Manager Cloud qua WireGuard
sudo curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
sudo echo 'deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main' | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt-get update

# Cài đặt và trỏ đến Wazuh Manager Cloud qua IP WireGuard
WAZUH_MANAGER='10.10.0.1' sudo apt-get install -y wazuh-agent

sudo nano /var/ossec/etc/ossec.conf

sudo systemctl restart wazuh-agent

sudo chmod 600 /etc/netplan/*.yaml
sudo systemctl enable systemd-networkd
sudo systemctl start systemd-networkd

sudo netplan apply


sudo apt update
sudo apt install iptables-persistent -y

sudo netfilter-persistent save

Phần 2: Viết luật Pass/Whitelist trong Suricata
Mặc định, nếu không có rule nào cảnh báo (alert) hoặc chặn (drop), Suricata sẽ tự động cho traffic đi qua. Tuy nhiên, trong hệ thống SOC, để tránh False Positive (chặn nhầm) làm đứt gãy luồng kết nối của các agent (như luồng log Wazuh gửi lên Manager qua VPN), bạn nên viết các luật pass (ưu tiên cao nhất) để Bypass kiểm tra với các traffic nội bộ được tin tưởng tuyệt đối.

1. Tạo file rule cục bộ:

Bash
sudo nano /etc/suricata/rules/local.rules
2. Thêm các luật cho phép đi qua lại:
Dưới đây là một số luật mẫu để bạn áp dụng:

Đoạn mã
# Cho phép toàn bộ traffic từ vùng LAN/DMZ kết nối an toàn với máy pfSense (Gateway)
pass ip [192.168.69.0/24, 192.168.96.0/24] any <> 192.168.21.1 any (msg:"Pass Local to pfSense Interface"; sid:1000001; rev:1;)

# Cho phép Wazuh Agent dưới LAN (port 1514, 1515) giao tiếp thoải mái lên Wazuh Manager mà không bị drop nhầm
pass tcp [192.168.69.0/24, 192.168.96.0/24] any -> any [1514,1515] (msg:"Pass Wazuh Agent Traffic"; sid:1000002; rev:1;)

# Bỏ qua kiểm tra gắt gao với luồng VPN WireGuard (port 51820)
pass udp any any <> any 51820 (msg:"Pass WireGuard Tunnel Traffic"; sid:1000003; rev:1;)
3. Báo cho Suricata biết rule mới và khởi động lại:
Mở file /etc/suricata/suricata.yaml, kéo xuống phần rule-files: và đảm bảo dòng - local.rules đã được khai báo.

Sau đó khởi động lại dịch vụ:

Bash
sudo systemctl restart suricata
Bây giờ luồng mạng đã được mở hoàn toàn. Mọi gói tin từ LAN/DMZ đều sẽ bị iptables tóm lại, ném vào Suricata. Suricata sẽ đối chiếu tập rules (ET Open + Local Rules của bạn), nếu thấy an toàn hoặc khớp với luật pass, gói tin sẽ lập tức được trả về iptables để tiếp tục chặng đường đến pfSense.
