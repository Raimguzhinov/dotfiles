# Dotfiles symlinked on my machine

### Install with `ln -s`:
```bash
ln -s ~/dotfiles/ranger/ ~/.config/ranger
ln -s ~/dotfiles/nvim/ ~/.config/nvim
ln -s ~/dotfiles/alacritty/ ~/.config/alacritty

ln -s ~/dotfiles/.tmux ~/.tmux
ln -s ~/dotfiles/.tmux.conf.local ~/.tmux.conf.local
ln -s ~/dotfiles/.tmux.conf ~/.tmux/.tmux.conf
ln -s -f .tmux/.tmux.conf
```

### Homebrew installation:
```bash
# Leaving a machine
brew leaves > leaves.txt

# Fresh installation
xargs brew install < leaves.txt
```
