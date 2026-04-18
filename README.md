# Nootski

This repository contains shared GitHub community health files used across all Nootski projects:

- **Issue templates** for bugs, incidents, change requests, features, security, documentation, and questions
- **Pull request template** with a standard checklist
- **Security policy** (see [SECURITY.md](../SECURITY.md))
- **Label definitions** (see [labels.yml](../labels.yml))

## How it works

GitHub automatically applies the files in this repository to any repository in the `Nootski` account that does not have its own version. This gives every project a consistent triage and contribution workflow with zero per-repo setup.

## Syncing labels

Labels are defined centrally in [`labels.yml`](../labels.yml) and applied to each repository via the sync script in `scripts/sync-labels.sh`.

## Conventions

- Every PR must reference an issue (Closes #XXX)
- Every issue starts in `status:triage` and moves through the lifecycle
- Severity is tracked for bugs, incidents and security issues
