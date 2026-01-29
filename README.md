# Dotfiles symlinked on my machine

### Install with `stow`:

```bash
sudo apt install git stow

git clone --branch main git@github.com:Raimguzhinov/dotfiles.git

cd dotfiles

stow .
```

### Homebrew installation:

```bash
# Leaving a machine
brew leaves > ~/dotfiles/SpecificDots/MacOS/leaves.txt

# Fresh installation
xargs brew install < ~/dotfiles/SpecificDots/MacOS/leaves.txt
```

### Arch installation:

```bash
# Leaving a machine
pacman -Qqe > ~/dotfiles/SpecificDots/Arch/pacman/pkglist.txt
comm -13 <(pacman -Qqdt | sort) <(pacman -Qqdtt | sort) > ~/dotfiles/SpecificDots/Arch/pacman/optdeplist.txt
pacman -Qqem > ~/dotfiles/SpecificDots/Arch/pacman/foreignpkglist.txt

# Fresh installation
pacman -S --needed - < ~/dotfiles/SpecificDots/Arch/pacman/pkglist.txt
pacman -S --needed $(comm -12 <(pacman -Slq | sort) <(sort ~/dotfiles/SpecificDots/Arch/pacman/pkglist.txt))
pacman -Rsu $(comm -23 <(pacman -Qq | sort) <(sort ~/dotfiles/SpecificDots/Arch/pacman/pkglist.txt))
```
