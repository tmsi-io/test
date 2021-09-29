#!/bin/sh
#--------------------------------------------------------------+
#                      |                                       |
#         ns0          |         ns1                           |
#      -----------     |     -----------                       |
#      | veth01  | --------- | veth10  |                       |
#      -----------    peer   -----------                       |
#                      |                                       |
#                      |                                       |
#                      |---------------------------------------|
#                      |                                       |
#                      |                                       |
#      ----------     peer   ----------          --------      |
#      |  veth04 | --------- |  veth99 |--------| ens0  |------|----lan
#      ----------      |     ----------   masq  --------       |
#                      |         host                          |
#                      |                                       |
#--------------------------------------------------------------+
# ns0 : can access lan and namespace network
# ns1 : only  allow access namespace network
# PS: this Danger for product env.

# ns1 veth ip
readonly veth10_v4=10.128.0.2
# ns0 br0 ip
readonly veth01_v4=10.128.0.1
# ns0 veth02 ip
readonly veth04_v4=172.19.0.1
# host veth ip
readonly veth99_v4=172.19.0.2

ip -Version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "   Could not run test without ip command"
	exit 1
fi

host_inf="$1"

if [ -z "$host_inf" ]; then
   echo "   interface :[$host_inf] not exists. "
   echo "   please append interface name in cmdline"
   exit 1
fi

# setup namespace and nic
setup_ns_and_nic() {
  # add network namespace ns0 and ns1 for test
	ip netns add ns0
	ip netns add ns1
  echo "   Create new network namespace 'ns0' and 'ns1' over."
  # add interface and peer for ns0 to ns1
	ip link add veth01 netns ns0 type veth peer name veth10 netns ns1
	echo "   Creat peer between ns0 and ns1 ok. "
	# add interface and peer for ns0 to host
	ip link add veth04 netns ns0 type veth peer name veth99
  echo "   Set peer for ns0 over. "

  ip netns exec ns0 ip link set lo up
	ip netns exec ns0 ip link set veth04 up
	ip netns exec ns0 ip addr add ${veth04_v4}/24 dev veth04
	echo "   Start ns0 nic over. "

	ip netns exec ns0 ip link set veth01 up
	ip netns exec ns0 ip addr add ${veth01_v4}/24 dev veth01
  echo "   Start br0 in ns0 over. "


	ip netns exec ns1 ip link set lo up
	ip netns exec ns1 ip link set veth10 up
	ip netns exec ns1 ip addr add ${veth10_v4}/24 dev veth10

	ip link set veth99 up
	ip addr add ${veth99_v4}/24 dev veth99
	echo "   Set ns1 nic over"
	sleep 1
}

# clean created network namespace, has bug in there?
cleanup_netns() {
	for i in 0 1
	do
	  echo "   Delete network namepspace '$i' ok"
		ip netns del ns$i > /dev/null 2>&1
	done
}

cleanup_firewall() {
    # flush forward rules.
    iptables -P FORWARD DROP
    iptables -F FORWARD
    # flush nat table
    iptables -t nat -F
}

cleanup_env() {
  cleanup_firewall
  cleanup_netns
}

# check
check() {
  echo "   Start ping in ns0. "
  ip netns exec ns0 ping 114.114.114.114 -c 5 -w 2
  echo "   Start ping in ns1. "
  ip netns exec ns1 ping ${veth01_v4} -c 5 -w 2
}

# setup ns default route and link
setup_route() {
  ip netns exec ns0 ip route add default via ${veth99_v4} dev veth04
  echo "   Setup default route for ns0 over."
}

setup_iptables() {
  cleanup_firewall
  # create MASQUERADE rule
  iptables -t nat -A POSTROUTING -s ${veth04_v4}/24 -o ${host_inf} -j MASQUERADE
  # add forward for veth04 and host interface
  iptables -A FORWARD -i ${host_inf} -o veth99 -j ACCEPT
  iptables -A FORWARD -o ${host_inf} -i veth99 -j ACCEPT
  echo "   Setup iptables for MASQUERADE over. "
}

run_tests() {
	setup_ns_and_nic
	setup_route
	setup_iptables
	check
	errors=$(( $errors + $? ))
	return $errors
}

trap cleanup_env EXIT

# entry point.
run_tests
