terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

variable "project" { type = string }
variable "region" { default = "us-west1" }
variable "zone" { default = "us-west1-b" }

resource "google_compute_network" "lab" {
  name                    = "lab-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name          = "lab-public"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.lab.id
}

resource "google_compute_subnetwork" "private" {
  name          = "lab-private"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.lab.id
}

variable "ip" {
  type        = string
  description = "Your public IP in CIDR form, e.g. 203.0.113.45/32"
}

resource "google_compute_firewall" "ssh" {
  name    = "lab-allow-ssh"
  network = google_compute_network.lab.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.ip]
  target_tags   = ["ssh-allowed"]
}
variable "vm_user" {
  type        = string
  description = "Username to create on the instance"
  default     = "ubuntu"
}

variable "ssh_key_path" {
  type        = string
  description = "Public key to install"
  default     = "~/.ssh/id_ed25519.pub"
}

resource "google_compute_instance" "public" {
  name         = "lab-public-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["ssh-allowed"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.vm_user}:${trimspace(file(pathexpand(var.ssh_key_path)))}"
  }
}

output "public_ip" {
  value = google_compute_instance.public.network_interface[0].access_config[0].nat_ip
}

resource "google_compute_instance" "private" {
  name         = "lab-private-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["internal"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
  }

  metadata = {
    ssh-keys = "${var.vm_user}:${trimspace(file(pathexpand(var.ssh_key_path)))}"
  }
}

resource "google_compute_firewall" "internal_ssh" {
  name    = "lab-allow-internal-ssh"
  network = google_compute_network.lab.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.0.1.0/24"]
  target_tags   = ["internal"]
}

resource "google_compute_router" "lab" {
  name    = "lab-router"
  region  = var.region
  network = google_compute_network.lab.id
}

resource "google_compute_router_nat" "lab" {
  name                               = "lab-nat"
  router                             = google_compute_router.lab.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
