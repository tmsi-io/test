#!/bin/sh

ip link add cni0 type bridge
ip link set cni0 up
ip netns add ns0
ip netns add ns1

ip link add veth01 netns ns0 type veth peer name veth-host01
ip netns exec ns0 ip link set veth01 up
ip link add veth11 netns ns1 type veth peer name veth-host11
ip netns exec ns1 ip link set veth11 up

ip link set veth-host01 master cni0
ip link set veth-host11 master cni0

ip link set veth-host01 up
ip link set veth-host11 up

ip addr add 10.244.0.1/24 dev cni0

ip netns exec ns0 ip addr add 10.244.0.2/24 dev veth01
ip netns exec ns1 ip addr add 10.244.0.3/24 dev veth11


iptables -t nat -A POSTROUTING -s 10.244.0.0/16 -o vxlan0 -j MASQUERADE
iptables -A FORWARD -i cni0 -o vxlan0 -j ACCEPT
iptables -A FORWARD -o cni0 -i vxlan0 -j ACCEPT

