# Infrastructure

Creates, in `eu-central-1`:

- a VPC with one public subnet and an internet gateway,
- a security group allowing SSH from `ssh_allowed_cidr`, HTTP from anywhere and
  MariaDB (3306) only between members of the group,
- one Amazon Linux 2023 instance per entry in `instances` (by default `source`
  and `target`), with an encrypted gp3 root volume and IMDSv2 required.

Each instance gets a `Role` tag from `instances`. The Ansible inventory turns
that tag into `role_web` / `role_db` groups, so `web,db` puts Apache, PHP and
MariaDB on the same box.

## Usage

`ssh_public_key` has no default. Put it in `terraform.tfvars` (gitignored):

```hcl
ssh_public_key   = "ssh-ed25519 AAAA... you@host"
ssh_allowed_cidr = "203.0.113.4/32"
```

then, with AWS credentials in the environment:

```sh
terraform init
terraform apply
terraform output public_ips
```

| Variable | Default | |
| --- | --- | --- |
| `region` | `eu-central-1` | |
| `name` | `joomla-cd` | Prefix for resource names and tags |
| `instance_type` | `t3.micro` | |
| `instances` | `{ source = "web,db", target = "web,db" }` | Instance name to `Role` tag |
| `ssh_public_key` | | Installed for `ec2-user` |
| `ssh_allowed_cidr` | `0.0.0.0/0` | Narrow this to your own IP |

## Gotchas

- `ansible/aws_ec2.yaml` hardcodes `eu-central-1`. Change both when changing
  `region`.
- Instances have no Elastic IP. A stop/start changes the public IP, which is
  what Ansible uses as the host name.
- Splitting web and DB onto separate instances (`web` and `db` tags) works, but
  the DB is only reachable from inside the security group, so keep every
  instance in it.
- State is local (`terraform.tfstate`, gitignored). Do not lose it, or the
  instances have to be cleaned up by hand.
