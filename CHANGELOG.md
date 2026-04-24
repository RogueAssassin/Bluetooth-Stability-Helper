# Changelog

## v0.6.0 - Pokemod support + GitHub updater

### Added
- GitHub updater manifest support through `updateJson` in `module/module.prop`.
- Release workflows for packaging and publishing Magisk install zips from tags.
- Pokemod app/package checker with the current public package name: `com.pokemod.app.public`.
- Status reporting for Pokemod installed/running checks.
- Repository branding, logo, badges, and update documentation.

### Changed
- Version bumped to `0.6.0` with `versionCode=60`.
- GitHub release asset naming standardized as `bt-stability-helper-v0.6.0.zip`.

### Notes
- Pokemod checking is conservative and configurable from `common/config.sh` or imported user config.
- Default behaviour remains safe unless watchdog/recovery options are explicitly enabled.
