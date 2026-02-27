terraform {
  required_version = ">= 1.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "hcloud" {
  # Authentication: provide token via variable or HCLOUD_TOKEN environment variable
  token = var.hcloud_token != "" ? var.hcloud_token : null
}
