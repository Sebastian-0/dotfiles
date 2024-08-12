#!/bin/bash
set -eou pipefail
if which nvim > /dev/null; then
    git config --global core.editor "nvim"
else
    git config --global core.editor "vim"
fi

git config --global pull.rebase true
git config --global core.autocrlf input
git config --global rerere.enabled true
git config --global column.ui auto
git config --global push.autoSetupRemote true
git config --global gpg.format ssh
echo "Note: git signing must be enabled manually with:"
echo "> git config --global user.signingkey path/to/ssh/key.pub"
echo "> git config --global commit.gpgsign true"

./install_font.sh

if [ -z "$(grep "$PWD/.bash_aliases" ~/.bashrc)" ]; then
    printf "\n" >> ~/.bashrc
    printf ". \"$(pwd)/.bash_aliases\"\n" >> ~/.bashrc
    printf ". \"$(pwd)/.bash_prompt\"" >> ~/.bashrc
fi

cp .inputrc ~/.inputrc
