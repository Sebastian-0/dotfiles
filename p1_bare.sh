#!/bin/bash
set -euo pipefail

echo "This will only install the bashrc aliases."
echo ""
read -rp "Press enter to continue..."

./install_bashrc.sh

echo ""
echo -e "[\e[1;32mSUCCESS\e[0m] Installation completed successfully!"
