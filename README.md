# AudioSwitch

AudioSwitch is a macOS program that allows switching between audio outputs
using a keyboard shortcut, from any application.

When switching, it displays the (user-defined) name of the newly selected
output, with a user interface matching the one used by the system for setting
the sound volume:

![AudioSwitch switching GUI](https://vinduv.github.io/resources/audioswitch/readme_gui_screenshot.gif)

AudioSwitch works with both built-in and removable (Bluetooth, USB…) audio
devices. If a device that has been enabled in AudioSwitch is removed, it will
be temporarily removed from the switch list; it will be automatically re-added
to the list when reconnected.

## Compatiblity

AudioSwitch has been tested on macOS 10.13 High Sierra. It should work on more
recents releases of macOS, and might be compatible with earlier OSes, but has
not been tested yet.

## Usage

To install AudioSwitch, uncompress the AudioSwitch Preferences application,
put it somewhere, and run it. Check the “Enable AudioSwitch” checkbox,
set a shortcut, and configure the audio outputs to enable.

![AudioSwitch preferences GUI](https://vinduv.github.io/resources/audioswitch/readme_prefs_screenshot.png)

That’s it! AudioSwitch is ready to be used, and will start automatically at
startup.

## Development

Xcode 10 or newer (with Swift 4.2) is needed for development.

To build AudioSwitch from source, clone the repository and initialize the
submodules to get the MASShortcut framework:

```
$ git submodule init
$ git submodule update
```

You can then open `AudioSwitch.xcodeproj` in Xcode.

## TODO

 - [ ] Create an icon for AudioSwitch Preferences
 - [ ] Add translations (currently only English and French are available)
 - [ ] Check compatibility with macOS 10.14 Mojave (the new visual effect APIs
       may remove a private API call currently used by the GUI)
 - [ ] Check compatibility with earlier versions of macOS (for instance, the
       availability of ServiceManager’s `SMJobIsEnabled` function)
