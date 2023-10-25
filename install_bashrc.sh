set -x
git config --global pull.rebase true
git config --global core.editor "vim"
git config --global core.autocrlf input

printf "\n\n" >> ~/.bashrc
printf ". \"$(pwd)/.bash_aliases\"" >> ~/.bashrc

cp .inputrc ~/.inputrc
