# Pikari Composer package index

A Composer repository for the Pikari WordPress plugins, so a site managed with
Composer installs the **same built ZIP** that a site without Composer downloads
from the GitHub release page. One artifact, two install paths.

## Using it

Add the repository, then require the plugins as normal:

```json
{
  "repositories": [
    { "type": "composer", "url": "https://hellopikari.github.io/packages/" }
  ],
  "require": {
    "pikari-inc/pikari-gutenberg-modals": "^1.0",
    "pikari-inc/pikari-gutenberg-query-filter": "^0.1",
    "pikari-inc/pikari-team": "^1.0"
  }
}
```

With `composer/installers` and an `installer-paths` entry for
`type:wordpress-plugin`, each plugin lands in `wp-content/plugins/<slug>/`
with its `build/` directory already compiled.

Sites that do not use Composer download the ZIP from the plugin's releases page
and are kept up to date by plugin-update-checker, which reads the same asset.

## How it works

`build-index.sh` reads every published, non-prerelease GitHub release for each
plugin listed in `plugins.json`, takes its `.zip` asset, and writes
`docs/packages.json`. GitHub Pages serves that directory.

The package definition is **built here, not read from the plugin's
`composer.json`.** That file on `main` is the development one — it carries
phpcs, phpunit and, for pikari-team, runtime dependencies that are already
vendored inside the release ZIP. Copying it would make every consumer install
those a second time and collide with the shipped autoloader. Each plugin's real
runtime requirement is declared in `plugins.json` instead.

Releases with no `.zip` asset are skipped. Three predate the release workflow
and have none: modals v0.1.0 and v0.1.1, query-filter v0.1.12.

## Regenerating

**After publishing a plugin release, run the workflow:** Actions → Regenerate
package index → Run workflow. That is the fastest path, and it is a step in the
release checklist.

It also runs daily at 06:17 UTC, so the index is never more than a day stale
even if that step is missed.

A plugin's `release.yml` does *not* dispatch here. `GITHUB_TOKEN` cannot trigger
a workflow in another repository, so that would need a cross-repo PAT stored as
a secret in all three plugin repos. The `repository_dispatch` trigger is left in
place should that ever be worth doing. Locally:

```bash
./build-index.sh          # needs gh, jq
```

## Adding a plugin

Add an entry to `plugins.json` with its `composer-name`, `description` and
minimum `php`, then run the workflow. The slug is the GitHub repository name and
becomes `extra.installer-name`.
