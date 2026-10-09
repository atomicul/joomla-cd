.DEFAULT_GOAL := help

PLAYBOOK = uv run ansible-playbook -i aws_ec2.yaml $(if $(host),--limit "$(host)") $(args)

.PHONY: help install check inventory require-host setup setup-db setup-joomla backup restore promote

help:
	@echo "Usage:"
	@echo "  make install                    - Sync uv environment and install Ansible requirements"
	@echo "  make check                      - Run ansible-lint and playbook syntax checks"
	@echo "  make inventory                  - Show the EC2 inventory groups"
	@echo "  make setup [host=<h>]           - Set up MariaDB and Joomla (default: all role hosts)"
	@echo "  make setup-db [host=<h>]        - Set up MariaDB only"
	@echo "  make setup-joomla [host=<h>]    - Set up Apache, PHP and Joomla only"
	@echo "  make backup host=<source>       - Back up a site into backups/<timestamp>/"
	@echo "  make restore host=<target>      - Restore a backup onto a host (wipes it)"
	@echo "    [backup=backups/<timestamp>]  - Backup to restore (default: backups/latest)"
	@echo "  make promote host=<live> backup=backups/<timestamp>"
	@echo "                                  - Back up a live site, then restore a backup over it"
	@echo "                                    keeping its own settings (also rolls back)"
	@echo ""
	@echo "Playbook targets take [args='...'] for extra ansible-playbook arguments."

install:
	uv sync
	uv run ansible-galaxy collection install -r collections/requirements.yml

check:
	@for f in playbooks/*.yml; do \
		uv run ansible-playbook --syntax-check "$$f"; \
	done
	uv run ansible-lint

inventory:
	uv run ansible-inventory -i aws_ec2.yaml --graph

require-host:
	@if [ -z "$(host)" ]; then \
		echo "Error: no host specified. Use: make $(MAKECMDGOALS) host=<ip>"; \
		exit 1; \
	fi

setup: setup-db setup-joomla

setup-db:
	$(PLAYBOOK) playbooks/setup_database.yml

setup-joomla:
	$(PLAYBOOK) playbooks/setup_joomla.yml

backup: require-host
	$(PLAYBOOK) playbooks/backup_joomla.yml

restore: require-host
	@printf "Restoring wipes the DB and webroot on %s. Continue? [y/N] " "$(host)"; \
	read answer; \
	[ "$$answer" = y ] || { echo "Aborted."; exit 1; }
	$(PLAYBOOK) playbooks/restore_joomla.yml -e restore_confirm=true $(if $(backup),-e backup_dir=$(backup))

promote: require-host
	@if [ -z "$(backup)" ] || [ ! -d "$(backup)" ]; then \
		echo "Error: no backup found. Use: make promote host=<ip> backup=backups/<timestamp>"; \
		exit 1; \
	fi
	@printf "Promoting replaces the live site on %s with %s. Continue? [y/N] " "$(host)" "$(realpath $(backup))"; \
	read answer; \
	[ "$$answer" = y ] || { echo "Aborted."; exit 1; }
	$(PLAYBOOK) playbooks/backup_joomla.yml
	$(PLAYBOOK) playbooks/restore_joomla.yml -e restore_confirm=true -e promote=true -e backup_dir=$(realpath $(backup))
