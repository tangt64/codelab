# 관리자 인증
source /etc/kolla/admin-openrc.sh

# 필요 시 Flavor, Keypair, Security Group 기본 설정
openstack flavor create --ram 1024 --vcpus 1 --disk 10 m1.small
openstack keypair create mykey > mykey.pem
chmod 600 mykey.pem
openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default
# External Network (flat)
openstack network create net-external \
  --provider-physical-network physnet1 \
  --provider-network-type flat \
  --external

# Subnet
openstack subnet create sn-external \
  --network net-external \
  --subnet-range 192.168.100.0/24 \
  --no-dhcp \
  --gateway 192.168.100.1 \
  --allocation-pool start=192.168.100.150,end=192.168.100.200
# Internal Network (VXLAN or geneve)
openstack network create net-internal

# Subnet
openstack subnet create sn-internal \
  --network net-internal \
  --subnet-range 172.16.0.0/24 \
  --gateway 172.16.0.1 \
  --dns-nameserver 8.8.8.8 \
  --dhcp
# Router 생성
openstack router create router1

# 외부망 연결
openstack router set router1 --external-gateway net-external

# 내부망 연결
openstack router add subnet router1 sn-internal
# Cirros 같은 테스트 이미지 등록 (없다면)
openstack image create cirros \
  --disk-format qcow2 \
  --container-format bare \
  --file /usr/share/kolla-ansible/etc_examples/kolla/images/cirros-0.6.2-x86_64-disk.img \
  --public

# 네트워크와 키페어 지정하여 인스턴스 생성
openstack server create test-vm \
  --flavor m1.small \
  --image cirros \
  --network net-internal \
  --key-name mykey
# Floating IP 생성 (192.168.100.150~200 중 하나)
FLOAT_IP=$(openstack floating ip create net-external -f value -c floating_ip_address)
echo "Floating IP = $FLOAT_IP"

# 인스턴스에 연결
openstack server add floating ip test-vm $FLOAT_IP
# 인스턴스 상태
openstack server list
# -> test-vm 에 floating IP (192.168.100.xxx) 표시

# 네트워크/라우터 상태
openstack network list
openstack router list
openstack port list --router router1

# 연결 확인
ping -c 4 $FLOAT_IP
ssh -i mykey.pem cirros@$FLOAT_IP
