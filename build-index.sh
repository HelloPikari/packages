#!/usr/bin/env bash
#
# build-index.sh — regenerate docs/packages.json from GitHub releases.
#
# The package definition is built HERE, not read from the plugin's composer.json.
# That file on main is the development one: its require/require-dev list phpcs,
# phpunit and (for pikari-team) runtime deps that are ALREADY vendored inside the
# release ZIP. Copying it would make every consumer install those a second time.
# Each plugin's runtime requirement is declared in plugins.json instead.
set -euo pipefail

ORG="${ORG:-HelloPikari}"
OUT="${OUT:-docs/packages.json}"
CONFIG="${CONFIG:-plugins.json}"

tmp="$(mktemp)"
echo '{}' > "$tmp"

for slug in $(jq -r 'keys[]' "$CONFIG"); do
    name="$(jq -r --arg s "$slug" '.[$s]["composer-name"]' "$CONFIG")"
    desc="$(jq -r --arg s "$slug" '.[$s].description' "$CONFIG")"
    php="$(jq -r --arg s "$slug" '.[$s].php' "$CONFIG")"

    echo "==> $ORG/$slug ($name)" >&2

    releases="$(gh api --paginate "repos/$ORG/$slug/releases" \
        --jq '.[] | select(.draft == false and .prerelease == false)
              | {tag: .tag_name, assets: [.assets[] | select(.name | endswith(".zip"))
                | {name: .name, url: .browser_download_url}]}' | jq -s '.')"

    versions="$(jq -n \
        --argjson releases "$releases" \
        --arg name "$name" --arg desc "$desc" --arg php "$php" --arg slug "$slug" '
        reduce ($releases[] | select(.assets | length > 0)) as $r ({};
          ($r.tag | ltrimstr("v")) as $v
          | . + { ($v): {
                name: $name,
                version: $v,
                description: $desc,
                type: "wordpress-plugin",
                license: "GPL-2.0-or-later",
                require: { php: $php },
                extra: { "installer-name": $slug },
                dist: { type: "zip", url: $r.assets[0].url, reference: $r.tag }
              } })')"

    if [ "$(jq 'length' <<<"$versions")" -eq 0 ]; then
        echo "    no published release with a .zip asset — skipping" >&2
        continue
    fi
    echo "    $(jq 'length' <<<"$versions") version(s)" >&2

    jq --arg name "$name" --argjson v "$versions" '.[$name] = $v' "$tmp" > "$tmp.new"
    mv "$tmp.new" "$tmp"
done

mkdir -p "$(dirname "$OUT")"
jq -n --argjson p "$(cat "$tmp")" '{packages: $p}' > "$OUT"
rm -f "$tmp"
echo "Wrote $OUT with $(jq '.packages | length' "$OUT") package(s)." >&2
