# Contributing

Thanks for contributing.

## Before opening a pull request

- Test on a non-critical device if possible
- Include the exported `status.txt`
- Include relevant excerpts from `bt-stability.log`
- Note the phone brand, model, Android version, and Magisk version
- Describe which mode was active

## Development notes

- Keep `post-fs-data.sh` minimal
- Prefer safer late-start logic in `service.sh`
- Make vendor-specific changes opt-in or profile-gated
- Avoid changes that can trigger boot loops
