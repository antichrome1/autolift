# autolift

Autofocus and lift windows on mouse hover.

## Install

Install pre-built binary:
```console
$ mise use -g github:antichrome1/autolift@v0.9.3
$ autolift
```

Or, use nix to build from source:
```console
$ git clone https://github.com/antichrome1/autolift && cd autolift
$ make release-nix install-nix
$ autolift             # default 1s delay until lift
```

## Use

Run the `autolift` bin in background.

You can modify the default delay by putting your value in the
`~/.autolift` file (simply put the number there).

Run on system boot:
- Navigate to System Settings -> General -> Login Items
- Click `+` and select the autolift executable

## License

ISC © 2026 Aditya Singh <antichrome1@proton.me> <br>
AI usage: No AI agents/tools were/are used in this project.<br>
