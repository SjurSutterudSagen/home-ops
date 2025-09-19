package config

import (
	"net"
	"list"
)

#Config: {
	nodes: [...#Node]
	_nodes_check: {
		name: list.UniqueItems() & [for item in nodes {item.name}]
		address: list.UniqueItems() & [for item in nodes {item.address}]
		cluster_address: list.UniqueItems() & [for item in nodes if item.cluster_address != _|_ {item.cluster_address}]
		mac_addr: list.UniqueItems() & [for item in nodes {item.mac_addr}]
		cluster_mac_addr: list.UniqueItems() & [for item in nodes if item.cluster_mac_addr != _|_ {item.cluster_mac_addr}]
	}
}

#Node: {
	name:               =~"^[a-z0-9][a-z0-9\\-]{0,61}[a-z0-9]$|^[a-z0-9]$" & !="global" & !="controller" & !="worker"
	address:            net.IPv4
	cluster_address?:   net.IPv4
	controller:         bool
	disk:               string
	mac_addr:           =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	cluster_mac_addr?:  =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	schematic_id:       =~"^[a-z0-9]{64}$"
	mtu?:               >=1450 & <=9000
	cluster_mtu?:       >=1450 & <=9000
	secureboot?:        bool
	encrypt_disk?:      bool
}

#Config
