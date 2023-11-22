set -x
git config --global pull.rebase true
git config --global core.editor "vim"
git config --global core.autocrlf input

./install_font.sh

if [ -z "$(grep "$PWD/.bash_aliases" ~/.bashrc)" ]; then
    printf "\n" >> ~/.bashrc
    printf ". \"$(pwd)/.bash_aliases\"\n" >> ~/.bashrc
    printf ". \"$(pwd)/.bash_prompt\"" >> ~/.bashrc
fi

cp .inputrc ~/.inputrc
