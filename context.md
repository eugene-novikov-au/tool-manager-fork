# Instructions
- Keep this fil up to date with the current progress
- git commit with the prefix [feature]m [bugfix]m [doc], [refactor] etc. There are not tickets numbers
- each unit of work must be in a sub task (e.g. edit a file based on a code review)
- don't be chatty, do the job, don't apologise, just fix the issue
- do NOT convert plugins scriipts into libs. Leave the scrip names as they are


# Status:
Reviewed `bin/tm-dev-console` script based on code review:
- No changes required.
Reviewed `bin/tm-reload` script based on code review:
- Added documentation for the `_tm::plugin::regenerate_wrapper_scripts`, `_tm::plugin::reload`, and `_tm::boot::reload` functions.
- Reviewed and ensured `_tm::util::parse::plugin` is robust.
Reviewed `bin/tm-env-bash` script based on code review:
Reviewed `bin/tm-plugin-uninstall` script based on code review:
- Added documentation for the `_tm::plugins::uninstall` function.
- Improved error handling for the `_tm::plugins::uninstall` function.
- Added help and guidance to the interactive mode.
Reviewed `bin/tm-plugin-ls` script based on code review:
- Added documentation for various formatting and listing functions.
- Refactored output formatting logic to use a `case` statement.
Reviewed `bin/tm-plugin-install` script based on code review:
- Added documentation for the `_tm::plugins::install` function.
- Added error handling for the `_tm::plugins::install` function.
- Added help and guidance to the interactive mode.
Reviewed `bin/tm-plugin-enable` script based on code review:
- Added documentation for the `_tm::plugin::enable` and `_trap_error` functions.
- Reviewed `_tm::util::parse::plugin` for robustness.
Reviewed `bin/tm-plugin-each` script based on code review:
- Added documentation for the `_invoke` function.
- Added error handling for the `_pushd` command.
- Parallel command execution now uses a subshell to prevent `set -e` from killing the parent script.
- Implemented error handling for parallel command failures using `wait` and checking exit codes.
Reviewed `bin/tm-plugin-disable` script based on code review:
- Added documentation for `_tm::plugin::disable`.
- Added error handling for the `rm` command.
- Reviewed `_tm::util::parse::plugin` and found it to be robust.
Reviewed `bin/tm-plugin-create` script based on code review:
- Added documentation for the `_tm::plugin::__new` function.
- Implemented validation for the plugin description using a regex.
- Refactored file creation to use dedicated template functions.
- Added comments to clarify Git repository initialization and configuration.
Reviewed `bin/tm-help-commands-gui` script based on code review:
- Added a bash doc after the shebang.
Reviewed `bin/tm-help-commands` script based on code review:
- Added documentation for `__tm_help`, `__tm_help_console`, `__tm_help_serve`, and `__tm_help_generate_help_page`.
- Modified the port finding mechanism to use `ss`.
- Added a comment regarding templating engines for HTML generation.
- Included a security warning for the simple Python HTTP server.
Reviewed `bin/tm-help-cfg` script based on code review:
- Added a bash doc after the shebang.
- Added comments to explain the purpose and usage of each configuration value.
- Removed `|| true` and added proper error handling for `_tm::plugins::find_all_enabled_dirs`.
Reviewed `bin/tm-gui` script based on code review:
- Added docstrings to the `App` class and its methods.
- Implemented error logging using the `logging` module.