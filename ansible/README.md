# Joomla on Amazon Linux 2023

Playbooks run against the EC2 inventory in `aws_ec2.yaml`; hosts join
`role_web` and/or `role_db` through their `Role` tag, and are named by their
public IP. The inventory needs AWS credentials in the environment, and SSH
logs in as `ec2-user` with whatever key your agent offers.

```sh
make install                 # uv env + collections
make inventory               # list hosts by role
make setup                   # MariaDB + Apache/PHP + Joomla on every role host
make setup host=<ip>         # ... or only on one
make check                   # syntax check + ansible-lint
make help                    # all targets
```

`make setup-db` and `make setup-joomla` run the two halves on their own. When
limiting a setup to a web host whose DB lives elsewhere, pass both:
`host="<web>,<db>"`.

Extra `ansible-playbook` arguments go through `args`, e.g.
`make setup host=1.2.3.4 args="-e foo=bar"`.

`setup_joomla.yml` only installs Joomla when `configuration.php` is missing, so
re-running it never touches an existing site. `setup_webserver.yml` is an
unrelated Nginx example and is not used by any target.

## Backing up and restoring onto another host

Use this to copy prod onto a dev server. Pushing dev back to prod uses
`make promote` instead (see [below](#promoting-onto-a-live-site)); the
[top-level README](../README.md) covers the whole round trip.

```sh
# 1. Back up a host and pull it into ansible/backups/<timestamp>/
make backup host=<source>

# 2. Restore it onto another host (asks first; wipes that host's DB and webroot)
make restore host=<target>
```

The backup reads the DB connection from the source's `configuration.php`,
dumps the DB, tars the webroot without caches and logs, and writes a
`manifest.json`. The source keeps the newest 3 backups under
`/var/backups/joomla/`; `ansible/backups/latest` points at the last one pulled.
Local backups are never pruned.

The restore takes `ansible/backups/latest` unless given
`backup=backups/<timestamp>`. It refuses to run without confirmation, on the
host the backup came from, or against more than one `role_db` host. On the
target it:

- imports the dump and disables scheduled tasks and update checks,
- keeps the source's `configuration.php` but points it at the target DB and
  turns off mail, caching and indexing (`robots` noindex),
- replaces `.htaccess` with Joomla's stock `htaccess.txt`.

The target DB name, user and password come from `group_vars/all.yml`, not from
the source.

Optional extra vars, passed as `args='-e ...'`:

| Var | Effect |
| --- | --- |
| `anonymise_users=true` | Rewrite user emails to `user<id>@example.invalid` |
| `'{"disable_extensions": ["element", ...]}'` | Disable extensions by `element` (payment, analytics, API integrations) |
| `reset_admin_username=<u> reset_admin_password=<p>` | Set a known password for an admin |

These change the restored data, so they end up on prod if that copy is pushed
back.

## Promoting onto a live site

```sh
make promote host=<prod> backup=backups/<timestamp>
```

This first backs the live site up like `make backup`, then runs
`restore_joomla.yml` with `-e promote=true`. In that mode the restore:

- reads the target's `configuration.php`, `.htaccess`, scheduled task states
  and update site switches before wiping it,
- imports the backup without sanitising it, then puts those back: the
  target's mail, robots, caching, Force HTTPS, cookie domain, `$live_site` and
  session/cache handler settings, its `.htaccess` (or none), and its task and
  update site states for every row it had,
- allows restoring a backup onto the host it came from, which is how a promote
  is rolled back,
- refuses `anonymise_users`, `disable_extensions` and `reset_admin_*`, and
  refuses a dump containing `@example.invalid` emails.

`backup=` is required, and resolved before the safety backup runs, so
`backup=backups/latest` still means the backup pulled before `make promote`.
See the [top-level README](../README.md#promoting-dev-onto-prod) for what is
kept and what comes from the backup.

### Known limitations

- The backup assumes the source is not being written to. The DB and files are
  captured seconds apart, not atomically, and anything written to the source
  after the backup is lost when a copy is restored over it.
- A restore discards whatever was changed on the target, and a failed one
  leaves the target without a working site. Only `make promote` takes a backup
  of the target first.
- Content and extension settings keep the source's absolute URLs.
- The backup refuses DBs with non-InnoDB tables (MEMORY is fine), since
  `--single-transaction` cannot snapshot them.
- The restore refuses dumps from MySQL 8 that use `utf8mb4_0900_*`
  collations, which MariaDB cannot import.
- PHP and Joomla versions are recorded in `manifest.json` but not compared;
  the target gets whatever PHP Amazon Linux ships.
- The backup needs free space for twice the webroot on the source.
- Extensions licensed per domain may complain on the target.
- `make restore` and `make promote` prompt for confirmation, so they cannot
  run unattended. Call `ansible-playbook` with `-e restore_confirm=true` (and
  `-e promote=true`) for that.
- Backups contain user emails and password hashes. `ansible/backups/` is
  gitignored; keep it out of synced folders too.

## Secrets

`group_vars/all.yml` and `setup_joomla.yml` hold placeholder passwords. To
replace them with vaulted values, run (choosing your own password):

```sh
uv run ansible-vault encrypt_string --name db_password
```

paste the output over the `db_password` line in `group_vars/all.yml`, and run
playbooks with `args="--ask-vault-pass"`.
