# 관리자 권한으로
source /etc/kolla/admin-openrc.sh

echo "🧹 [STEP 1] Floating IP 제거..."
for fip in $(openstack floating ip list -f value -c ID); do
    echo " - Deleting floating IP: $fip"
    openstack floating ip delete $fip || true
done

echo "🧹 [STEP 2] 인스턴스(서버) 제거..."
for vm in $(openstack server list -f value -c ID); do
    echo " - Deleting instance: $vm"
    openstack server delete $vm || true
done

echo "🧹 [STEP 3] 라우터 인터페이스 제거..."
for router in $(openstack router list -f value -c Name); do
    for subnet in $(openstack router show $router -f value -c interfaces_info | grep -o "'subnet_id': '[^']*" | awk -F"'" '{print $4}'); do
        echo " - Removing subnet $subnet from router $router"
        openstack router remove subnet $router $subnet || true
    done
done

echo "🧹 [STEP 4] 라우터 삭제..."
for router in $(openstack router list -f value -c ID); do
    echo " - Deleting router: $router"
    openstack router delete $router || true
done

echo "🧹 [STEP 5] 서브넷 삭제..."
for subnet in $(openstack subnet list -f value -c ID); do
    echo " - Deleting subnet: $subnet"
    openstack subnet delete $subnet || true
done

echo "🧹 [STEP 6] 네트워크 삭제..."
for net in $(openstack network list -f value -c ID); do
    echo " - Deleting network: $net"
    openstack network delete $net || true
done

echo "✅ [DONE] 모든 network / router / instance / floating IP 정리 완료!"
