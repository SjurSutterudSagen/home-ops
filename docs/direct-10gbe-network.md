# Direct 10GbE Node-to-Node Network

Three nodes are connected in a full point-to-point mesh via dedicated 10GbE NICs — one cable per node pair, six NICs total, no intermediate switch. This network carries etcd peer traffic and Kubernetes pod-to-pod traffic, leaving the 1GbE management NICs (`192.168.50.x`) for API server access and external cluster traffic.

## Physical Topology

```
homelab-k8s-c01                homelab-k8s-c02
┌─────────────────┐            ┌─────────────────┐
│ cc:7c (10.1.0.1)├────────────┤(10.1.0.2) cd:44 │
│ cc:7d (10.1.0.5)├──┐      ┌──┤(10.1.0.9) cd:45 │
└─────────────────┘  │      │  └─────────────────┘
                     │      │
homelab-k8s-c03      │      │
┌─────────────────┐  │      │
│cc:4c  (10.1.0.6)├──┘      │
│cc:4d (10.1.0.10)├─────────┘
└─────────────────┘
```

## IP Addressing

### Physical link subnets (/30, one per cable)

| Link | Subnet | c0x IP | c0y IP |
|---|---|---|---|
| c01 ↔ c02 | `10.1.0.0/30` | c01 = `10.1.0.1` | c02 = `10.1.0.2` |
| c01 ↔ c03 | `10.1.0.4/30` | c01 = `10.1.0.5` | c03 = `10.1.0.6` |
| c02 ↔ c03 | `10.1.0.8/30` | c02 = `10.1.0.9` | c03 = `10.1.0.10` |

### Loopback node IPs (`lo`, one per node)

| Node | IP |
|---|---|
| homelab-k8s-c01 | `10.1.1.1/32` |
| homelab-k8s-c02 | `10.1.1.2/32` |
| homelab-k8s-c03 | `10.1.1.3/32` |

Each node also has static routes so its peers' loopback IPs are reachable via the direct links:

| Node | Route | Via (direct link gateway) |
|---|---|---|
| c01 | `10.1.1.2/32` | `10.1.0.2` |
| c01 | `10.1.1.3/32` | `10.1.0.6` |
| c02 | `10.1.1.1/32` | `10.1.0.1` |
| c02 | `10.1.1.3/32` | `10.1.0.10` |
| c03 | `10.1.1.1/32` | `10.1.0.5` |
| c03 | `10.1.1.2/32` | `10.1.0.9` |

## How Pod-to-Pod Routing Uses the 10G Links

Cilium runs in native routing mode with `autoDirectNodeRoutes: true`. It installs kernel routes for each remote pod CIDR, using the remote node's Kubernetes `InternalIP` as the next-hop. Because kubelet's `validSubnets` is set to `10.1.1.0/29`, each node's `InternalIP` is its loopback address (`10.1.1.x`), not its management IP.

With `bpf.hostLegacyRouting: true`, Cilium defers egress to the Linux kernel routing stack. The full chain for a pod on c01 sending to a pod on c02:

```
1. Cilium installs:  10.42.1.0/24 via 10.1.1.2          (c02's InternalIP)
2. Kernel resolves:  10.1.1.2/32  via 10.1.0.2           (static route on c01)
3. Kernel resolves:  10.1.0.2     connected on 10G NIC   (10.1.0.0/30 subnet)
4. Packet exits via the c01↔c02 direct 10G cable ✓
```

No Cilium configuration changes were needed — the routing falls out naturally from setting the kubelet node IP to the loopback and adding the static routes.

etcd is also directed to the internal network: `advertisedSubnets: ["10.1.1.0/29"]` makes etcd peers advertise and prefer the loopback IPs, so etcd replication traffic also flows over the 10G links.

## Configuration Files

All configuration is in Talos machine patches under `templates/config/talos/patches/`:

| File | Purpose |
|---|---|
| `patches/homelab-k8s-c01/machine-network-direct.yaml.j2` | c01 10G NIC config + loopback IP + static routes |
| `patches/homelab-k8s-c02/machine-network-direct.yaml.j2` | c02 10G NIC config + loopback IP + static routes |
| `patches/homelab-k8s-c03/machine-network-direct.yaml.j2` | c03 10G NIC config + loopback IP + static routes |
| `patches/global/machine-kubelet.yaml.j2` | kubelet `validSubnets: ["10.1.1.0/29"]` — sets node InternalIP to loopback |
| `patches/controller/cluster.yaml.j2` | etcd `advertisedSubnets: ["10.1.1.0/29"]` — etcd peers use internal IPs |

These are picked up automatically by `task configure` — no changes to `cluster.yaml`, `nodes.yaml`, or any Kubernetes manifests are needed.

## Installation

### New cluster (no special steps needed)

The patches are applied as part of the normal bootstrap. Run `task configure` as usual, then proceed:

```sh
task configure
task bootstrap:talos
task bootstrap:apps
```

Nodes will register in Kubernetes with `InternalIP` set to `10.1.1.x` from the start.

### Existing running cluster (breaking change)

Changing `kubelet.nodeIP.validSubnets` changes each node's Kubernetes `InternalIP`. The old node object (registered under `192.168.50.x`) must be removed and re-registered. Do this one node at a time to avoid losing quorum.

For each node (repeat for c01, c02, c03):

```sh
# 1. Drain the node
kubectl drain homelab-k8s-c01 --ignore-daemonsets --delete-emptydir-data

# 2. Apply the new Talos config (regenerate first if not done yet)
task configure
task talos:apply-node IP=192.168.50.221

# 3. Wait for the node to reboot and come back up
talosctl -n 192.168.50.221 health

# 4. Delete the old Kubernetes node object so it re-registers with the new IP
kubectl delete node homelab-k8s-c01

# 5. Wait for the node to re-register (kubelet will recreate it with InternalIP 10.1.1.1)
kubectl get nodes -w

# 6. Uncordon once registered
kubectl uncordon homelab-k8s-c01
```

etcd membership is managed by Talos and updates automatically when the config is applied — no manual etcd peer reconfiguration is needed.

## Verification

```sh
# --- Talos-level checks (run from management IPs) ---

# 10G interfaces are up with correct addresses
talosctl get addresses -n 192.168.50.221 | grep "10\.1\."

# MTU is 9000 on the 10G NICs
talosctl get links -n 192.168.50.221 | grep -A5 "cc:7[cd]"

# Loopback has the internal IP
talosctl get addresses -n 192.168.50.221 | grep "10\.1\.1\.1"

# Static routes to peer loopback IPs are present
talosctl get routes -n 192.168.50.221 | grep "10\.1\.1\."

# Ping peers over the internal network
talosctl -n 192.168.50.221 -- ping -c3 10.1.1.2   # c01 → c02
talosctl -n 192.168.50.221 -- ping -c3 10.1.1.3   # c01 → c03


# --- Kubernetes-level checks ---

# Node InternalIPs should be 10.1.1.x
kubectl get nodes -o wide

# etcd peers should advertise 10.1.1.x URLs
talosctl -n 192.168.50.221 etcd members


# --- Cilium pod routing check ---

# Cilium's route table should show pod CIDRs via 10.1.1.x next-hops
kubectl -n kube-system exec ds/cilium -- \
  cilium bpf ipcache list | grep -E "10\.42\."
# Expect entries like: 10.42.1.0/24 → identity ... tunnel 10.1.1.2 (for pods on c02)

# Or check kernel routes directly on a node
talosctl -n 192.168.50.221 -- ip route show | grep "10\.42\."
# Expect: 10.42.1.0/24 via 10.1.1.2 dev <10G-iface>
```
