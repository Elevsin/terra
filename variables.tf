variable "machine_name" {
  description = "Имя машины из Vagrantfile. Нужно для поиска её ssh_config по имени, а не по индексу"
  type        = string
  default     = "default"
}

variable "databases" {
  description = "Какие СУБД ставить."
  type        = list(string)
  default     = ["postgres", "mysql"]

  validation {
    condition     = alltrue([for d in var.databases : contains(["postgres", "mysql"], d)])
    error_message = "Допустимые значения: postgres, mysql."
  }
}

variable "postgres_version" {
  description = "Мажорная версия PostgreSQL."
  type        = string
  default     = "17"
}

variable "percona_repo" {
  description = "Алиас репозитория percona-release для ветки 8.4 LTS"
  type        = string
  default     = "ps-84-lts"
}

variable "percona_version" {
  description = "Версия percona-server-server."
  type        = string
  default     = "8.4.8-8-1.trixie"
}

variable "pmm_version" {
  description = "Версия PMM Server."
  type        = string
  default     = "3.9.0"
}

variable "pmm_client_version" {
  description = "Версия пакета pmm-client."
  type        = string
  default     = "3.9.0-1.trixie"

  validation {
    condition     = split("-", var.pmm_client_version)[0] == var.pmm_version
    error_message = "Версии PMM Server и PMM Client должны совпадать: клиент новее сервера не поддерживается."
  }
}

variable "stand_ip" {
  description = "Статический host-only адрес ВМ из Vagrantfile."
  type        = string
  default     = "192.168.56.50"
}

variable "docker_tcp_port" {
  description = "Порт демона Docker."
  type        = number
  default     = 2375
}

# -----------------------------------------------------------------------------
# Пароли
# -----------------------------------------------------------------------------

variable "mysql_root_password" {
  description = "Пароль root@localhost в Percona Server. Задаётся через debconf при установке"
  type        = string
  sensitive   = true
  default     = "mysql"
}

variable "pmm_admin_password" {
  description = "Пароль admin в PMM Server. Используется и для входа в UI, и для доступа к Grafana API"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "postgres_password" {
  description = "Пароль суперпользователя postgres. Нужен, т.к. в Debian он ходит через peer-аутентификацию и пароля не имеет, а провайдер идёт по TCP"
  type        = string
  sensitive   = true
  default     = "postgres"
}

variable "mysql_tf_password" {
  description = "Пароль учётки tfadmin, под которой подключается провайдер mysql. Отдельная, т.к. root доступен только с localhost"
  type        = string
  sensitive   = true
  default     = "TfAdmin"
}

variable "pmm_db_password" {
  description = "Пароль пользователя pmm в обеих СУБД. Под ним агент собирает метрики"
  type        = string
  sensitive   = true
  default     = "PmmDb"
}

# =============================================================================
# Производные значения
#
# Условия count вынесены сюда: выражение contains(...) повторялось по пять раз
# на каждую СУБД. Подсеть выводится из stand_ip, чтобы адрес стенда оставался
# единственным источником правды
# =============================================================================

locals {
  pg_count    = contains(var.databases, "postgres") ? 1 : 0
  mysql_count = contains(var.databases, "mysql") ? 1 : 0

  # 192.168.56.50 -> 192.168.56
  stand_prefix = join(".", slice(split(".", var.stand_ip), 0, 3))
  # Формат pg_hba.conf
  stand_cidr = "${local.stand_prefix}.0/24"
  # Формат host в MySQL: маска % вместо префикса длины
  stand_host_mask = "${local.stand_prefix}.%"

  pg_conf_dir = "/etc/postgresql/${var.postgres_version}/main"
}
