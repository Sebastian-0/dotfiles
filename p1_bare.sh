#!/bin/bash
set -euo pipefail

echo "This will only install the bashrc aliases."
echo ""
if [ -t 0 ]; then read -rp "Press enter to continue..."; fi

./install_bashrc.sh

echo ""
echo -e "[\e[1;32mSUCCESS\e[0m] Installation completed successfully!"
