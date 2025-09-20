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
	}
}

#Node: {
	name:               =~"^[a-z0-9][a-z0-9\\-]{0,61}[a-z0-9]$|^[a-z0-9]$" & !="global" & !="controller" & !="worker"
	address:            net.IPv4
	cluster_address?:   net.IPv4
	controller:         bool
	disk:               string

	// External network interfaces - single or multiple (bonding)
	mac_addr?:          =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	mac_addr_1?:        =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	mac_addr_2?:        =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	mac_addr_3?:        =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	mac_addr_4?:        =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	mac_addr_5?:        =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	mac_addr_6?:        =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	mac_addr_7?:        =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	mac_addr_8?:        =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	mac_addr_9?:        =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"

	// Cluster network interfaces - single or multiple (bridging)
	cluster_mac_addr?:  =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	cluster_mac_addr_1?: =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	cluster_mac_addr_2?: =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	cluster_mac_addr_3?: =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	cluster_mac_addr_4?: =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	cluster_mac_addr_5?: =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	cluster_mac_addr_6?: =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	cluster_mac_addr_7?: =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	cluster_mac_addr_8?: =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"
	cluster_mac_addr_9?: =~"^([0-9a-f]{2}[:]){5}([0-9a-f]{2})$"

	schematic_id:       =~"^[a-z0-9]{64}$"
	mtu?:               >=1450 & <=9000
	cluster_mtu?:       >=1450 & <=9000
	secureboot?:        bool
	encrypt_disk?:      bool

	// Ensure at least one external interface is defined
	_external_interface_check: or([
		mac_addr != _|_,
		mac_addr_1 != _|_,
	])
}

#Config
