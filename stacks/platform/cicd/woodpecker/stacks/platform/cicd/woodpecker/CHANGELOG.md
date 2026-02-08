# Changelog

## [1.0.1](https://github.com/cpritchett/homelab/compare/woodpecker-stack-v1.0.0...woodpecker-stack-v1.0.1) (2026-02-08)


### Bug Fixes

* add -f flag to op inject for non-interactive operation ([43a792f](https://github.com/cpritchett/homelab/commit/43a792feedea6a6165e0a715c4eb4c6a93ddb0d9))
* change secrets volumes to bind mounts for Komodo compatibility ([65f8452](https://github.com/cpritchett/homelab/commit/65f84529bddcb455754269ae63715f527e5c2e0a))
* convert depends_on to list format for Docker Swarm compatibility ([ae03b53](https://github.com/cpritchett/homelab/commit/ae03b5347df71e25554f4e19d4287c18c6d9c3e3))
* remove env_file, use runtime env loading for Docker Swarm ([4164e1d](https://github.com/cpritchett/homelab/commit/4164e1db7a59607d6ea8abc1a706a3267fe38e7f))
* standardize op-connect network naming and update service configurations across stacks ([1ed317a](https://github.com/cpritchett/homelab/commit/1ed317a4b29c3e399bf91dba16d467394ad364e2))
* update network aliases for services in various stacks ([84427d1](https://github.com/cpritchett/homelab/commit/84427d16a99d1a29f8abb80e70c44f221c64cc2b))


### Refactoring

* move CLOUDFLARE_API_TOKEN to Docker Swarm secrets ([a7296fb](https://github.com/cpritchett/homelab/commit/a7296fb56622ebde09aaf18636aff92782258041))

## 1.0.0 (2026-02-01)


### Features

* add 1Password Connect stack for enhanced secret management ([#116](https://github.com/cpritchett/homelab/issues/116)) ([a40319a](https://github.com/cpritchett/homelab/commit/a40319aba2c32fbbcbb079677b596fb9d87b5f1d))


### Bug Fixes

* add user configuration for op-connect services in compose file ([#126](https://github.com/cpritchett/homelab/issues/126)) ([e4892dd](https://github.com/cpritchett/homelab/commit/e4892ddb56b9df8816e4554521e5a7c71c73b969))
