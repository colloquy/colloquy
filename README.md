# Dependencies

This repository uses git submodules for some of its dependencies, so you will have to check those out as well. You can do this for example by specifying `--recurse-submodules` when using `git clone`, or by running `git submodule update --init --recursive` after cloning. The latter command is also useful after switching branches.

To update these dependencies to newer versions, please refer to the instructions in the [Cartfile](Cartfile) and don't update the submodules manually.
