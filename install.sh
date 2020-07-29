set -x
git config --global pull.rebase true
git config --global core.editor "vim"

echo "" >> ~/.bashrc
echo ". ~/dotfiles/.bash_aliases" >> ~/.bashrc