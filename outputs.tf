# =============================================================================
# Outputs
# =============================================================================

output "vm_ssh" {
  description = "Строка подключения к ВМ (через проброшенный порт NAT)"
  value       = "${local.ssh.user}@${local.ssh.host}:${local.ssh.port}"
}

output "postgres_check" {
  description = "Версия работающего сервера PostgreSQL"
  value       = one(ssh_resource.postgres[*].result)
}

output "mysql_check" {
  description = "Версия работающего сервера Percona"
  value       = one(ssh_resource.mysql[*].result)
  sensitive   = true
}

output "docker_check" {
  description = "Версия Docker Engine"
  value       = ssh_resource.docker.result
}

output "pmm_url" {
  description = "Адрес интерфейса PMM. Логин admin, пароль из pmm_admin_password"
  value       = "https://${var.stand_ip}"
}

output "pmm_client_check" {
  description = "Вывод pmm-admin status: подключение агента к серверу"
  value       = ssh_resource.pmm_client.result
  sensitive   = true
}

output "pg_access_check" {
  description = "Фактическое значение listen_addresses"
  value       = one(ssh_resource.pg_access[*].result)
}

output "mysql_access_check" {
  description = "Фактическое значение bind_address"
  value       = one(ssh_resource.mysql_access[*].result)
  sensitive   = true
}

output "pmm_add_postgres_check" {
  description = "Список сервисов PMM после регистрации PostgreSQL"
  value       = one(ssh_resource.pmm_add_postgres[*].result)
  sensitive   = true
}

output "pmm_add_mysql_check" {
  description = "Список сервисов PMM после регистрации MySQL"
  value       = one(ssh_resource.pmm_add_mysql[*].result)
  sensitive   = true
}
