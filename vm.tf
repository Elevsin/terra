# =============================================================================
# Виртуальная машина
# =============================================================================

resource "vagrant_vm" "my_vagrant_vm" {
  name            = "vagrantbox"
  vagrantfile_dir = "."
  get_ports       = true
}

locals {
  ssh = vagrant_vm.my_vagrant_vm.ssh_config[
    index(vagrant_vm.my_vagrant_vm.machine_names, var.machine_name)
  ]
}
