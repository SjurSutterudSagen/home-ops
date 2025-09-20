# Dual Network Configuration Guide

This guide explains how to configure the cluster template for a dual-network setup with high-speed direct connections between nodes for cluster traffic and separate external network interfaces for internet access.

**NEW**: The template now supports **flexible network configurations** including interface bonding, bridging, and mesh topologies.

## Overview

In a dual-network configuration:
- **External Network (`node_cidr`)**: Slower ethernet connections with internet access for management, external services, and ingress traffic
- **Cluster Network (`cluster_cidr`)**: High-speed direct connections between nodes for internal Kubernetes traffic (etcd, kubelet, pod-to-pod communication)

## Benefits

1. **Performance**: High-speed cluster network improves etcd performance, pod-to-pod communication, and storage replication
2. **Isolation**: Separates cluster traffic from external traffic for better security and performance
3. **Scalability**: Reduces congestion on the external network by offloading cluster communication
4. **Redundancy**: Support for bonded external interfaces and bridged cluster interfaces
5. **Flexibility**: Mix and match single/multiple interfaces per node based on hardware capabilities

## Network Planning

### IP Address Allocation

You'll need to plan two separate network ranges:

#### External Network (`node_cidr`)
- Used for: Management access, external services, ingress traffic
- Example: `192.168.1.0/24`
- Needs: Internet gateway, DNS servers

#### Cluster Network (`cluster_cidr`)
- Used for: Kubernetes API, etcd, kubelet, pod-to-pod communication, load balancer services
- Example: `10.0.0.0/24`
- Needs: High-speed direct connections between nodes (no internet required)

### Example Configuration

For a 3-node cluster:

**External Network (192.168.1.0/24):**
- Gateway: `192.168.1.1`
- Node 1: `192.168.1.10`
- Node 2: `192.168.1.11`
- Node 3: `192.168.1.12`

**Cluster Network (10.0.0.0/24):**
- Node 1: `10.0.0.10`
- Node 2: `10.0.0.11`
- Node 3: `10.0.0.12`
- Kubernetes API VIP: `10.0.0.100`
- Internal Gateway: `10.0.0.101`
- DNS Gateway: `10.0.0.102`

## Configuration Files

### cluster.yaml

```yaml
---
# External network (management/internet access)
node_cidr: "192.168.1.0/24"

# Cluster network (high-speed direct connections)
cluster_cidr: "10.0.0.0/24"

# Gateways
node_default_gateway: "192.168.1.1"       # External network gateway
cluster_default_gateway: "10.0.0.1"       # Cluster network gateway (optional)

# Kubernetes API on cluster network
cluster_api_addr: "10.0.0.100"

# Load balancer IPs on cluster network
cluster_dns_gateway_addr: "10.0.0.102"
cluster_gateway_addr: "10.0.0.101"

# External gateway on external network
cloudflare_gateway_addr: "192.168.1.200"

# Other required settings...
cloudflare_domain: "your-domain.com"
cloudflare_token: "your-token"
repository_name: "your-username/your-repo"
```

### nodes.yaml

The template supports **multiple network interface configurations**:

#### **Traditional Mode (Single Interfaces)**
```yaml
---
nodes:
  - name: "node-1"
    address: "192.168.1.10"              # External network IP
    cluster_address: "10.0.0.10"         # Cluster network IP
    controller: true
    disk: "/dev/sda"
    mac_addr: "aa:bb:cc:dd:ee:01"         # External NIC MAC
    cluster_mac_addr: "aa:bb:cc:dd:ee:11" # Cluster NIC MAC
    schematic_id: "your-schematic-id"
    mtu: 1500                             # External network MTU
    cluster_mtu: 1500                     # Cluster network MTU
```

#### **External Bonding Mode (Redundant External)**
Active-backup bonding for external interface redundancy:
```yaml
  - name: "node-2"
    address: "192.168.1.11"
    cluster_address: "10.0.0.11"
    controller: true
    disk: "/dev/sda"
    mac_addr_1: "aa:bb:cc:dd:ee:02"       # External NIC 1 (bonded)
    mac_addr_2: "aa:bb:cc:dd:ee:03"       # External NIC 2 (bonded)
    cluster_mac_addr: "aa:bb:cc:dd:ee:12" # Single cluster NIC
    schematic_id: "your-schematic-id"
```
**Benefits**: Plug external cable into either port, automatic failover.

