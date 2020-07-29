set -x
git config --global pull.rebase true
git config --global core.editor "vim"

printf "\n\n" >> ~/.bashrc
printf ". \"$(pwd)/.bash_aliases\"" >> ~/.bashrc