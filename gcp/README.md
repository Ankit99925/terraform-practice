# gcp

A small segmented network on Google Cloud: a VPC with a public and a private
subnet, a bastion host, an isolated instance, and NAT so the private side can
reach out but not be reached.

Built to practise cloud networking rather than to run anything. Destroy it when
you are done.

## What it creates

| Resource                     | Purpose                                     |
|------------------------------|---------------------------------------------|
| `google_compute_network`     | VPC, with `auto_create_subnetworks = false` |
| `google_compute_subnetwork`  | public, `10.0.1.0/24`                       |
| `google_compute_subnetwork`  | private, `10.0.2.0/24`                      |
| `google_compute_firewall`    | ssh from your address to tagged instances   |
| `google_compute_firewall`    | ssh from the public subnet to the private   |
| `google_compute_instance`    | public, with `access_config` for a public IP |
| `google_compute_instance`    | private, no `access_config`                 |
| `google_compute_router`      | required container for NAT                  |
| `google_compute_router_nat`  | outbound only, private subnet               |

## Setup

    gcloud auth application-default login
    cp terraform.tfvars.example terraform.tfvars   # project, and your public IP
    terraform init
    terraform plan
    terraform apply

Your public IP goes in as a `/32` — `curl -s https://api.ipify.org` gives it.
Home addresses change, so this needs updating occasionally.

## Using it

    terraform output -raw public_ip
    ssh -J ubuntu@$(terraform output -raw public_ip) ubuntu@10.0.2.2

`-J` tunnels through the public instance without exposing your SSH agent to it.
That pattern is called a bastion host, or a jump host.

## Cost

The NAT gateway bills hourly and is not in any free tier. Destroy when finished:

    terraform destroy

Then check nothing was left behind:

    gcloud compute instances list
    gcloud compute disks list
    gcloud compute addresses list

An unattached static IP is billed specifically for being reserved and unused.

## Worth knowing

**GCP creates a default route to the internet gateway for you.** So the public
subnet has outbound access without you declaring a gateway — unlike AWS or OCI
where you attach one explicitly.

**Firewall rules apply to the whole VPC**, not to a subnet. You narrow them
with `target_tags`, which are labels on instances. `source_ranges` takes CIDR
blocks; `source_tags` takes labels.

**Default is deny inbound, and it drops rather than refuses.** So a blocked
connection hangs until it times out. A connection that is *refused* immediately
means the firewall let you through and nothing was listening — usually an
instance that has not finished booting.

**Ephemeral public IPs change** on destroy and rebuild. Reserve a static
address if that matters, at the cost of a small monthly charge.
