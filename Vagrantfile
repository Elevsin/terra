Vagrant.configure("2") do |config|
  config.vm.box         = "bento/debian-13"
  config.vm.box_version = "202510.26.0"
  config.vm.hostname    = "vg-tf-node-01"

  config.vm.network "private_network", ip: "192.168.56.50"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "tf-node"
    vb.memory = 6144
    vb.cpus   = 2
    vb.gui    = false
  end

  config.vm.provision "shell", inline: <<-SHELL
  apt-get update
 SHELL
end
