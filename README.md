# autolift

Autofocus and lift windows on mouse hover.

Install pre-built binary:
```console
$ mise use -g github:antichrome1/autolift@v0.9.2
```

Or, build from source:
```console
$ swiftc autolift.swift -O
$ ./autolift             # default 1s delay until lift
```

You can modify the default delay by putting your value in the
`~/.autolift` file (simply put the number there).

Run on system boot:
- Navigate to System Settings -> General -> Login Items
- Click `+` and select the autolift executable

## License

ISC © 2026 Aditya Singh <antichrome1@proton.me> <br>
AI usage: No AI agents/tools were/are used in this project.<br>
