# Changelog

## [1.0.1](https://github.com/cpritchett/homelab/compare/woodpecker-stack-v1.0.0...woodpecker-stack-v1.0.1) (2026-02-20)


### Bug Fixes

* add -f flag to op inject for non-interactive operation ([43a792f](https://github.com/cpritchett/homelab/commit/43a792feedea6a6165e0a715c4eb4c6a93ddb0d9))
* change secrets volumes to bind mounts for Komodo compatibility ([65f8452](https://github.com/cpritchett/homelab/commit/65f84529bddcb455754269ae63715f527e5c2e0a))
* convert depends_on to list format for Docker Swarm compatibility ([ae03b53](https://github.com/cpritchett/homelab/commit/ae03b5347df71e25554f4e19d4287c18c6d9c3e3))
* dnsmasq foreground mode, woodpecker agent gRPC, smartctl auto_pull ([faf46e8](https://github.com/cpritchett/homelab/commit/faf46e8d4fc185259d6130e830908057466badbc))
* remove env_file, use runtime env loading for Docker Swarm ([4164e1d](https://github.com/cpritchett/homelab/commit/4164e1db7a59607d6ea8abc1a706a3267fe38e7f))
* **stacks:** convert forgejo, woodpecker, restic to Swarm format ([3c1546d](https://github.com/cpritchett/homelab/commit/3c1546dbfd8d3b1d376bedcbc48b33f0bdf0b540))
* **stacks:** use restart_policy condition: any for all long-running services ([1b3f74b](https://github.com/cpritchett/homelab/commit/1b3f74b7d633eb0925d7d408b1a8f04a78af6b3d))
* standardize op-connect network naming and update service configurations across stacks ([1ed317a](https://github.com/cpritchett/homelab/commit/1ed317a4b29c3e399bf91dba16d467394ad364e2))
* update network aliases for services in various stacks ([84427d1](https://github.com/cpritchett/homelab/commit/84427d16a99d1a29f8abb80e70c44f221c64cc2b))
* **woodpecker:** use Alpine images and add ignore_services ([07810de](https://github.com/cpritchett/homelab/commit/07810de4152d18a2e9e04f2deb7346b698bf1349))


### Refactoring

* move CLOUDFLARE_API_TOKEN to Docker Swarm secrets ([a7296fb](https://github.com/cpritchett/homelab/commit/a7296fb56622ebde09aaf18636aff92782258041))
