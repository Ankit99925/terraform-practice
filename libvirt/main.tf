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
  }
}

resource "libvirt_volume" "vm_disk" {
  name = "tfvm.qcow2"
  pool = libvirt_pool.default.name
  capacity = 10
  capacity_unit = "GiB"

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path   = libvirt_volume.base.path
    format = { type = "qcow2" }
  }
}

resource "libvirt_domain" "vm" {
  name   = "tfvm"
  type   = "kvm"
  memory_unit = "GiB"
  memory = 1
  vcpu   = 1

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc-q35-6.2"
  }

  devices = {
    disks = [
      {
        device = "disk"
        source = {
          volume = {
            pool   = libvirt_pool.default.name
            volume = libvirt_volume.vm_disk.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      }
    ]
  }
}


