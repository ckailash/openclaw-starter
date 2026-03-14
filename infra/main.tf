terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/agent_ed25519.pub"
}

provider "hcloud" {
  token = var.hcloud_token
}

# --- SSH Key ---

resource "hcloud_ssh_key" "agent" {
  name       = "agent"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# --- Firewall ---

resource "hcloud_firewall" "agent" {
  name = "agent"

  # SSH
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Tailscale UDP (WireGuard)
  rule {
    direction = "in"
    protocol  = "udp"
    port      = "41641"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

# --- Server ---

resource "hcloud_server" "agent" {
  name        = "agent"
  server_type = "cax31"
  image       = "ubuntu-24.04"
  location    = "nbg1"

  ssh_keys = [hcloud_ssh_key.agent.id]

  firewall_ids = [hcloud_firewall.agent.id]

  user_data = file("${path.module}/cloud-init.yml")

  labels = {
    project = "openclaw-agent"
    role    = "brain"
  }
}

# --- Outputs ---

output "server_ip" {
  value       = hcloud_server.agent.ipv4_address
  description = "Server public IPv4 address"
}

output "server_ipv6" {
  value       = hcloud_server.agent.ipv6_address
  description = "Server public IPv6 address"
}

output "server_status" {
  value       = hcloud_server.agent.status
  description = "Server status"
}

output "ssh_command" {
  value       = "ssh -i ~/.ssh/agent_ed25519 root@${hcloud_server.agent.ipv4_address}"
  description = "SSH command to connect"
}
