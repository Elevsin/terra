# =============================================================================
# PMM Server в контейнере
# =============================================================================

resource "docker_image" "pmm_server" {
  depends_on = [ssh_resource.docker]
  name         = "percona/pmm-server:${var.pmm_version}"
  keep_locally = true # не удалять образ при destroy — экономит ~800 МБ загрузки
}

resource "docker_volume" "pmm_data" {
  depends_on = [ssh_resource.docker]
  name       = "pmm-data"
}

resource "docker_container" "pmm_server" {
  name    = "pmm-server"
  image   = docker_image.pmm_server.image_id
  restart = "always"
  wait         = true
  wait_timeout = 300

  ports {
    internal = 8443
    external = 443
  }

  volumes {
    volume_name    = docker_volume.pmm_data.name
    container_path = "/srv"
  }

  env = ["GF_SECURITY_ADMIN_PASSWORD=${var.pmm_admin_password}"]
}

# =============================================================================
# Сервисный токен для PMM Client
# =============================================================================

provider "grafana" {
  url                  = "https://${var.stand_ip}/graph/" 
  auth                 = "admin:${var.pmm_admin_password}" # basic auth
  insecure_skip_verify = true                              # самоподписанный сертификат PMM
}

resource "grafana_service_account" "pmm_agent" {
  depends_on = [docker_container.pmm_server]
  name       = "pmm-client-agent"
  role       = "Admin" # требуется агенту для регистрации сервисов
}

resource "grafana_service_account_token" "pmm_agent" {
  name               = "pmm-client-token"
  service_account_id = grafana_service_account.pmm_agent.id
  # Значение .key Grafana отдаёт только при создании; хранится в state
}

# =============================================================================
# PMM Client — один агент на узел, базы регистрируются отдельными сервисами
# =============================================================================

resource "ssh_resource" "pmm_client" {
  depends_on = [ssh_resource.docker, grafana_service_account_token.pmm_agent]

  host        = local.ssh.host
  port        = local.ssh.port
  user        = local.ssh.user
  private_key = local.ssh.private_key
  timeout     = "10m"

  commands = [
    "sudo percona-release enable pmm3-client release",
    "sudo apt-get update -y",
    "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y pmm-client=${var.pmm_client_version}",
    # В PMM 3 агент авторизуется сервисным токеном; логин буквально service_token
    "sudo pmm-admin config --server-insecure-tls --server-url=https://service_token:${grafana_service_account_token.pmm_agent.key}@${var.stand_ip}:443",
    "sudo pmm-admin status",
  ]
}

# =============================================================================
# Регистрация сервисов в PMM
# =============================================================================

resource "ssh_resource" "pmm_add_postgres" {
  count = local.pg_count
  depends_on = [ssh_resource.pmm_client, postgresql_role.pmm, postgresql_extension.pg_stat_statements]

  host        = local.ssh.host
  port        = local.ssh.port
  user        = local.ssh.user
  private_key = local.ssh.private_key
  timeout     = "5m"

  commands = [
    "sudo pmm-admin remove postgresql pg-local || true",
    "sudo pmm-admin add postgresql --username=pmm --password='${var.pmm_db_password}' --host=127.0.0.1 --port=5432 --service-name=pg-local",
    "sudo pmm-admin list",
  ]
}

resource "ssh_resource" "pmm_add_mysql" {
  count = local.mysql_count
  depends_on = [ssh_resource.pmm_client, mysql_grant.pmm, ssh_resource.pmm_add_postgres]

  host        = local.ssh.host
  port        = local.ssh.port
  user        = local.ssh.user
  private_key = local.ssh.private_key
  timeout     = "5m"

  commands = [
    "sudo pmm-admin remove mysql mysql-local || true",
    "sudo pmm-admin add mysql --username=pmm --password='${var.pmm_db_password}' --host=127.0.0.1 --port=3306 --service-name=mysql-local --query-source=perfschema",
    "sudo pmm-admin list",
  ]
}
