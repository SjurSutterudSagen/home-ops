# Local-Only Kubernetes Cluster Setup

This guide shows you how to set up the cluster template for **local network access only** without Cloudflare external access.

## ✅ Benefits of Local-Only Setup

- **Simpler configuration** - No Cloudflare account or domain needed
- **Faster setup** - Skip DNS configuration and tunnel creation
- **Enhanced security** - No external internet exposure
- **Cost-free** - No external service dependencies

## 📋 What You'll Get

- Full Kubernetes cluster with dual-network support
- Internal DNS resolution via k8s_gateway
- Self-signed TLS certificates
- Local network access to applications
- All core features (Flux, Cilium, cert-manager, etc.)

## 🚀 Quick Setup Steps

### 1. **Hardware Setup**
Set up your 3 mini PCs with:
- **External network**: Standard ethernet for management and local access
- **Cluster network**: High-speed direct connections between nodes

### 2. **Clone and Configure**
```bash
# Clone the template
git clone https://github.com/onedr0p/cluster-template.git my-cluster
cd my-cluster

# Install tools
mise trust
mise install

# Generate config files
task init
```

### 3. **Configure cluster.yaml**
```yaml
---
# External network (your home network)
node_cidr: "192.168.1.0/24"

# Cluster network (high-speed connections)
cluster_cidr: "10.0.0.0/24"

# Gateways
node_default_gateway: "192.168.1.1"       # Your router
cluster_default_gateway: "10.0.0.1"       # Optional

# Kubernetes API on cluster network
cluster_api_addr: "10.0.0.100"

# Load balancer IPs on cluster network
cluster_dns_gateway_addr: "10.0.0.102"
cluster_gateway_addr: "10.0.0.101"

# Local domain (any domain you want)
local_domain: "cluster.local"

# Repository settings
repository_name: "your-username/my-cluster"
```

### 4. **Configure nodes.yaml**
```yaml
---
nodes:
  - name: "node-1"
    address: "192.168.1.10"              # External IP
    cluster_address: "10.0.0.10"         # Cluster IP
    controller: true
    disk: "/dev/sda"
    mac_addr: "aa:bb:cc:dd:ee:01"         # External NIC MAC
    cluster_mac_addr: "aa:bb:cc:dd:ee:11" # Cluster NIC MAC
    schematic_id: "your-schematic-id"

  - name: "node-2"
    address: "192.168.1.11"
    cluster_address: "10.0.0.11"
    controller: true
    disk: "/dev/sda"
    mac_addr: "aa:bb:cc:dd:ee:02"
    cluster_mac_addr: "aa:bb:cc:dd:ee:12"
    schematic_id: "your-schematic-id"

  - name: "node-3"
    address: "192.168.1.12"
    cluster_address: "10.0.0.12"
    controller: true
    disk: "/dev/sda"
    mac_addr: "aa:bb:cc:dd:ee:03"
    cluster_mac_addr: "aa:bb:cc:dd:ee:13"
    schematic_id: "your-schematic-id"
```

### 5. **Generate and Deploy**
```bash
# Generate configurations
task configure

# Commit to git
git add -A
git commit -m "initial cluster configuration"
git push

# Bootstrap Talos
task bootstrap:talos

# Bootstrap applications
task bootstrap:apps
```

## 🌐 Accessing Your Applications

### **DNS Setup**
Configure your router or local DNS server to forward `*.home.local` queries to your cluster DNS gateway:

**Router/DNS Configuration:**
- Domain: `home.local`
- DNS Server: `10.0.0.102` (cluster_dns_gateway_addr)

### **Example Application Access**
- `echo.home.local` → Example application
- `grafana.home.local` → Monitoring dashboard
- `argocd.home.local` → ArgoCD (if installed)

### **Certificate Trust**
Since we're using self-signed certificates, you'll need to:
1. Accept browser security warnings, OR
2. Add the self-signed CA to your trust store

## 🔧 Adding Applications

Applications use the `internal` gateway for local access:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
spec:
  hostnames: ["my-app.home.local"]
  parentRefs:
    - name: internal          # Use internal gateway
      namespace: kube-system
  rules:
    - backendRefs:
        - name: my-app-service
          port: 80
```

## 🔄 Adding Cloudflare Later

If you want to add external Cloudflare access later:

1. **Add to cluster.yaml:**
```yaml
cloudflare_domain: "your-domain.com"
cloudflare_token: "your-cloudflare-token"
cloudflare_gateway_addr: "192.168.1.200"
```

2. **Re-run configuration:**
```bash
task configure
git add -A && git commit -m "enable cloudflare" && git push
```

The template will automatically enable Cloudflare components and external access.

## 🛠️ Troubleshooting

### **DNS Not Working**
- Check router DNS forwarding configuration
- Verify cluster DNS gateway is running: `kubectl get svc -n network k8s-gateway`
- Test direct DNS query: `dig @10.0.0.102 echo.home.local`

### **Applications Not Accessible**
- Check gateway status: `kubectl get gateway -n kube-system internal`
- Verify HTTPRoute: `kubectl get httproute -A`
- Check internal gateway IP: Should be accessible at cluster_gateway_addr

### **Certificate Issues**
- Accept browser warnings for self-signed certs
- Check certificate status: `kubectl get certificates -n kube-system`
- Trust the self-signed CA in your browser/system

## 📈 What's Next

With your local cluster running, you can:
- Add monitoring (Prometheus/Grafana)
- Install storage solutions (Rook-Ceph, Longhorn)
- Set up CI/CD pipelines
- Add development tools
- Experiment with service mesh
- Test disaster recovery procedures

Your local cluster provides all the capabilities of a production cluster without external dependencies!