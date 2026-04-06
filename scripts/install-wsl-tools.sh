#!/bin/bash
set -e

echo "=== Installing lazydocker ==="
LAZYDOCKER_VERSION=$(curl -fsSL https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
echo "Latest lazydocker version: ${LAZYDOCKER_VERSION}"
curl -fsSL "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz" -o /tmp/lazydocker.tar.gz
tar -xzf /tmp/lazydocker.tar.gz -C /tmp lazydocker
install -m 0755 /tmp/lazydocker /usr/local/bin/lazydocker
rm -f /tmp/lazydocker /tmp/lazydocker.tar.gz
echo "lazydocker installed: $(lazydocker --version)"

echo ""
echo "=== Installing Microsoft Edit ==="
apt-get install -y -qq zstd
MSEDIT_URL=$(curl -fsSL https://api.github.com/repos/microsoft/edit/releases/latest | grep '"browser_download_url".*x86_64-linux-gnu\.tar\.zst"' | sed -E 's/.*"(https[^"]+)".*/\1/')
echo "Downloading: ${MSEDIT_URL}"
curl -fsSL "${MSEDIT_URL}" -o /tmp/msedit.tar.zst
tar --zstd -xf /tmp/msedit.tar.zst -C /tmp
install -m 0755 /tmp/edit /usr/local/bin/edit
rm -f /tmp/edit /tmp/msedit.tar.zst
echo "Microsoft Edit installed: $(edit --version 2>&1 || true)"

echo ""
echo "=== Done ==="
echo "Run 'lazydocker' to manage Docker containers"
echo "Run 'edit' to launch Microsoft Edit"
