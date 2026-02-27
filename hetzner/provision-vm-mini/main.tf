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
  length           = 16
  special          = true
  override_special = "_"
  upper            = true
  lower            = true
  numeric          = true
}

# =============================================================================
# Locals
# =============================================================================

locals {
  # SSH key ID for server creation
  ssh_key_id = var.ssh_public_key != "" ? hcloud_ssh_key.jambonz[0].id : data.hcloud_ssh_key.existing[0].id

  # SSH public key content for cloud-init
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : data.hcloud_ssh_key.existing[0].public_key
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
# Firewall
# Single firewall for the all-in-one mini server.
# =============================================================================

resource "hcloud_firewall" "mini" {
  name = "${var.name_prefix}-fw-mini"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = [var.allowed_http_cidr]
    description = "HTTP"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = [var.allowed_http_cidr]
    description = "HTTPS"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "5060"
    source_ips  = [var.allowed_sip_cidr]
    description = "SIP TCP"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "5060"
    source_ips  = [var.allowed_sip_cidr]
    description = "SIP UDP"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "5061"
    source_ips  = [var.allowed_sip_cidr]
    description = "SIP TLS"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "8443"
    source_ips  = [var.allowed_sip_cidr]
    description = "SIP WebSocket Secure"
  }

  rule {
    direction   = "in"
    protocol    = "udp"
    port        = "40000-60000"
    source_ips  = [var.allowed_sip_cidr]
    description = "RTP media"
  }
}
