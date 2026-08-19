# =============================================================================
# PostgreSQL
# =============================================================================

resource "ssh_resource" "postgres" {
  count = local.pg_count

  host        = local.ssh.host
  port        = local.ssh.port
  user        = local.ssh.user
  private_key = local.ssh.private_key
  timeout     = "5m"

  commands = [
    "sudo apt-get update -y",
    "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-${var.postgres_version}",
    "sudo -u postgres psql -tAc 'SHOW server_version'",
  ]
}

# =============================================================================
# Репозиторий Percona
# =============================================================================

resource "ssh_resource" "percona_repo" {
  depends_on = [ssh_resource.postgres]

  host        = local.ssh.host
  port        = local.ssh.port
  user        = local.ssh.user
  private_key = local.ssh.private_key
  timeout     = "5m"

  commands = [
    "sudo apt-get update -y",
    "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget gnupg lsb-release ca-certificates",
    "wget -q -O /tmp/percona-release.deb https://repo.percona.com/apt/percona-release_latest.generic_all.deb",
    "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/percona-release.deb",
  ]
}

# =============================================================================
# Percona Server 8.4
# =============================================================================

resource "ssh_resource" "mysql" {
  count = local.mysql_count
  depends_on = [ssh_resource.percona_repo]

  host        = local.ssh.host
  port        = local.ssh.port
  user        = local.ssh.user
  private_key = local.ssh.private_key
  timeout     = "10m"

  commands = [
    "sudo percona-release setup -y ${var.percona_repo}",
    "sudo apt-get update -y",
    "echo 'percona-server-server percona-server-server/root-pass password ${var.mysql_root_password}' | sudo debconf-set-selections",
    "echo 'percona-server-server percona-server-server/re-root-pass password ${var.mysql_root_password}' | sudo debconf-set-selections",
    "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y percona-server-server=${var.percona_version} percona-server-client=${var.percona_version} percona-server-common=${var.percona_version}",
    "mysql -uroot -p'${var.mysql_root_password}' -e 'SELECT VERSION()'",
  ]
}

# =============================================================================
# Доступ к PostgreSQL из host-only сети
#
# Конфиги СУБД
# =============================================================================

resource "ssh_resource" "pg_access" {
  count      = local.pg_count
  depends_on = [ssh_resource.postgres]

  host        = local.ssh.host
  port        = local.ssh.port
  user        = local.ssh.user
  private_key = local.ssh.private_key
  timeout     = "5m"

  commands = [
    # Отдельный файл в conf.d вместо правки postgresql.conf — идемпотентно
    "echo \"listen_addresses = '*'\" | sudo tee ${local.pg_conf_dir}/conf.d/listen.conf",
    # Библиотека для Query Analytics.
    "echo \"shared_preload_libraries = 'pg_stat_statements'\" | sudo tee ${local.pg_conf_dir}/conf.d/pgss.conf",
    # grep перед дописыванием: иначе при повторном apply строка продублируется
    "grep -q '${local.stand_cidr}' ${local.pg_conf_dir}/pg_hba.conf || echo 'host all all ${local.stand_cidr} scram-sha-256' | sudo tee -a ${local.pg_conf_dir}/pg_hba.conf",
    "sudo -u postgres psql -c \"ALTER USER postgres PASSWORD '${var.postgres_password}'\"",
    "sudo systemctl restart postgresql",
    "sudo -u postgres psql -tAc 'SHOW listen_addresses'",
  ]
}

# =============================================================================
# Доступ к MySQL из host-only сети
# =============================================================================

resource "ssh_resource" "mysql_access" {
  count      = local.mysql_count
  depends_on = [ssh_resource.mysql]

  host        = local.ssh.host
  port        = local.ssh.port
  user        = local.ssh.user
  private_key = local.ssh.private_key
  timeout     = "5m"

  file {
    content     = "[client]\nuser=root\npassword=\"${var.mysql_root_password}\"\n"
    destination = "/home/vagrant/.my.cnf"
    permissions = "0600"
  }

  commands = [
    "printf '[mysqld]\\nbind-address = 0.0.0.0\\n' | sudo tee /etc/mysql/conf.d/bind.cnf",
    "sudo systemctl restart mysql",
    "mysql -e \"CREATE USER IF NOT EXISTS 'tfadmin'@'${local.stand_host_mask}' IDENTIFIED BY '${var.mysql_tf_password}'; GRANT ALL ON *.* TO 'tfadmin'@'${local.stand_host_mask}' WITH GRANT OPTION;\"",
    "mysql -e \"SELECT @@bind_address\"",
  ]
}

# =============================================================================
# Пользователи для мониторинга
# =============================================================================

provider "postgresql" {
  host     = var.stand_ip
  port     = 5432
  database = "postgres"
  username = "postgres"
  password = var.postgres_password
  sslmode  = "disable"
  connect_timeout = 60
}

provider "mysql" {
  endpoint = "${var.stand_ip}:3306"
  username = "tfadmin"
  password = var.mysql_tf_password
}

resource "postgresql_role" "pmm" {
  count      = local.pg_count
  depends_on = [ssh_resource.pg_access]

  name     = "pmm"
  login    = true
  password = var.pmm_db_password
  roles = ["pg_monitor"]
}

# =============================================================================
# pg_stat_statements
# =============================================================================

resource "postgresql_extension" "pg_stat_statements" {
  count      = local.pg_count
  depends_on = [ssh_resource.pg_access]

  name     = "pg_stat_statements"
  database = "postgres"
}

resource "mysql_user" "pmm" {
  count      = local.mysql_count
  depends_on = [ssh_resource.mysql_access]

  user = "pmm"
  host               = "127.0.0.1"
  plaintext_password = var.pmm_db_password
}

resource "mysql_grant" "pmm" {
  count = local.mysql_count

  user     = mysql_user.pmm[0].user
  host     = mysql_user.pmm[0].host
  database = "*"
  table    = "*"
  privileges = ["SELECT", "PROCESS", "REPLICATION CLIENT", "RELOAD", "BACKUP_ADMIN"]
}
