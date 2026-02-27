# =============================================================================
# Locals
# =============================================================================

locals {
  # Generate database password if not provided
  db_password = var.mysql_password != "" ? var.mysql_password : random_password.db_password[0].result

  # SSH key ID for server creation
  ssh_key_id = var.ssh_public_key != "" ? hcloud_ssh_key.jambonz[0].id : data.hcloud_ssh_key.existing[0].id

  # SSH public key content for cloud-init
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : data.hcloud_ssh_key.existing[0].public_key

  # Static private IPs — use high offsets to avoid DHCP collisions.
  # Hetzner DHCP assigns from the bottom of the range, so we place
  # static IPs near the top of the /16 (172.20.0.200, 172.20.0.201).
  monitoring_private_ip = cidrhost(var.vpc_cidr, 200)
  db_private_ip         = cidrhost(var.vpc_cidr, 201)

  # Map Hetzner location to network zone
  network_zone = lookup({
    "nbg1" = "eu-central"
    "fsn1" = "eu-central"
    "hel1" = "eu-central"
    "ash"  = "us-east"
    "hil"  = "us-west"
    "sgp1" = "ap-southeast"
  }, var.location, "eu-central")
}

# =============================================================================
# Random Secrets Generation
# =============================================================================

# JWT/Encryption secret (32 characters, alphanumeric only)
resource "random_password" "encryption_secret" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# Database password (16 characters)
resource "random_password" "db_password" {
  count            = var.mysql_password == "" ? 1 : 0
  length           = 16
  special          = true
  override_special = "_"
  upper            = true
  lower            = true
  numeric          = true
}

# =============================================================================
# SSH Key
# =============================================================================

resource "hcloud_ssh_key" "jambonz" {
  count      = var.ssh_public_key != "" ? 1 : 0
  name       = "${var.name_prefix}-jambonz-key"
  public_key = var.ssh_public_key
}

data "hcloud_ssh_key" "existing" {
  count = var.ssh_public_key == "" ? 1 : 0
  name  = var.ssh_key_name
}

# =============================================================================
# Private Network
# =============================================================================

resource "hcloud_network" "jambonz" {
  name     = "${var.name_prefix}-network"
  ip_range = var.vpc_cidr
}

resource "hcloud_network_subnet" "jambonz" {
  network_id   = hcloud_network.jambonz.id
  type         = "cloud"
  network_zone = local.network_zone
  ip_range     = var.vpc_cidr
}

# =============================================================================
# Firewalls
# Hetzner firewalls apply to public interfaces only.
# Private network traffic between servers flows freely.
# =============================================================================

# SSH-only firewall (for DB, feature server, recording — private-only roles)
resource "hcloud_firewall" "ssh_only" {
  name = "${var.name_prefix}-fw-ssh-only"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.allowed_ssh_cidr]
    description = "SSH access"
  }
}

# Web firewall (portal, API, public-apps — HTTP/HTTPS only)
resource "hcloud_firewall" "web" {
  name = "${var.name_prefix}-fw-web"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = [var.allowed_http_cidr]
    description = "HTTP"
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = [var.allowed_http_cidr]
    description = "HTTPS"
  }
}

# Monitoring firewall (SSH only — Grafana/Homer proxied via web's nginx)
resource "hcloud_firewall" "monitoring" {
  name = "${var.name_prefix}-fw-monitoring"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.allowed_ssh_cidr]
    description = "SSH access"
  }
}

# SIP firewall
resource "hcloud_firewall" "sip" {
  name = "${var.name_prefix}-fw-sip"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "5060"
    source_ips = [var.allowed_sip_cidr]
    description = "SIP TCP"
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "5060"
    source_ips = [var.allowed_sip_cidr]
    description = "SIP UDP"
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "5061"
    source_ips = [var.allowed_sip_cidr]
    description = "SIP TLS"
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "8443"
    source_ips = [var.allowed_sip_cidr]
    description = "SIP WebSocket Secure"
  }
}

# RTP firewall
resource "hcloud_firewall" "rtp" {
  name = "${var.name_prefix}-fw-rtp"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "40000-60000"
    source_ips = [var.allowed_sip_cidr]
    description = "RTP media"
  }
}
