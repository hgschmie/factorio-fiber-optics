# Factorio mod development

- These are general rules on how to develop mods for the Factorio game.
- The mod can use any API listed on https://lua-api.factorio.com/latest/
- The basic functionality for a mod is described here: https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html
- The mod is mostly written in lua.


# Collaboration

A mod is in a single github repository.

A mod should have minimal dependencies. You are not allowed to add dependencies on your own. If needed, prompt the user and he will add them for you.

Mods should use the Factorio API, its libraries and the code in the
framework and stdlib folders as library. No external dependencies
should be added.

A repository contains a number of subfolders. You are not allowed to
modify files in the following folders without explicit permission:

- `framework`
- `stdlib`
- `.portal`
- `gfx`

A mod may contain multiple localizations. While developing, only update localization in the `locale/en` folder, ignore all other languages.

# Lua style

Factorio uses lua 5.2.1 with a few modifications as described here: https://lua-api.factorio.com/latest/auxiliary/libraries.html

The code should use the type annotaions described at https://luals.github.io/wiki/annotations/

# Code organization

For the settings stage, you can modify `settings.lua`, `lib/settings.lua`, the fields prefixed with `settings` in the `lib/constants.lua` file and the localization definitions in the `locale` folder.

For the data stage, you can modify `data.lua` to add more 'require' statements and all files in the `prototypes` folder. If more files are needed, organize them in the `prototypes` folder.

For the runtime stage, you can modify `control.lua` which contains the interface between the various Factorio events and the actual mod code. The actual functionality is in files in the `scripts` folder.

The `lib` folder contains files that are loaded in all stages. If there is any code that is specific to a stage (e.g. code that relies on variables that are only available in runtime stage), it must be guarded by an explicit check.

- `lib/init.lua` is the main entry point for the mod code. All official game entry points (`settings.lua`, `data.lua`, `data-updates.lua`, `data-final-fixes.lua` and `control.lua` load this file. It initializes the framework code and then loads the `lib/this.lua` file.

- `lib.this.lua` is the global entry point for all pieces of the mod.

  * It sets up a basic version in the settings and data stages and loads all code functionality in the runtime stage.
  * It configures other, optional mods that can interact with this mod through remote API calls: `This.other_mods`
  * It contains the init() function for creating the storage data: `This:init()`
  * It contains a global function to return a reference to the mod storage: `This.storage()`

# General development guidelines

- Before doing *ANY* potential destructive operations (e.g. deleting files or directories, removing large blocks of code that has not been committed to the repository), ask the user for explicit confirmation.


# Mod-specific instructions

Look for a file `mod.spec.md` in the root folder of the repository. This file contains the mod specific instructions. It describes the functionality and, if needed, special instructions for the code in this mod. If information in that file contradicts information in this file,
the instructions in the `mod.spec.md` file are more accurate. If you see a conflict that you can not resolve, prompt the user for instructions.
