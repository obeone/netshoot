# Changelog

## [1.1.0](https://github.com/obeone/netshoot/compare/v1.0.0...v1.1.0) (2026-05-16)


### Features

* add thefuck, fix gitstatusd persistence, and refactor shell config ([0fc6e8b](https://github.com/obeone/netshoot/commit/0fc6e8bce47aa8f49c0aca8571219b949514507c))
* **build.sh:** add build commands for nerdctl and podman targets ([9eb4c64](https://github.com/obeone/netshoot/commit/9eb4c645c9cfeacf2df27f5cbf2a194c1b919c37))
* **build.sh:** introduce BUILDER variable and cache configuration ([b6314d7](https://github.com/obeone/netshoot/commit/b6314d79685a77670615e68cfa899c9fed3c3e70))
* **build:** migrate netshoot images to Debian Trixie with new variants and build script ([e0e8899](https://github.com/obeone/netshoot/commit/e0e889996c3ab2f82f20dd4770a01fa89a04cfa7))
* **ci:** add GitHub Actions build-and-publish workflow ([34385ff](https://github.com/obeone/netshoot/commit/34385ff20d370750b37d9f7a48d9e34ecbec739d))
* **debian:** migrate to Debian Bookworm, add advanced networking tools, multi-runtime support, and enhanced build script ([40d7764](https://github.com/obeone/netshoot/commit/40d776476dbf715fdd4aaca1e23337babb42e290))
* **docker:** add e2fsprogs to Dockerfile dependencies ([506d4ba](https://github.com/obeone/netshoot/commit/506d4ba0d8348adeb01ce88be3ca8847b81f435a))
* **docker:** add slim variant Dockerfile with minimal networking tools ([bac12be](https://github.com/obeone/netshoot/commit/bac12be619ff34e1c9d5cdc8e30a744f9ea863c6))
* **Dockerfile:** add bash command wrapper with exit 0 ([d865376](https://github.com/obeone/netshoot/commit/d865376fb77169c14077c3ac559963667a66e7c1))
* **dockerfile:** add coreutils and set default shell to zsh ([42f166a](https://github.com/obeone/netshoot/commit/42f166a74973131ef8975b79d4828c3d551e8073))
* **dockerfile:** add thefuck to system tools ([35c2abc](https://github.com/obeone/netshoot/commit/35c2abcbb3761e410b5c0f85463d92936b5c2fd3))
* **docker:** switch base images to Debian Trixie, add nerdctl client stage, and expand slim image tooling ([fcef8b3](https://github.com/obeone/netshoot/commit/fcef8b30003a151ff2510a70713ee9bf09fd849e))
* **docker:** update Dockerfile dependencies and paths ([02c0279](https://github.com/obeone/netshoot/commit/02c0279a46271c48c39e03b8588ccb9097a95ff1))
* **docs:** add CLAUDE.md guidance and update README to Debian 13 Trixie ([64a69b0](https://github.com/obeone/netshoot/commit/64a69b069d12c6ce6116c8544418851772b333f4))


### Bug Fixes

* **build,readme:** remove personal config comments and fix documentation ([8cca850](https://github.com/obeone/netshoot/commit/8cca85040baef45bd2e0273eea16576c70a35eb6))
* **build:** add --no-cache when Docker build cache is disabled ([abd7093](https://github.com/obeone/netshoot/commit/abd7093d904c89283b7381ebdd2ffbca1ad7a708))
* **build:** apply buildx cache per build tag in build_target ([836f949](https://github.com/obeone/netshoot/commit/836f94996648ff5a3bfbb9ac6375fdced6be740b))
* **ci:** skip Docker Hub login when credentials are not configured ([#5](https://github.com/obeone/netshoot/issues/5)) ([fae69e5](https://github.com/obeone/netshoot/commit/fae69e58d5087a473d20877ee6599c3525731e94))
* **dockerfile:** persist gitstatusd binary in image layer ([5210054](https://github.com/obeone/netshoot/commit/5210054d4aaea0f5ffefffe55eac8fb229cc6b1f))
* **docker:** install grpcurl from GitHub releases instead of apt ([807427e](https://github.com/obeone/netshoot/commit/807427e40531e7a1767679f4fe8dc2068487003e))
* **term:** update TERM to xterm-kitty for xterm compatibility ([8e9979a](https://github.com/obeone/netshoot/commit/8e9979a68e5c9a601eb83c5929c35ab04ebf6d3a))
* **transfers.sh:** update default TRANSFERSH_URL ([186f2e9](https://github.com/obeone/netshoot/commit/186f2e9ac4d5706f626ef2eb151763d9f44e4cb6))


### Refactoring

* clean up project for GitHub publication ([73bb563](https://github.com/obeone/netshoot/commit/73bb5633ef0c6d0565b5ac553f72fc4436bb10d3))
* **Dockerfile, build.sh:** reorganize file structure and simplify build commands ([c164189](https://github.com/obeone/netshoot/commit/c164189f5c4478b8e7c8a28e71eeb08ce795060a))
* **dockerfile:** extract installation scripts and deduplicate code ([0c435f3](https://github.com/obeone/netshoot/commit/0c435f3c438739425c52ef1268137bce5ad129f3))
* **p10k:** replace custom config with wizard-generated classic style ([747c35b](https://github.com/obeone/netshoot/commit/747c35b5f62ede440a3fb1848a90d03b8aea1c7e))
* **zshrc:** remove macOS/desktop-specific configuration ([4667435](https://github.com/obeone/netshoot/commit/4667435a3d9826c2459da9e206791361f53e8790))


### Documentation

* add full documentation, refactor config files and scripts ([977e61d](https://github.com/obeone/netshoot/commit/977e61db9c58feeaf29967c9a610fa5997de1d1e))
* add MIT LICENSE file ([b4ca999](https://github.com/obeone/netshoot/commit/b4ca999898cf35ee776077c106cbe298468eb0a1))
* **claude:** document versioning policy and release workflow ([41803a6](https://github.com/obeone/netshoot/commit/41803a6e59072dbc97930c67062855f62b934017))
* **claude:** improve CLAUDE.md with CI/CD, local build commands, and tool patterns ([34385ff](https://github.com/obeone/netshoot/commit/34385ff20d370750b37d9f7a48d9e34ecbec739d))
* **claude:** update CLAUDE.md for new scripts/ directory ([a780a18](https://github.com/obeone/netshoot/commit/a780a18029ca1490cfe9316c0e31e72bb867eef2))
* expand README usage and tool listing ([0a7564c](https://github.com/obeone/netshoot/commit/0a7564c4f65e52d782eb6bcc123802ba56aa8a66))
* **readme:** add CI/CD section with registries and required secrets ([34385ff](https://github.com/obeone/netshoot/commit/34385ff20d370750b37d9f7a48d9e34ecbec739d))
* **readme:** restructure and improve README ([e5d78b2](https://github.com/obeone/netshoot/commit/e5d78b268eb03e14bc6bfccb23b5f3c09edd2247))
* **readme:** update tool counts, tool lists, and headings; add markdownlint config ([c88d582](https://github.com/obeone/netshoot/commit/c88d582744dcad3b0435fef5f9458dc72150431a))


### CI/CD

* add manual workflow_dispatch trigger to build-and-publish ([0f3b639](https://github.com/obeone/netshoot/commit/0f3b6396c8fe73c5018aa599d6f92057e6ae2ef9))
* optimize build pipeline with sequential base→variants strategy ([2ec8441](https://github.com/obeone/netshoot/commit/2ec8441658948a5d13498430e621b577cb390e07))
* optimize build pipeline with sequential base→variants strategy ([50591ef](https://github.com/obeone/netshoot/commit/50591ef923a16f2ec1427dab26fc25224472ab30))
* **release:** add release-please for automated semantic versioning ([801364c](https://github.com/obeone/netshoot/commit/801364c88dfbc6cb2cde2444d2210575607c3e43))
* **release:** add release-please workflow and configuration ([2773bcf](https://github.com/obeone/netshoot/commit/2773bcf4a4f0c8a6c5a39fc99a336626996ec9d6))
* skip Claude Code review for PRs opened by the repo owner ([ee67210](https://github.com/obeone/netshoot/commit/ee67210de5909cf68b5f59b5da76255142610985))
* **workflow:** keep cache-to for PR builds ([7a2e97f](https://github.com/obeone/netshoot/commit/7a2e97f8c6ed7a911df2808c06d47bcb6d2aba3e))
* **workflow:** switch PR builds to build-only (no push) ([9395287](https://github.com/obeone/netshoot/commit/93952872ac985f4e3df07eac093a18ab3bcec142))
* **workflow:** switch PR builds to build-only (no push) ([0a08426](https://github.com/obeone/netshoot/commit/0a084269fef73b1963bab0d7bedff2d6a8606f73))


### Build

* **docker:** install gnupg package in image ([6b44298](https://github.com/obeone/netshoot/commit/6b442988950b1312e115b482792b2019c1e98d2a))
* **docker:** update tool packages and install Ookla speedtest via apt repo ([22b6584](https://github.com/obeone/netshoot/commit/22b6584e55a2566164ca683677f6c619342814cc))


### Miscellaneous

* add .gitignore and remove tracked artifacts ([c0f57ad](https://github.com/obeone/netshoot/commit/c0f57ad1f977dfed20ec891adff4f4dc4e2c6a87))
* **build:** add buildx build-and-push script with type/target selection and optional registry cache ([fe09fa3](https://github.com/obeone/netshoot/commit/fe09fa3ad5cce007903f72e134e4800ddb3f6ab7))
* **dockerfile:** add OCI labels, lock apt cache mounts, and split nerdctl client/full stages ([7ca9fbe](https://github.com/obeone/netshoot/commit/7ca9fbe1347a9439f594321d6017f0e4d775ddfe))
* **podman:** add storage configuration for overlay driver ([10c14e9](https://github.com/obeone/netshoot/commit/10c14e9a46f5003727e4e0358010c7525be5dd8a))
* **zsh:** add TTY guards for ZLE widgets, debug logging, and improve p10k sourcing ([34385ff](https://github.com/obeone/netshoot/commit/34385ff20d370750b37d9f7a48d9e34ecbec739d))
* **zsh:** make SSH_AUTH_SOCK and Lando PATH portable and add default web search engine ([1be9d0b](https://github.com/obeone/netshoot/commit/1be9d0b126fc1de08899e59c3de57310f4cfb1ab))
* **zsh:** replace p10k config with wizard-generated classic config and refactor zshrc ([7fe9f30](https://github.com/obeone/netshoot/commit/7fe9f30e4dede992ee10dbebcf226e8521c9e258))
