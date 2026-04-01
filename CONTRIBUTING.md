# Contributing

Thanks for your interest in contributing! This is a small, personal project but contributions are welcome.

## Getting Started

1. Fork and clone the repo
2. Read the [README](README.md) to understand the setup
3. Make sure you have Podman and an NVIDIA GPU with CDI configured

## Scope

This project is intentionally minimal. Spare me slop, I won't read it.

## Guidelines

- Keep scripts simple and self-contained - no external dependencies on the host beyond Podman
- All containers must run on the internal network with no internet access (except temporary download containers)
- Test your changes with both `./build.sh` and the relevant script before submitting
- Follow the existing style: bash with `set -euo pipefail`, comment blocks between sections, consistent naming

## Submitting Changes

1. Create a branch for your change
2. Keep commits focused - one logical change per commit
3. Open a pull request with a clear description of what and why
4. Make sure all scripts still work end-to-end

## Reporting Issues

https://boyter.org/posts/the-three-f-s-of-open-source/