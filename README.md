[Ansible](http://docs.ansible.com/intro_installation.html) playbooks for a vector tile server.

# Testing

Playbooks can be tested using [Vagrant](https://docs.vagrantup.com/v2/installation/index.html).

## Vagrant

Add Ubuntu 14.04 LTS to Vagrant:
```
vagrant box add ubuntu-official-lts https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box
```

From the directory containing ```Vagrantfile```, run
```vagrant up --provision```
or, if the VM is already running, run
```vagrant provision```
