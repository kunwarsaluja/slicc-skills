---
name: demo-clone-wizard
description: Multi-step wizard to clone scdemos/demo into a new GitHub repo, install AEM Code Sync, migrate DA content, and bulk preview/publish the new site.
---

# Demo Clone Wizard

A guided 4-step wizard for cloning the Adobe EDS demo site (`scdemos/demo`) into a new GitHub repository and DA space.

## Steps

1. **Repository** — Creates a new GitHub repo from the `scdemos/demo` template
2. **Code Sync** — Installs the AEM Code Sync GitHub App on the new repo
3. **Content** — Migrates all DA content from `scdemos/demo` to the new DA space using the DA Admin API
4. **Publish** — Bulk previews and publishes all migrated pages via the AEM Admin API

## Requirements

- Adobe IMS session active (Settings → Providers → Adobe) — needed for DA Admin API calls
- GitHub account with permission to create repositories

## How to launch

When the user asks to "clone the demo site", "run the demo wizard", or "set up a new demo":

1. Create a scoop named `demo-clone-wizard`:
   ```
   scoop_scoop("demo-clone-wizard")
   ```

2. Feed it this exact brief (self-contained, no context needed):

```
You own the sprinkle 'demo-clone-wizard'. Your job:

1. Read: read_file /workspace/skills/sprinkles/style-guide.md
2. Copy the sprinkle file to the right location:
   bash cp /workspace/skills/demo-clone-wizard/demo-clone-wizard.shtml /shared/sprinkles/demo-clone-wizard/demo-clone-wizard.shtml
3. Copy the helper scripts:
   bash cp /workspace/skills/demo-clone-wizard/da-migrate.sh /scoops/demo-clone-wizard/da-migrate.sh
   bash cp /workspace/skills/demo-clone-wizard/bulk-action.sh /scoops/demo-clone-wizard/bulk-action.sh
   bash chmod +x /scoops/demo-clone-wizard/da-migrate.sh /scoops/demo-clone-wizard/bulk-action.sh
4. Open the sprinkle:
   bash sprinkle open demo-clone-wizard
5. DO NOT finish — stay ready for lick events from the wizard.

## Lick event handlers

Handle these actions forwarded by the cone:

**open-github** {owner, repo}:
  bash open 'https://github.com/new?template_owner=scdemos&template_name=demo&owner=OWNER&name=REPO'
  sprinkle send demo-clone-wizard '{"action":"status","message":"GitHub opened — create your repo then click Continue","type":"positive"}'

**step1-complete** {owner, repo}:
  sprinkle send demo-clone-wizard '{"action":"set-state","owner":"OWNER","repo":"REPO"}'
  sprinkle send demo-clone-wizard '{"action":"step-update","step":2}'

**open-codesync** {owner, repo}:
  bash open 'https://github.com/apps/aem-code-sync/installations/new'
  sprinkle send demo-clone-wizard '{"action":"status","message":"AEM Code Sync installer opened","type":"positive"}'
  sprinkle send demo-clone-wizard '{"action":"codesync-opened"}'

**step2-complete** {owner, repo}:
  sprinkle send demo-clone-wizard '{"action":"set-state","owner":"OWNER","repo":"REPO"}'
  sprinkle send demo-clone-wizard '{"action":"step-update","step":3}'

**copy-da-content** {owner, repo}:
  TOKEN=$(oauth-token adobe)
  If empty → sprinkle send demo-clone-wizard '{"action":"copy-error","message":"Adobe auth token not available"}'
  Else:
    sprinkle send demo-clone-wizard '{"action":"copy-progress","message":"Starting migration..."}'
    bash /scoops/demo-clone-wizard/da-migrate.sh scdemos demo OWNER REPO "$TOKEN"
  (Script sends copy-done/copy-error itself)

**step3-complete** {owner, repo}:
  sprinkle send demo-clone-wizard '{"action":"set-state","owner":"OWNER","repo":"REPO"}'
  sprinkle send demo-clone-wizard '{"action":"step-update","step":4}'

**bulk-preview** {owner, repo}:
  TOKEN=$(oauth-token adobe)
  bash /scoops/demo-clone-wizard/bulk-action.sh preview OWNER REPO "$TOKEN"

**bulk-publish** {owner, repo}:
  TOKEN=$(oauth-token adobe)
  bash /scoops/demo-clone-wizard/bulk-action.sh publish OWNER REPO "$TOKEN"

**view-site** {owner, repo}:
  bash open 'https://main--REPO--OWNER.aem.live'

**wizard-done**:
  sprinkle send demo-clone-wizard '{"action":"status","message":"All done! Your demo site is live.","type":"positive"}'
```

3. Tell the user: "The Demo Clone Wizard is open in the sidebar. Fill in your GitHub username and repo name to get started."

## Lick event routing

All sprinkle lick events come to the cone as `[Sprinkle Event: demo-clone-wizard]`. Always forward them to the `demo-clone-wizard` scoop via `feed_scoop`. Never handle them in the cone directly.
