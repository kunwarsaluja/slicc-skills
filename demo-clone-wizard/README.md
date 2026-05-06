# Demo Clone Wizard — SLICC Skill

A guided 4-step wizard that clones the Adobe EDS demo site into your own GitHub repository and DA space, fully automated inside [SLICC](https://slicc.dev).

## What it does

| Step | Action |
|------|--------|
| 1. Repository | Creates a new GitHub repo from the `scdemos/demo` template |
| 2. Code Sync | Installs the AEM Code Sync GitHub App on the new repo |
| 3. Content | Migrates all DA content via the DA Admin API (GET + POST, cross-org) |
| 4. Publish | Bulk previews and publishes all pages via the AEM Admin API |

## Install

In your SLICC chat:

```
upskill <your-github-org>/slicc-skills --skill demo-clone-wizard
```

Or install directly from this repo:

```
upskill <github-owner>/<this-repo>
```

## Requirements

- SLICC with an Adobe IMS provider configured (Settings → Providers → Adobe)
- GitHub account with permission to create repositories

## Usage

Once installed, just ask SLICC:

> "Clone the demo site" or "Launch the demo clone wizard"

SLICC will open the wizard in the sidebar. Fill in your GitHub username and repo name and follow the steps.

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Skill instructions — tells SLICC how to launch and handle the wizard |
| `demo-clone-wizard.shtml` | The wizard UI (full-document sprinkle) |
| `da-migrate.sh` | Recursively crawls and copies DA content cross-org |
| `bulk-action.sh` | Crawls page paths and triggers AEM Admin bulk preview/publish |
