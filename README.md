# @raisedadead's .:zap:files

> my dotfiles | fancy stuff in here... feel free to have a look around.

My dotfiles follow the convention from [`homeshick`](https://github.com/andsens/homeshick). 

`homeshick` is a  git based dotfiles synchronizer utility. dotfiles are splitup into repositories (a.k.a castles). This repository is my primary castle. It has all the common and most used configs. Other castles are either private (emails, etc.) or are platform specific.

## Installation

1. Quick install [`homeshick`](https://github.com/andsens/homeshick) and source it:

   ```bash
   git clone git://github.com/andsens/homeshick.git $HOME/.homesick/repos/homeshick
   source "$HOME/.homesick/repos/homeshick/homeshick.sh"
   ```

2. Get the castle that you need. This one is mine:

   ```bash
   homeshick clone git@github.com:raisedadead/dotfiles.git
   ```
   
3. Rinse and repeat for others:

   ```bash
   homeshick clone git@github.com:raisedadead/dotfiles-private.git
   ```

   ```bash
   homeshick clone git@github.com:raisedadead/dotfiles-mac-os.git
   ```


## Related

[my Brewfile](https://github.com/raisedadead/Brewfile)

## License

ISC © 2017 Mrugesh Mohapatra