#### **Cluster Bridging Mode (Mesh Topology)**
Bridge multiple cluster interfaces for direct node connections:
```yaml
  - name: "node-3"
    address: "192.168.1.12"
    cluster_address: "10.0.0.12"
    controller: true
    disk: "/dev/sda"
    mac_addr: "aa:bb:cc:dd:ee:04"         # Single external NIC
    cluster_mac_addr_1: "aa:bb:cc:dd:ee:13" # Cluster NIC 1 (to node-1)
    cluster_mac_addr_2: "aa:bb:cc:dd:ee:14" # Cluster NIC 2 (to node-2)
    schematic_id: "your-schematic-id"
```
**Benefits**: Direct high-speed connections, mesh topology, no cluster switch needed.

#### **Full Redundancy Mode (Bonding + Bridging)**
Maximum redundancy for both networks:
```yaml
  - name: "node-4"
    address: "192.168.1.13"
    cluster_address: "10.0.0.13"
    controller: false                     # Worker node
    disk: "/dev/sda"
    mac_addr_1: "aa:bb:cc:dd:ee:05"       # External NIC 1 (bonded)
    mac_addr_2: "aa:bb:cc:dd:ee:06"       # External NIC 2 (bonded)
    cluster_mac_addr_1: "aa:bb:cc:dd:ee:15" # Cluster NIC 1 (bridged)
    cluster_mac_addr_2: "aa:bb:cc:dd:ee:16" # Cluster NIC 2 (bridged)
    schematic_id: "your-schematic-id"
```

> **Auto-Detection**: The template automatically detects which mode to use based on the MAC address fields you provide. See `nodes.sample.yaml` for more examples.

## Hardware Setup

### Physical Connection Options

The template supports multiple physical topologies:

#### **1. Traditional Dual-Network (Switch-based)**
- **External Network**: Each node connects to your main router/switch
- **Cluster Network**: Each node connects to a dedicated high-speed switch
- **Configuration**: Use single MAC addresses (`mac_addr`, `cluster_mac_addr`)

#### **2. Mesh Topology (Direct Connections)**
- **External Network**: Each node connects to your main router/switch
- **Cluster Network**: Direct point-to-point connections between nodes:
  - Node 1 ↔ Node 2 (direct cable)
  - Node 1 ↔ Node 3 (direct cable)
  - Node 2 ↔ Node 3 (direct cable)
- **Configuration**: Use multiple cluster MAC addresses (`cluster_mac_addr_1`, `cluster_mac_addr_2`)
- **Benefits**: No cluster switch needed, maximum performance, lower latency

#### **3. Redundant External (Bonded)**
- **External Network**: Each node uses 2+ interfaces bonded for failover
- **Cluster Network**: Single or multiple cluster interfaces
- **Configuration**: Use multiple external MAC addresses (`mac_addr_1`, `mac_addr_2`)
- **Benefits**: Cable in any external port, automatic failover

#### **4. Full Redundancy (Bonded + Bridged)**
- **External Network**: Bonded interfaces for failover
- **Cluster Network**: Multiple interfaces bridged for performance/redundancy
- **Configuration**: Use both multiple external and cluster MAC addresses
- **Benefits**: Maximum redundancy and performance

### Network Interface Identification

Before configuration, identify your network interfaces on each node:

```bash
# Boot from Talos ISO and run:
talosctl get links --nodes <node-ip> --insecure

# This will show you the MAC addresses of each interface
# Use these MAC addresses in your nodes.yaml configuration
```

### Recommended Physical Setups

#### **For 2-port nodes (most common):**
- **Port 1**: External network (to router/switch)
- **Port 2**: Cluster network (direct connection or cluster switch)

#### **For 4-port nodes (high-end):**
- **Ports 1-2**: External network (bonded for redundancy)
- **Ports 3-4**: Cluster network (bridged for performance/mesh)

## MTU Considerations

- **External Network**: Standard 1500 MTU for compatibility
- **Cluster Network**: Consider jumbo frames (9000 MTU) for better performance on high-speed connections

## Flexible Network Configuration Details

### Automatic Detection Logic

