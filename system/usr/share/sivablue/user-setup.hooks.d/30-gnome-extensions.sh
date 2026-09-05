#!/usr/bin/bash

# shellcheck source=/dev/null
source /usr/lib/sivablue/setup-services/libsetup.sh

version-script gnome-extensions user 1 || exit 0

set -x

# The enabled-extensions gschema override only seeds a brand-new profile; an
# existing/migrated dconf shadows it, so the shipped extensions never switch on
# for those users. Merge the image's default-on set into the user's own list once,
# additively - never removing anything the user has added or deliberately disabled.
OVERRIDE=/usr/share/glib-2.0/schemas/zz0-sivablue-mods.gschema.override

mapfile -t WANT < <(grep -oP '(?<=enabled-extensions=\[).*?(?=\])' "$OVERRIDE" \
    | grep -oP '[A-Za-z0-9._-]+@[A-Za-z0-9._-]+')

# If the override could not be parsed, do nothing rather than clobber the key
test "${#WANT[@]}" -gt 0 || exit 0

current="$(gsettings get org.gnome.shell enabled-extensions)"

merged="$(python3 - "$current" "${WANT[@]}" <<'PY'
import ast, sys
try:
    have = ast.literal_eval(sys.argv[1].strip())
    if not isinstance(have, list):
        have = []
except (ValueError, SyntaxError):
    have = []
for uuid in sys.argv[2:]:
    if uuid not in have:
        have.append(uuid)
print(repr(have))
PY
)"

gsettings set org.gnome.shell enabled-extensions "$merged"
