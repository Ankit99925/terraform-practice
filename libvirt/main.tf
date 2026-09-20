terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}
resource "libvirt_pool" "default" {
  name = "tfpool"
  type = "dir"
  target = {
    path = "/var/lib/libvirt/tfpool"
    permissions = {
      owner = "64055"
      group = "991"
      mode  = "0711"
    }
  }
}

resource "libvirt_volume" "base" {
  name = "ubuntu-base.qcow2"
  pool = libvirt_pool.default.name

  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
    permissions = {
      owner = "64055"
      group = "991"
      mode  = "0660"
    }
  }
}

resource "libvirt_volume" "vm_disk" {
  name          = "tfvm.qcow2"
  pool          = libvirt_pool.default.name
  capacity      = 10
  capacity_unit = "GiB"

  target = {
    format = {
      type = "qcow2"
    }
    permissions = {
      owner = "64055"
      group = "991"
      mode  = "0660"
    }
  }

  backing_store = {
    path   = libvirt_volume.base.path
    format = { type = "qcow2" }
  }
}

resource "libvirt_domain" "vm" {
  name        = "tfvm"
  type        = "kvm"
  memory_unit = "GiB"
  memory      = 1
  vcpu        = 1

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc-i440fx-resolute"
  }

  devices = {
    disks = [
      {
        device = "disk"
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          file = {
            file = libvirt_volume.vm_disk.path
          }
        }
        backing_store = {
          format = { type = "qcow2" }
          source = {
            file = {
              file = libvirt_volume.base.path
            }
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
      } },
      {
        device = "cdrom"
        source = {
          file = {
            file = libvirt_cloudinit_disk.init.path
          }
        }
        target = { dev = "sda", bus = "sata" }
      }
    ]

    interfaces = [
      {
        source = {
          network = {
            network = "default"
          }
        }
        model = { type = "virtio" }
      }
    ]
    consoles = [
      {
        target = {
          type = "serial"
          port = 0
        }
      }
    ]
  }
}

resource "libvirt_cloudinit_disk" "init" {
  name = "tfvm-init.iso"

  meta_data = yamlencode({
    instance-id    = "tfvm"
    local-hostname = "tfvm"
  })

  user_data = <<-EOT
    #cloud-config
    users:
      - name: ${var.vm_user}
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${trimspace(file(pathexpand(var.ssh_key_path)))}
  EOT
}

variable "vm_user" {
  description = "Username created on the VM by cloud-init"
  type        = string
  default     = "ubuntu"
}

variable "ssh_key_path" {
  description = "Public key to install for that user"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