The template automatically detects your configuration based on MAC address fields:

- **Single External**: `mac_addr` → Standard interface configuration
- **Bonded External**: `mac_addr_1`, `mac_addr_2`, etc. → Active-backup bond with failover
- **Single Cluster**: `cluster_mac_addr` → Standard cluster interface
- **Bridged Cluster**: `cluster_mac_addr_1`, `cluster_mac_addr_2`, etc. → Bridge for mesh topology

### Bonding vs Bridging

#### **External Network Bonding (Active-Backup)**
- **Purpose**: Failover and redundancy
- **Mode**: Only one interface active at a time
- **Benefit**: Plug cable into any port, automatic failover if link fails
- **Use Case**: Ensure external connectivity even if one ethernet port/cable fails

#### **Cluster Network Bridging**
- **Purpose**: Aggregate multiple direct connections
- **Mode**: All interfaces active simultaneously
- **Benefit**: Higher bandwidth, mesh topology support
- **Use Case**: Direct node-to-node connections without requiring switches

### Mixed Configurations

You can mix different configurations within the same cluster:

```yaml
nodes:
  # Controller with full redundancy
  - name: "controller-1"
    mac_addr_1: "..." # Bonded external
    mac_addr_2: "..."
    cluster_mac_addr_1: "..." # Bridged cluster
    cluster_mac_addr_2: "..."

  # Worker with traditional setup
  - name: "worker-1"
    mac_addr: "..." # Single external
    cluster_mac_addr: "..." # Single cluster

  # Worker with external bonding only
  - name: "worker-2"
    mac_addr_1: "..." # Bonded external
    mac_addr_2: "..."
    cluster_mac_addr: "..." # Single cluster
```

### Network Interface Naming

The template creates predictable interface names:
- **External Bond**: `bond-external` (combines `external-nic1`, `external-nic2`, etc.)
- **Cluster Bridge**: `br-cluster` (combines `cluster-nic1`, `cluster-nic2`, etc.)
- **Physical Interfaces**: `external-nic1`, `cluster-nic1`, etc.

## DNS and Service Discovery

- **External DNS**: Points to external gateway IP for public services
- **Internal DNS**: Points to cluster gateway IP for internal services
- **k8s_gateway**: Runs on cluster network for internal service discovery

## Traffic Flow

### External Traffic
Internet → Router → External NIC → External Gateway → Services

### Internal Traffic
Pod → Cluster Network → High-speed links → Destination Pod

### API Traffic
kubectl → External Network → Load Balancer → Cluster Network → Kubernetes API

## Troubleshooting

### Common Issues

1. **Interface Detection**: Ensure Cilium is configured with correct device patterns
2. **Routing**: Verify routes are correctly configured on both networks
3. **MTU**: Ensure MTU settings are consistent across the cluster network
4. **Firewall**: Verify cluster network allows all required Kubernetes ports
5. **Bonding Issues**: Check if bonded interfaces are correctly detecting link status
6. **Bridge Issues**: Verify all physical interfaces are properly added to bridges

### Verification Commands

```bash
# Check network interfaces
talosctl get links --nodes <node-ip>

# Check routes
talosctl get routes --nodes <node-ip>

# Check Cilium status
cilium status

# Check pod-to-pod connectivity
kubectl exec -it <pod-name> -- ping <other-pod-ip>

# Check bonding status (if using bonded external interfaces)
talosctl read /proc/net/bonding/bond-external --nodes <node-ip>

# Check bridge status (if using bridged cluster interfaces)
talosctl read /sys/class/net/br-cluster/bridge/ --nodes <node-ip>

# Verify interface configurations
talosctl get addresses --nodes <node-ip>
```

### Troubleshooting Bonding Issues

```bash
# Check bond status
talosctl read /proc/net/bonding/bond-external --nodes <node-ip>

# Should show active slave and backup slave(s)
# Example output:
# Bonding Mode: fault-tolerance (active-backup)
# Primary Slave: external-nic1 (primary_reselect always)
# Currently Active Slave: external-nic1
# Slave Interface: external-nic1
# MII Status: up
# Slave Interface: external-nic2
# MII Status: up

# Test failover by disconnecting active interface cable
# Backup interface should become active automatically
```

### Troubleshooting Bridge Issues

