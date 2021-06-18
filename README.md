# Colloquy

## Dependencies

This repository uses git submodules for some of its dependencies, so you will have to check those out as well. You can do this for example by specifying `--recurse-submodules` when using `git clone`, or by running `git submodule update --init --recursive` after cloning. The latter command is also useful after switching branches.

To update these dependencies to newer versions, please refer to the instructions in the [Cartfile](Cartfile) and don't update the submodules manually.

Additionally, the `Colloquy.xcworkspace` expects the bouncer repository at `../bouncer`. This dependency is not managed, so you have to place it at that location manually. If you do not have access to the bouncer repository, simply ignore the missing reference. The expected behavior is, that Colloquy for Mac builds without errors also in that case.

## Build & Run

To build and run an app, open up `Colloquy.xcworkspace` and select the appropriate scheme from the dropdown menu. For macOS builds `Colloquy (Aggregate)` is the correct target, and iOS builds should use `Colloquy (iOS)`.

## Additional Documentation

… can be found at http://colloquy.info/project/wiki, but it might be outdated.
