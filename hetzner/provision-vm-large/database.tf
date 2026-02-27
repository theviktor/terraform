# =============================================================================
# Database Server (MySQL on dedicated VM)
# =============================================================================

resource "hcloud_server" "db" {
  name        = "${var.name_prefix}-db"
  server_type = var.server_type_db
  location    = var.location
  image       = var.image_db
  ssh_keys    = [local.ssh_key_id]
  firewall_ids = [hcloud_firewall.ssh_only.id]

  network {
    network_id = hcloud_network.jambonz.id
    ip         = local.db_private_ip
  }

  labels = {
    role    = "db"
    cluster = var.name_prefix
  }

  user_data = templatefile("${path.module}/cloud-init-db.yaml", {
    mysql_user     = var.mysql_username
    mysql_password = local.db_password
    mysql_database = "jambones"
    ssh_public_key = local.ssh_public_key
  })

  depends_on = [hcloud_network_subnet.jambonz]
}
