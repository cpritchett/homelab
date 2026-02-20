# Changelog

## [1.1.0](https://github.com/cpritchett/homelab/compare/forgejo-stack-v1.0.0...forgejo-stack-v1.1.0) (2026-02-20)


### Features

* **governance:** pre-deploy scripts, secrets permission invariant ([e59834b](https://github.com/cpritchett/homelab/commit/e59834b26fbf2dd568992b977df81d1a6b0efcfa))


### Bug Fixes

* add -f flag to op inject for non-interactive operation ([43a792f](https://github.com/cpritchett/homelab/commit/43a792feedea6a6165e0a715c4eb4c6a93ddb0d9))
* add user configuration for op-connect services in compose file ([6746074](https://github.com/cpritchett/homelab/commit/6746074f2a39dae4c3801f3d97a5bce454fb508b))
* change secrets volumes to bind mounts for Komodo compatibility ([65f8452](https://github.com/cpritchett/homelab/commit/65f84529bddcb455754269ae63715f527e5c2e0a))
* cleanup secrets, pre-deploy gaps, and documentation ([a1725df](https://github.com/cpritchett/homelab/commit/a1725df064c8f3236bdf2fab219008e414b9444b))
* convert depends_on to list format for Docker Swarm compatibility ([ae03b53](https://github.com/cpritchett/homelab/commit/ae03b5347df71e25554f4e19d4287c18c6d9c3e3))
* remove env_file, use runtime env loading for Docker Swarm ([4164e1d](https://github.com/cpritchett/homelab/commit/4164e1db7a59607d6ea8abc1a706a3267fe38e7f))
* **stacks:** consolidate all appdata to apps01 SSD pool ([13da2e1](https://github.com/cpritchett/homelab/commit/13da2e139e009b32abaead1eefcd2e47cd3597cb))
* **stacks:** convert forgejo, woodpecker, restic to Swarm format ([3c1546d](https://github.com/cpritchett/homelab/commit/3c1546dbfd8d3b1d376bedcbc48b33f0bdf0b540))
* **stacks:** use restart_policy condition: any for all long-running services ([1b3f74b](https://github.com/cpritchett/homelab/commit/1b3f74b7d633eb0925d7d408b1a8f04a78af6b3d))
* standardize op-connect network naming and update service configurations across stacks ([1ed317a](https://github.com/cpritchett/homelab/commit/1ed317a4b29c3e399bf91dba16d467394ad364e2))
* update network aliases for services in various stacks ([84427d1](https://github.com/cpritchett/homelab/commit/84427d16a99d1a29f8abb80e70c44f221c64cc2b))
* update PostgreSQL 18 data directory path ([e739584](https://github.com/cpritchett/homelab/commit/e7395848388d5092e666a8682c9a9cf3557083b0))
* update user and group IDs for permissions consistency across stacks ([4d561df](https://github.com/cpritchett/homelab/commit/4d561df9a8500b3d6761f54d0d90754cc840acba))


### Refactoring

* move CLOUDFLARE_API_TOKEN to Docker Swarm secrets ([a7296fb](https://github.com/cpritchett/homelab/commit/a7296fb56622ebde09aaf18636aff92782258041))
