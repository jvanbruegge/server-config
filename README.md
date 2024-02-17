# My NixOS server config

## Development setup

Either use an existing server or virtual machine with NixOS or use Vagrant to set up a ubuntu machine and use [nixos-infect](https://github.com/elitak/nixos-infect) to convert it to NixOS. This is done as test run for my VPS.

The `setup_vps.sh` script expects root ssh access to the machine via a ssh key. For the vagrant box set this up with these commands:
```bash
vagrant up
vagrant ssh -c 'sudo tee /root/.ssh/authorized_keys' < ~/.ssh/id_rsa.pub
```
