# =============================================================================
# Docker Engine + демон на TCP
# =============================================================================

resource "ssh_resource" "docker" {
  depends_on = [ssh_resource.postgres, ssh_resource.mysql, ssh_resource.percona_repo]

  host        = local.ssh.host
  port        = local.ssh.port
  user        = local.ssh.user
  private_key = local.ssh.private_key
  timeout     = "5m"

  commands = [
    "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh",
    "sudo sh /tmp/get-docker.sh",
    "sudo usermod -aG docker vagrant",
    "sudo mkdir -p /etc/systemd/system/docker.service.d",
    "printf '[Service]\\nExecStart=\\nExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:${var.docker_tcp_port}\\n' | sudo tee /etc/systemd/system/docker.service.d/override.conf",
    "sudo systemctl daemon-reload",
    "sudo systemctl restart docker",
    "sudo docker --version",
  ]
}

provider "docker" {
  host = "tcp://${var.stand_ip}:${var.docker_tcp_port}"
}