```bash
# Check bridge interface status
talosctl read /sys/class/net/br-cluster/bridge/ --nodes <node-ip>

# List bridge members
talosctl exec --nodes <node-ip> -- bridge link show

# Should show cluster-nic1, cluster-nic2, etc. as bridge members
# Example output:
# 3: cluster-nic1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master br-cluster
# 4: cluster-nic2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 master br-cluster

# Check bridge forwarding
talosctl read /sys/class/net/br-cluster/bridge/stp_state --nodes <node-ip>
# Should return: 0 (STP disabled as configured)
```

## Performance Tuning

1. **Enable jumbo frames** on cluster network (MTU 9000)
2. **Use SR-IOV** if available on your NICs
3. **Tune network buffers** for high-throughput applications
4. **Consider DPDK** for ultra-low latency requirements

## Security Considerations

### ⚠️ Critical Security Requirements

1. **Network Isolation**:
   - Cluster network MUST NOT be routable from external networks
   - Use dedicated switches or direct cables for cluster network
   - Implement VLAN isolation if using shared infrastructure

2. **Firewall Configuration**:
   ```bash
   # Example iptables rules for external interface (adapt to your firewall)
   # Block access to cluster network from external sources
   iptables -I FORWARD -i eth0 -o eth1 -j DROP
   iptables -I FORWARD -s 10.0.0.0/24 -o eth0 -j DROP
   ```

3. **Interface Access Control**:
   - Physically secure cluster network connections
   - Use locked server racks or cabinets
   - Consider using fiber optic connections for tamper resistance

4. **Network Encryption** (Recommended for sensitive environments):
   ```yaml
   # Add to Talos machine configuration for IPSec encryption
   machine:
     network:
       kubespan:
         enabled: true
         allowDownPeerBypass: false
   ```

5. **Monitoring and Auditing**:
   - Monitor cluster network traffic for anomalies
   - Log access to cluster network interfaces
   - Set up alerts for unexpected network activity

### 🔒 Secure Configuration Practices

1. **Device Pattern Specification**:
   ```yaml
   # In Cilium configuration - BE SPECIFIC about interfaces
   # BAD (too permissive):
   devices: eth+ eno+

   # GOOD (specific to your cluster NICs):
   devices: eth1 eno2 enp2s0
   ```

2. **MTU Configuration**:
   - Start with standard MTU (1500) and test before enabling jumbo frames
   - Ensure all network infrastructure supports chosen MTU
   - Test end-to-end connectivity before production deployment

3. **Route Table Isolation** (Advanced):
   ```bash
   # Consider using policy-based routing for additional isolation
   ip rule add from 10.0.0.0/24 table 100
   ip route add default via 10.0.0.1 table 100
   ```

### 🚨 Security Warnings

**WARNING**: The cluster network carries sensitive traffic including:
- Kubernetes API communication
- etcd cluster data
- Pod-to-pod communication
- Secret and certificate data

**CRITICAL**: Never expose cluster network interfaces to untrusted networks or the internet.

**IMPORTANT**: Regularly audit network configurations and access controls.

### 📋 Security Checklist

Before deploying your dual-network cluster, ensure you've completed these security steps:

#### Network Isolation
- [ ] Cluster network is physically separated from external networks
- [ ] No routing configured between cluster and external networks
- [ ] Firewall rules prevent cross-network access
- [ ] Network switches/infrastructure properly configured

#### Interface Security
- [ ] Cilium device patterns specify exact interfaces (not wildcards)
- [ ] Interface names verified on all nodes
- [ ] No unnecessary interfaces included in cluster network
- [ ] Physical access to cluster network ports is restricted

#### Configuration Security
- [ ] MTU settings tested and validated across all nodes
- [ ] Network interface MAC addresses correctly identified
- [ ] IP address ranges don't overlap between networks
- [ ] VIP addresses properly configured

#### Monitoring & Auditing
- [ ] Network traffic monitoring configured
- [ ] Log aggregation for network events
- [ ] Alerting set up for unusual network activity
- [ ] Regular security audits scheduled

#### Access Control
- [ ] Management access limited to external network only
- [ ] No unnecessary services exposed on cluster network
- [ ] Strong authentication configured for cluster access
- [ ] Network access logs reviewed regularly