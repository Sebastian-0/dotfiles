#!/bin/bash
set -euo pipefail

echo "This will install the bashrc aliases, nvim and tools."
echo ""
read -rp "Press enter to continue..."

./install_bashrc.sh
./install_tools.sh
./install_nvim.sh

echo ""
echo -e "[\e[1;32mSUCCESS\e[0m] Installation completed successfully!"
