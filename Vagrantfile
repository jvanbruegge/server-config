# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|

  config.vm.define "vps" do |vps|
    vps.vm.box = "generic/ubuntu2204"

    vps.vm.provider "virtualbox" do |v|
      v.memory = 4096
      v.cpus = 2
    end

    vps.vm.network "private_network", ip: "192.168.56.10"
  end

  config.vm.define "caladan" do |c|
    c.vm.box = "generic/ubuntu2204"

    c.vm.provider "virtualbox" do |v|
      v.memory = 4096
      v.cpus = 2
    end

    c.vm.network "private_network", ip: "192.168.56.11"
    config.vm.network "forwarded_port", guest: 3001, host: 3001, auto_correct: true
    config.vm.network "forwarded_port", guest: 3000, host: 3000, auto_correct: true
  end

end
