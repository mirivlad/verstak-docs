#!/usr/bin/env bash
# Verifies that relative Markdown links inside this repository resolve.
#
# A docs repo whose only build step is a no-op cannot fail, so nothing catches
# a renamed file until a reader hits the dead link.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== verstak-docs check ==="

python3 - "$ROOT" <<'PY'
import os
import re
import sys
from urllib.parse import unquote, urlsplit

root = sys.argv[1]
link_pattern = re.compile(r'\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)')
broken = []
checked = 0

for current, dirs, files in os.walk(root):
    dirs[:] = [d for d in dirs if d not in {'.git', 'node_modules'}]
    for name in files:
        if not name.endswith('.md'):
            continue
        path = os.path.join(current, name)
        with open(path, encoding='utf8') as handle:
            text = handle.read()
        # Fenced code blocks routinely contain example paths.
        text = re.sub(r'```.*?```', '', text, flags=re.S)
        for target in link_pattern.findall(text):
            parts = urlsplit(target)
            if parts.scheme or parts.netloc or not parts.path:
                continue
            checked += 1
            resolved = os.path.normpath(
                os.path.join(current, unquote(parts.path))
            )
            if not os.path.exists(resolved):
                broken.append(
                    f'{os.path.relpath(path, root)} -> {target}'
                )

print(f'  checked {checked} relative link(s)')
if broken:
    print('  ❌ unresolved links:')
    for item in broken:
        print(f'    {item}')
    sys.exit(1)
print('  ✅ all relative links resolve')
PY

echo ""
echo "✅ all checks passed"
