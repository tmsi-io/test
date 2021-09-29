#!/bin/sh

#   |----------------------------------------------------------------------+--------------+
#   |   container0      containern      |     container0      containern   |              |
#   |    ------           -----         |      ------           -----      |              |
#   |    |eth0|          |ethn|         |      |eth0|          |ethn|      | container    |
#   |    ------          -----          |      ------          -----       |  network ns  |
#   |       |              |            |       |              |           |              |
#   |      veth           veth          |      veth           veth         |              |
#   |_______|______________|____________|_______|______________|___________|______________|
#   |     --------        --------      |      --------        --------    |              |
#   |     |veth01|        |veth0n|      |      |veth01|        |veth0n|    |              |
#   |     -------         --------      |      -------         --------    |              |
#   |        |             |            |         |             |          |              |
#   |        |             |            |         |             |          |              |
#   |      ------------------           |        ------------------        |              |
#   |      |  cni1(bridge)  |           |        |  cni1(bridge)  |        |   Host       |
#   |      -----------------            |        -----------------         |   Network ns |
#   |            | <-route              |          route->    |            |              |
#   |      -----------                  |                 -----------      |              |
#   |      | vxlan0  |                  |                 | vxlan0  |      |              |
#   |      -----|-----                  |                 ----|------      |              |
#   |           |  \                    |                 /   |            |              |
#   |           |   \                   |                /    |            |              |
#   |   UDP:    |    \________________vxlan_____________/     |            |              |
#   |           |                       |                     |            |              |
#   |           |                       |                     |            |              |
#   |      -----|-----                  |               ------|----        |              |
#   |      |  ens01 | ----------------cable------------ |  ens01  |        |              |
#   |      ----------                   |               ----------         |              |
#   |       phy nic                     |                 phy nic          |              |
#   |                                   |                                  |              |
#   |       host1                       |                 host2            |              |
#   |----------------------------------------------------------------------+--------------|

# this shell was simple VxLan like flannel.
#
# ./test.sh --peer-vxlan-mac=3e:32:f7:c5:a3:5c --vxlan-port=4976 --peer-host-ip=10.100.100.203 --peer-vxlan-ip-num=2 --vxlan-ip-num=1 --host-nic=ens192 --vxlan-mac=3e:32:f7:c5:a3:5b --vxlan-id=9 --vxlan-dev=vxlan01 --sub-net=10.230
# ./test.sh --peer-vxlan-mac=3e:32:f7:c5:a3:5b --vxlan-port=4976 --peer-host-ip=10.100.100.202 --peer-vxlan-ip-num=1 --vxlan-ip-num=2 --host-nic=ens32 --vxlan-mac=3e:32:f7:c5:a3:5c --vxlan-id=9 --vxlan-dev=vxlan01 --sub-net=10.230

#readonly ns_list=11,12,13

# check input argument len
check_argu_len() {
  if [ ${#2} -eq 0 ]; then
    echo "Argument value for '$1' was too short. "
    exit 1
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
  --help | -h)
    echo "vxlan.sh - attempt to set vxlan demo"
    echo " "
    echo "vxlan.sh [options]"
    echo " "
    echo "options:"
    echo "--vxlan-dev=,             specify an vxlan device name"
    echo "--vxlan-id=,              specify an vxlan id(vni?)"
    echo "--vxlan-mac=,             specify a vxlan mac"
    echo "--host-nic=,              specify local host nic name"
    echo "--vxlan-ip-num=,          specify vxlan ip "
    echo "--peer-vxlan-ip-num=,     specify peer vxlan ip"
    echo "--peer-vxlan-mac=,        specify peer vxlan mac"
    echo "--peer-host-ip=,          specify peer host ip "
    echo "--vxlan-port=,            specify vxlan communication port "
    echo "--sub-net=,               specify subnet for vxlan, eg: 10.124 "
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
  --vxlan-ip-num=*)
    vxlan_ip_num="${1#*=}"
    ;;
  --peer-vxlan-ip-num=*)
    peer_vxlan_ip_num="${1#*=}"
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
  --sub-net=*)
    sub_net="${1#*=}"
    ;;
  *) ;;
  esac
  shift
done

check_argument_list() {
  echo "   Start Check input argument..."
  check_argu_len '--peer-vxlan-mac' ${peer_vxlan_mac}
  check_argu_len '--vxlan-port' ${connect_port}
  check_argu_len '--peer-host-ip' ${peer_host_ip}
  check_argu_len '--peer-vxlan-ip-num' ${peer_vxlan_ip_num}
  check_argu_len '--vxlan-ip-num' ${vxlan_ip_num}
  check_argu_len '--host-nic' ${host_nic}
  check_argu_len '--vxlan-mac' ${vxlan_mac}
  check_argu_len '--vxlan-id' ${vxlan_id}
  check_argu_len '--vxlan-dev' ${vxlan_dev}
  check_argu_len '--sub-net' ${sub_net}
}

