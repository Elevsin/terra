terraform {
  required_version = ">= 1.9.0"

  required_providers {
    vagrant = {
      source  = "bmatcuk/vagrant"
      version = "4.1.0"
    }
    ssh = {
      source  = "loafoe/ssh"
      version = "2.7.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.5.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "3.25.7"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.26.0"
    }
    mysql = {
      source  = "petoju/mysql"
      version = "3.0.94"
    }
  }
}
