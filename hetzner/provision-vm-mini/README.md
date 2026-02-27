# jambonz Mini (Single VM) on Hetzner Cloud

This Terraform configuration deploys jambonz as a single all-in-one VM on Hetzner Cloud.

## Architecture

```
              Internet
                  │
                  ▼
           ┌─────────────┐
           │   Mini VM   │
           │             │
           │  - SBC      │
           │  - FS       │
           │  - Web/API  │
           │  - MySQL    │
           │  - Redis    │
           │  - Homer    │
           │  - Grafana  │
           └─────────────┘
```

## Components

All components run on a single VM:

| Component | Description |
|-----------|-------------|
| drachtio | SIP server |
| rtpengine | RTP media proxy |
| Feature Server | Call processing (freeswitch + jambonz apps) |
| Web Portal | jambonz admin UI |
| API Server | REST API |
| MySQL | Local database |
| Redis | Local cache/pub-sub |
| Homer | SIP capture and analysis |
| Grafana | Metrics dashboard |

## Prerequisites

1. **Hetzner Cloud account** with a project created
2. **Terraform** >= 1.0
3. **Packer-built snapshot** for the jambonz mini image

### Authentication

Provide your Hetzner Cloud API token using one of these methods:

**Option A: Environment variable (recommended)**
```bash
export HCLOUD_TOKEN="your-api-token"
```

**Option B: In terraform.tfvars**
```hcl
hcloud_token = "your-api-token"
```

Generate a token in the Hetzner Cloud Console: Project → Security → API Tokens → Generate API Token (Read & Write).

### Build Snapshot

Build the jambonz mini snapshot using Packer before deploying:
```bash
# See the packer/ directory for build instructions
# Note the snapshot ID from the Packer output
```

## Deployment

### 1. Copy and edit variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

At minimum, you must set:
- `name_prefix` - Resource naming prefix
- `location` - Hetzner Cloud location
- `url_portal` - Your domain name
- `ssh_public_key` - Your SSH public key (or `ssh_key_name` for existing key)
- `image_mini` - Packer snapshot ID

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan and apply

```bash
terraform plan
terraform apply
```

### 4. Configure DNS

After deployment, create DNS A records pointing to the public IP:

```bash
terraform output public_ip
```

Create these DNS records:
- `<url_portal>` → public IP
- `api.<url_portal>` → public IP
- `grafana.<url_portal>` → public IP
- `homer.<url_portal>` → public IP
- `sip.<url_portal>` → public IP

Or use the automated post-install script:
```bash
python ../../post_install.py --email admin@example.com
```

## Configuration

### Monitoring & Observability

Both PCAP capture and OpenTelemetry tracing are **enabled by default**. To disable either, add to `terraform.tfvars`:

```hcl
# Disable SIP/RTP packet capture (Homer HEP)
enable_pcaps = "false"

# Disable OpenTelemetry tracing (Cassandra + Jaeger)
enable_otel = "false"
```

- **`enable_pcaps`** controls HEP flags on drachtio and rtpengine, and the heplify-server service
- **`enable_otel`** controls Cassandra and Jaeger services, and the `JAMBONES_OTEL_ENABLED` flag in feature-server config

### Server Type

Default: `cx33` (4 vCPU, 8 GB RAM, 80 GB disk). Not all server types are available in all locations. To list available types:
```bash
hcloud server-type list
```

## APIBan Configuration (Optional)

[APIBan](https://www.apiban.org/) provides a community-maintained blocklist of known VoIP fraud and spam IP addresses.

### Option 1: Single API Key (Simple)

Best for: Single deployments or when one key per email is sufficient.

1. Get a free API key at https://apiban.org/getkey.html
2. Add to `terraform.tfvars`:
   ```hcl
   apiban_key = "your-api-key-here"
   ```

### Option 2: Client Credentials (Multiple Keys)

Best for: Multiple deployments needing unique keys per instance.

1. Contact APIBan to obtain client credentials
2. Add to `terraform.tfvars`:
   ```hcl
   apiban_client_id     = "your-client-id"
   apiban_client_secret = "your-client-secret"
   ```

Each instance will automatically provision its own unique API key at boot time.

**Note:** If both are provided, client credentials take precedence.

## Outputs

| Output | Description |
|--------|-------------|
| `public_ip` | Public IP address of the VM |
| `portal_url` | jambonz portal URL |
| `portal_password` | Initial admin password (instance ID) |
| `ssh_connection` | SSH command to connect |
| `dns_records_required` | DNS A records to create |

## SSH Access

```bash
ssh jambonz@<public-ip>
```

## Troubleshooting

### Check cloud-init logs

```bash
sudo cat /var/log/cloud-init-output.log
```

### Check jambonz app logs

```bash
sudo -u jambonz pm2 logs
```

### Check service status

```bash
sudo systemctl status drachtio
sudo systemctl status rtpengine
sudo -u jambonz pm2 list
```

## Cleanup

```bash
terraform destroy
```