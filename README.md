# Joomla CD lab

This lab shows how a Joomla site can be moved between hosts with a backup and
a restore, so that changes are made on a dev copy instead of on production:

1. back up prod and restore it onto dev, sanitised so dev cannot send mail,
   run scheduled tasks or get indexed,
2. make and test the changes on dev,
3. back up dev and promote it onto prod, keeping prod's own settings.

Each step copies the whole site, database and files together. Nothing is
merged, so the workflow assumes prod is read-only while dev is being worked
on (see [One writer at a time](#one-writer-at-a-time)).

| Directory | What it does |
| --- | --- |
| [`tf/`](tf/README.md) | Terraform for a VPC and two EC2 instances, `source` (prod) and `target` (dev) |
| [`ansible/`](ansible/README.md) | Playbooks to install Joomla, back a site up and restore it elsewhere |

## Walkthrough

You need Terraform, [uv](https://docs.astral.sh/uv/), AWS credentials for
`eu-central-1` and an SSH key loaded in your agent.

```sh
# Provision both instances and note their public IPs
cd tf
terraform init
terraform apply
terraform output public_ips

# Install Joomla on both
cd ../ansible
make install
make setup

# Copy prod onto dev
make backup host=<prod>
make restore host=<dev>

# ... edit and test the site on http://<dev>/ ...

# Push dev back to prod
make backup host=<dev>
make promote host=<prod> backup=backups/latest
```

`make restore` restores the newest backup pulled (`backups/latest`) unless given
`backup=backups/<timestamp>`. `make promote` always needs `backup=`; it backs
prod up first, and `backups/latest` is resolved before that backup moves it.

## One writer at a time

Prod and dev are two copies of the same site. Once dev is restored, both can
take writes, and there is no way to merge them: pushing dev back replaces
prod's database and webroot wholesale. Anything written on prod after the
backup is lost.

So, from the moment prod is backed up until dev is pushed back:

- make no admin edits on prod (articles, menus, users, extensions, settings),
- turn off or accept the loss of anything visitors write: registrations,
  contact forms, comments, orders,
- expect the bookkeeping Joomla writes on its own to roll back: article hit
  counters, sessions (everyone gets logged out), last-visit dates, action logs.

Nothing enforces this. Putting prod in maintenance mode or disabling user
registration is up to you.

## Promoting dev onto prod

Dev's backup carries dev's sanitised state, so promoting does not just skip the
sanitising: it reads prod's own environment just before wiping it and puts it
back over dev's copy.

| Kept from prod | Taken from dev |
| --- | --- |
| Mail, robots, caching, Force HTTPS, cookie domain, `$live_site`, session and cache handlers | Everything else in Global Configuration (site name, SEF, metadata, ...) |
| `.htaccess` (or none, if prod had none) | Articles, categories, menus, modules, users |
| Scheduled task states and update site switches, for rows that existed on prod | Extensions, templates and their settings |

The DB connection in `configuration.php` always points at prod's own database.

### Rolling back

`make promote` backs prod up before replacing it, and promoting a host's own
backup is allowed. To undo a promote, take the timestamp of that safety backup
from the output (or `ls backups/`) and run:

```sh
make promote host=<prod> backup=backups/<timestamp>
```

### Gotchas

- Changes to the kept Global Configuration settings cannot be promoted. Make
  them on prod after promoting.
- Data changed by sanitising options on dev travels to prod.
  `disable_extensions` leaves those extensions disabled, and
  `reset_admin_password` leaves that admin with the dev password. Promoting
  refuses a dump made after `anonymise_users=true`, since it would replace
  every real email with `user<id>@example.invalid`.
- Scheduled tasks and update sites created on dev keep the state they had on
  dev.
- The site is down while prod is promoted: Apache is stopped, the database is
  dropped and the webroot deleted before the new copy goes in. If the promote
  fails half way, prod stays broken until rolled back.
- Promoting needs a working Joomla on prod; it fails, before changing
  anything, if prod has no database to read its settings from.
- Instances are addressed by public IP. Stopping and starting one gives it a
  new IP, so update the `host=` you use, and the "not onto its own source"
  guard of `make restore` no longer recognises it.
- Content keeps prod's absolute URLs, so links on dev may lead back to prod.
- Backups hold user emails and password hashes; see
  [`ansible/README.md`](ansible/README.md#known-limitations).
