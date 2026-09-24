# libvirt

The first Terraform project — a single Ubuntu VM on the local hypervisor,
built to learn the tool. **Nothing is deployed from here.** The state is empty
and the lab it led to lives in `../lab`.

Kept as a record. Everything it taught is applied properly next door.

## What it defines

A storage pool, an Ubuntu cloud image downloaded into it, a layered disk on top
of that image, a cloud-init ISO, and a domain using them.

    terraform init
    terraform plan     # will show 5 to add; nothing is deployed
    terraform apply    # only if you actually want the VM back

## What it taught

Most of a day went into a VM that would not boot. The errors were misleading
at nearly every step, and the method that eventually worked was comparing
against a VM that already ran.

**"Permission denied" from QEMU often is not a permission problem.** Hours went
into pool permissions, volume permissions, directory modes, AppArmor and
dynamic ownership. The command that settled it was:

    sudo -u libvirt-qemu qemu-img info /path/to/disk.qcow2

That succeeded, proving the file was readable by the user QEMU runs as. The
real causes were a missing `driver = { type = "qcow2" }` and an outdated
machine type.

**Read the provider schema before writing config.** This provider maps HCL
almost one-to-one onto libvirt's XML and fills in nothing. Examples found by
searching are usually for a different version. A helper that prints one level
of the schema at a time made the difference:

    terraform providers schema -json > ~/schema.json
    tfschema ~/schema.json libvirt_volume
    tfschema ~/schema.json libvirt_volume target

**The same field name appears at several depths and means different things.**
`libvirt_volume` has a `format` under `target`, another under
`backing_store`, and a third under `target.encryption`. Searching for the name
finds decoys; only the path identifies a field.

**The provider is at the wrong level of abstraction for a cloud image.**
`virt-install` sets the disk format, backing chain, machine type and console
from `--os-variant` alone. Doing it by hand through Terraform means meeting
every layer those tools normally hide. For local VMs, use `virt-install`. For
Terraform practice, use a cloud provider.

## Status

Left as-is. The `lab` project supersedes it and passes the destroy-and-rebuild
test that this one never did.
