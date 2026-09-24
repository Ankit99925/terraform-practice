# terraform

Three Terraform projects, each in its own directory with its own state.

| Directory  | What                                                          |
|------------|---------------------------------------------------------------|
| `lab/`     | The home lab: OPNsense, an Ubuntu server, a VLAN test VM       |
| `gcp/`     | A cloud network: VPC, two subnets, bastion host, NAT gateway   |
| `libvirt/` | The first learning project. Nothing is deployed from it now    |

Run Terraform from inside a directory, not from here. Each has its own
`terraform.tfstate`, and state is what Terraform uses to know what it created.

## Before you start

    sudo apt install terraform

Each directory needs its own `terraform init` once, to download the provider.

## Local values

Anything specific to one machine lives in `terraform.tfvars`, which is
gitignored. Each project has a `terraform.tfvars.example` listing what it needs
and how to find the values.

    cd lab
    cp terraform.tfvars.example terraform.tfvars
    # edit it
    terraform init
    terraform plan

## Habits worth keeping

**Read the plan before applying.** `plan` reports what it intends; the provider
gets the final say and can still refuse. Watch the destroy count especially —
libvirt pools and volumes cannot be updated at all, so a change Terraform
describes as in-place may come back as "requires replacement".

**Check the schema before writing config.** Provider documentation found by
searching is often for a different version.

    terraform providers schema -json > ~/schema.json
    tfschema ~/schema.json <resource>
    tfschema ~/schema.json <resource> <field>

`tfschema` prints one level at a time — which fields exist, their type, whether
they are required, optional or computed, and which are blocks. A computed field
is one the provider fills in; you can read it but not set it.

**Destroy and rebuild to prove a config.** A configuration that only works
because of something you once did by hand is not reproducible. The `gcp` and
`lab` projects have both been through this; `libvirt` never passed it.
