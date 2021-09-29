#!/bin/sh
#----------------------------------------------+
#                      |                       |
#         host1        |         host2         |
#      -----------     |      -----------      |
#      | vxlan0  |     |      | vxlan0  |      |
#      -----|-----     |      ----|------      |
#           |  \       |      /   |            |
#           |   \      |     /    |            |
#   UDP:    |    \___vxlan__/     |            |
#           |          |          |            |
#           |          |          |            |
#      -----|-----     |    ------|----        |
#      |  ens01 | --------- |  ens02  |--------|
#      ----------      |    ----------         |
#       phy nic        |         phy nic       |
#                      |                       |
#----------------------------------------------+

# this shell was simple VxLan config with two linux hosts.
#
#
#

# check input argument len
check_argu_len () {
  if [ ${#2} -eq 0 ]; then
    echo "Argument value for '$1' was too short. "
    exit 1
  fi
}


while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
        echo "vxlan.sh - attempt to set vxlan demo"
        echo " "
        echo "vxlan.sh [options]"
        echo " "
        echo "options:"
        echo "--vxlan-dev=,            specify an vxlan device name"
        echo "--vxlan-id=,             specify an vxlan id(vni?)"
        echo "--vxlan-mac=,            specify a vxlan mac"
        echo "--host-nic=,             specify local host nic name"
        echo "--vxlan-ip=,             specify vxlan ip "
        echo "--peer-vxlan-ip=,        specify peer vxlan ip"
        echo "--peer-vxlan-mac=,       specify peer vxlan mac"
        echo "--peer-host-ip=,         specify peer host ip "
        echo "--vxlan-port=,           specify vxlan communication port "
        exit 0
        ;;
    --vxlan-dev=*)
      vxlan_dev="${1#*=}"
      ;;
    --vxlan-id=*)
      vxlan_id="${1#*=}"
      ;;
    --vxlan-mac=*)
      vxlan_mac="${1#*=}"
      ;;
    --host-nic=*)
      host_nic="${1#*=}"
      ;;
    --vxlan-ip=*)
      vxlan_ip="${1#*=}"
      ;;
    --peer-vxlan-ip=*)
      peer_vxlan_ip="${1#*=}"
      ;;
    --peer-vxlan-mac=*)
      peer_vxlan_mac="${1#*=}"
      ;;
    --peer-host-ip=*)
      peer_host_ip="${1#*=}"
      ;;
    --vxlan-port=*)
      connect_port="${1#*=}"
      ;;
    *)
  esac
  shift
done



check_argu_len '--peer-vxlan-mac' ${peer_vxlan_mac}
check_argu_len '--vxlan-port' ${connect_port}
check_argu_len '--peer-host-ip' ${peer_host_ip}
check_argu_len '--peer-vxlan-ip' ${peer_vxlan_ip}
check_argu_len '--vxlan-ip' ${vxlan_ip}
check_argu_len '--host-nic' ${host_nic}
check_argu_len '--vxlan-mac' ${vxlan_mac}
check_argu_len '--vxlan-id' ${vxlan_id}
check_argu_len '--vxlan-dev' ${vxlan_dev}

echo "   Start add vxlan device"
ip link add ${vxlan_dev} type vxlan id ${vxlan_id} dev ${host_nic} dstport ${connect_port}
echo "   Set vxlan device mac"
ip link set dev ${vxlan_dev} address ${vxlan_mac}
echo "   Set vxlan device up "
ip link set dev ${vxlan_dev} up
echo "   Set ip addr for vxlan device"
ip ad add ${vxlan_ip}/24 dev ${vxlan_dev}
echo "   Add neigh peer for vxlan device"
ip neigh add ${peer_vxlan_ip} lladdr ${peer_vxlan_mac} dev ${vxlan_dev} nud permanent
echo "   Add map for peer ip and mac. "
bridge fdb add to ${peer_vxlan_mac} dst ${peer_host_ip} dev ${vxlan_dev}

echo "   Showing Vxlan neigh info: "
ip neigh show dev ${vxlan_dev}
echo "   Showing fdb info for vxlan"
bridge fdb show dev ${vxlan_dev}
ip ad show dev ${vxlan_dev}
ip -d link show dev ${vxlan_dev}
ping ${peer_vxlan_ip}
