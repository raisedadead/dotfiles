# [@raisedadead](https://github.com/raisedadead)'s dotfiles

> ### Every-day carry for my systems.

My dotfiles follow the convention from
[`homeshick`](https://github.com/andsens/homeshick).

`homeshick` is a Git-based dotfiles synchronizer utility. The convention is to
split up collections of dotfiles into repositories called "castles". This
particular repository is my primary castle. It has all the standard and most
used configs. Other castles are private or platform-specific.

Be mindful of the spelling "homesick" vs. "home**sh**ick". The former is the
original tool implemented in ruby and later in shell script. I use a shell alias
`alias home=homeshick` to execute commands for convenience.

In practice, you should be able to use the files as is, by getting them from the
`/home` directory in this repository.

## Prerequisite

If you are the same person as I am, make sure that the initial system setup
checklist has been completed and tools and packages have been installed.

### Packages and tools:

Check and get additional tools and packages for the system.

- Brewfile for Homebrew on Linux

  <https://github.com/raisedadead/dotfiles-linux/blob/master/home/Brewfile>

- Brewfile for Homebrew on macOS

  <https://github.com/raisedadead/Brewfile>

  ~~I manage my `Brewfile` on macOS with a Brewfile manager called
  [Brew-file](https://github.com/rcmdnk/homebrew-file). It handles installing
  casks and applications from the App Store with `mas-cli`. Additionally it
  neatly wraps the `brew` command to keep the Brewfile updated and
  synchronized.~~

  I now use `brew bundle` to manage the Brewfile.

## Installation

1. Install [`homeshick`](https://github.com/andsens/homeshick) and source it:

   ```bash
   git clone https://github.com/andsens/homeshick.git $HOME/.homesick/repos/homeshick
   source ~/.homesick/repos/homeshick/homeshick.sh
   ```

   Later we would be able to use our alias `dot` for `homeshick`, once we have
   loaded the first castle.

2. Get the primary castle:

   ```bash
   homeshick clone git@github.com:raisedadead/dotfiles.git
   ```

3. Repeat for others:

   Private Castle (<https://github.com/raisedadead/dotfiles-private>):

   ```bash
   homeshick clone git@github.com:raisedadead/dotfiles-private.git
   ```

   Ubuntu Castle (<https://github.com/raisedadead/dotfiles-linux>):

   ```bash
   homeshick clone git@github.com:raisedadead/dotfiles-linux.git
   ```

   macOS Castle (<https://github.com/raisedadead/dotfiles-macos>):

   ```bash
   homeshick clone git@github.com:raisedadead/dotfiles-macos.git
   ```

   Neovim Castle (<https://github.com/raisedadead/dotfiles-nvim>):

   ```bash
   homeshick clone git@github.com:raisedadead/dotfiles-nvim.git
   ```

## License

ISC © 2017 Mrugesh Mohapatra
