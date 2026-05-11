# Contributing to envified

First off, thank you for considering contributing to `envified`! It's people like you that make `envified` such a great tool for the Flutter community.

## Branching Strategy

We use a branching model that balances stability with developelopment speed:

- **main**: Production-ready, stable releases only.
- **develop**: Integration branch for the next release.
- **feature/***: New features (branch from `develop`).
- **fix/***: Bug fixes (branch from `develop`).
- **docs/***: Documentation updates (branch from `develop`).
- **release/v*.*.***: Release preparation (branch from `develop`).

## Pull Request Process

1.  Branch from `develop` for features, fixes, or documentation.
2.  Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.
3.  Ensure all tests pass and code is formatted.
4.  Update the `CHANGELOG.md` with your changes under the `[Unreleased]` section (or the next version if known).
5.  Open a PR against the `develop` branch.
6.  Once approved and merged into `develop`, it will be integrated into the next release.

## Commit Message Guidelines

We follow Conventional Commits: `<type>(<scope>): <subject>`

### Types:
- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that do not affect the meaning of the code (white-space, formatting, etc)
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **perf**: A code change that improves performance
- **test**: Adding missing tests or correcting existing tests
- **chore**: Changes to the build process or auxiliary tools and libraries

### Example:
```
feat(auto-discovery): scan assets for .env.* files automatically
```

## Community Standards

Please refer to our [Code of Conduct](CODE_OF_CONDUCT.md) for details on our code of conduct and the process for submitting pull requests to us.
