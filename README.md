# mvd

Start and stop **Mac Virtual Display** on Apple Vision Pro from the command line.

Normally Mac Virtual Display is started from the headset, by looking at the Mac or using Control Center. `mvd` starts it from the Mac, so you can script it, bind it to a hotkey, or run it from Shortcuts or AppleScript.

## Usage

```
mvd connect       # start Mac Virtual Display on the Vision Pro
mvd disconnect    # end it; the Mac's own screen comes back on
mvd toggle        # connect if disconnected, disconnect if connected
mvd               # same as toggle
mvd status        # prints: connected | available | not found
mvd list          # every display device macOS can see, e.g.
                  #   Apple Vision Pro  [RealityDevice14,1] (connected)
```

`connect` and `disconnect` do nothing if the display is already in that state. Errors go to stderr, and the exit code is 1.

### From AppleScript or Shortcuts

```applescript
do shell script "$HOME/bin/mvd connect"
```

In Shortcuts, use a **Run Shell Script** action with the same command.

## Build and install

`mvd` is a single Swift file with no dependencies. You need the Xcode Command Line Tools (`xcode-select --install`).

```sh
swiftc -O -o mvd mvd.swift
cp mvd ~/bin/          # or anywhere on your PATH
```

## Requirements

- An Apple silicon Mac that supports Mac Virtual Display.
- The Vision Pro has to be on, unlocked, and signed into the same Apple Account as the Mac, the same as for starting Mac Virtual Display from the headset.

Tested on a MacBook Pro (M2 Max) running macOS 27.2.

## How it works

Mac Virtual Display runs on the same system as iPad Sidecar. macOS shows the virtual display as a "Sidecar Display" connected over AirPlay. `mvd` loads the private `SidecarCore` framework and uses `SidecarDisplayManager`:

- `devices` and `connectedDevices` list what's available and what's in use.
- `connectToDevice:completion:` and `disconnectFromDevice:completion:` start and stop the session.

A Vision Pro is recognized by its model identifier, which starts with `RealityDevice`.

## Caveats

- **Private API.** `SidecarCore` is undocumented, and a macOS update could change or remove it. If that happens, `mvd` exits with `SidecarCore is unavailable on this macOS version.` or reports a missing selector.
- The display opens in whatever size and mode the headset last used. `mvd` doesn't control resolution or wide/ultrawide mode.
- `mvd` uses the first Vision Pro it finds. It doesn't pick between multiple headsets.
- `connect` and `disconnect` wait up to 30 seconds for the headset to respond before giving up.

## License

BSD 2-Clause. See [LICENSE](LICENSE).
