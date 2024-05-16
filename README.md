# Dotfiles symlinked on my machine

### Install with `ln -s`:
```bash
ln -s ~/dotfiles/.zshrc ~/.zshrc
# or
ln -s ~/dotfiles/.zshrc.hyprland ~/.zshrc

ln -s ~/dotfiles/.gitconfig ~/.gitconfig

ln -s ~/dotfiles/nvim/ ~/.config/nvim
ln -s ~/dotfiles/alacritty/ ~/.config/alacritty

ln -s ~/dotfiles/.tmux ~/.tmux
ln -s ~/dotfiles/.tmux.conf.local ~/.tmux.conf.local
ln -s ~/dotfiles/.tmux.conf ~/.tmux/.tmux.conf
ln -sf ~/.tmux/.tmux.conf
ln -s ~/dotfiles/yazi/ ~/.config/yazi

ln -s ~/dotfiles/mimeapps.list ~/.config/mimeapps.list
```

### Homebrew installation:
```bash
# Leaving a machine
brew leaves > leaves.txt

# Fresh installation
xargs brew install < leaves.txt
```

### Arch installation:
```bash
# Leaving a machine
pacman -Qqe > pkglist.txt
comm -13 <(pacman -Qqdt | sort) <(pacman -Qqdtt | sort) > optdeplist.txt
pacman -Qqem > foreignpkglist.txt

# Fresh installation
pacman -S --needed - < pkglist.txt
pacman -S --needed $(comm -12 <(pacman -Slq | sort) <(sort pkglist.txt))
pacman -Rsu $(comm -23 <(pacman -Qq | sort) <(sort pkglist.txt))
```