set_vxlan() {
  echo "   Start add vxlan device"
  ip link add ${vxlan_dev} type vxlan id ${vxlan_id} dev ${host_nic} dstport ${connect_port}
  echo "   Set vxlan device mac"
  ip link set dev ${vxlan_dev} address ${vxlan_mac}
  echo "   Set vxlan device up "
  ip link set dev ${vxlan_dev} up
  echo "   Set ip addr for vxlan device"
  ip ad add ${sub_net}.${vxlan_ip_num}.1/16 dev ${vxlan_dev}
  echo "   Add neigh peer for vxlan device"
  ip neigh add ${sub_net}.${peer_vxlan_ip_num}.1 lladdr ${peer_vxlan_mac} dev ${vxlan_dev} nud permanent
  echo "   Add map for peer ip and mac. "
  bridge fdb add to ${peer_vxlan_mac} dst ${peer_host_ip} dev ${vxlan_dev}
  echo "   Add vxlan network route"
  ip r add ${sub_net}.${peer_vxlan_ip_num}.0/24 via ${sub_net}.${peer_vxlan_ip_num}.1 dev ${vxlan_dev}
}

show_vxlan_and_check() {
  echo "   Showing Vxlan neigh info: "
  ip neigh show dev ${vxlan_dev}
  echo "   Showing fdb info for vxlan"
  bridge fdb show dev ${vxlan_dev}
  ip ad show dev ${vxlan_dev}
  ip -d link show dev ${vxlan_dev}
  ping ${sub_net}.${peer_vxlan_ip_num}.1 -c 5 -w 3
}

add_netns_and_interface() {
  echo "   Start create netns${1} and it's device. "
  ip netns add ns$1
  ip link add veth${1}1 netns ns${1} type veth peer name veth-host${1}1
  ip netns exec ns${1} ip addr add ${sub_net}.${vxlan_ip_num}.${1}/24 dev veth${1}1
  ip netns exec ns${1} ip link set veth${1}1 up
  ip netns exec ns${1} ip route add default via ${sub_net}.${vxlan_ip_num}.1
  echo "   Create netns${1} and it's device over. "
}

up_host_veth() {
  echo "   Uplink host side [ veth-host${1}1 ] veth interface. "
  ip link set veth-host${1}1 up
}

add_bridge() {
  echo "   Create bridge and up start with device name cni1.  "
  ip link add cni1 type bridge
  ip link set cni1 up
  ip addr add ${sub_net}.${vxlan_ip_num}.2/24 dev cni1
}

clean_mac() {
  ip neigh del ${sub_net}.${peer_vxlan_ip_num}.1 lladdr ${peer_vxlan_mac} dev ${vxlan_dev} nud permanent
  bridge fdb del to ${peer_vxlan_mac} dst ${peer_host_ip} dev ${vxlan_dev}
}

bind_veth_to_bridge() {
  echo "   Bind veth-host${1}1 to bridge cni1. "
  ip link set veth-host${1}1 master cni1
}

clean_firewall() {
  echo "   Clear firewall over. "
  iptables -P FORWARD DROP
  iptables -F FORWARD
  iptables -t nat -F
}

set_up_ns_and_intf() {
  for i in 11 12; do
    echo " "
    echo "   Start deal for ns: $i"
    add_netns_and_interface $i
    bind_veth_to_bridge $i
    up_host_veth $i
    echo " "
  done
}

cleanup_netns() {
  for i in 11 12; do
    echo "   Delete network namepspace '$i' ok"
    ip netns del ns$i >/dev/null 2>&1
  done
}

cleanup_interface() {
  for i in 11 12; do
    ip link del veth-host${i}1
  done
  ip link del ${vxlan_dev}
  ip link del cni1
  bridge fdb del ${peer_vxlan_mac} dst ${peer_host_ip} dev ${vxlan_dev}
}

set_iptables() {
  clean_firewall
  echo "   Create firewall rule for forward and address MASQUERADE. "
  iptables -t nat -A POSTROUTING -s ${sub_net}.${vxlan_ip_num}/16 -o ${vxlan_dev} -j MASQUERADE
  iptables -A FORWARD -i cni1 -o ${vxlan_dev} -j ACCEPT
  iptables -A FORWARD -o cni1 -i ${vxlan_dev} -j ACCEPT
}

start() {
  check_argument_list
  set_vxlan
  show_vxlan_and_check
  add_bridge
  set_up_ns_and_intf
  set_iptables
}

exist_clean() {
  clean_firewall
  cleanup_netns
  cleanup_interface
  clean_mac
}

trap exist_clean EXIT

start
