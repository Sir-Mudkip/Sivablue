set allow-duplicate-recipes
set ignore-comments

_default:
    #!/usr/bin/bash
    echo "https://docs.projectbluefin.io/administration#community-aliases-and-workarounds"
    ujust --list --list-heading $'Available commands:\n' --list-prefix $' - '

# Imports

import "/usr/share/sivablue/just/fetch.just"
import "/usr/share/sivablue/just/apps.just"
import "/usr/share/sivablue/just/system.just"
import "/usr/share/sivablue/just/utils.just"
