# Tool Manager (`tm`) Codebase Analysis

## 1. Purpose of the Tool Manager (`tm`)

The Tool Manager (`tm`) is a Bash-based framework designed to manage a collection of command-line tools, referred to as "plugins." It provides a structured way to:
*   Install and manage the tool manager itself.
*   Discover, install, enable, disable, and update individual plugins.
*   Run plugin commands, potentially with different configurations.
*   Organize tools into a coherent system, accessible via `tm-*` prefixed commands and commands provided by the plugins.

## 2. Core Components and Their Roles

*   **Installation Script (`install.sh`)**:
    *   Handles the initial setup of the Tool Manager.
    *   Checks for Bash version compatibility.
    *   Clones the main `tool-manager` Git repository into `$TM_HOME` (default: `$HOME/.local/bin/tool-manager`).
    *   Sources the Tool Manager's main `.bashrc` file from the user's `~/.bashrc` to integrate `tm` into the shell environment.

*   **Main Initialization (`.bashrc` -> `bin/.tm.boot.sh`)**:
    *   **`.bashrc`** (at the root of `TM_HOME`): This is the primary entry point sourced by the user's shell.
        *   It sources `bin/.tm.boot.sh`.
        *   Conditionally calls `_tm::boot::load` (defined in bootstrap) based on the `TM_ENABLED` environment variable.
    *   **`bin/.tm.boot.sh`**:
        *   Performs core initialization (`_tm::boot::init`).
        *   Sets up crucial `TM_*` environment variables defining paths for binaries, plugin installations, configurations, variable data, etc.
        *   Sources utility scripts: `bin/.tm.common.sh`, `bin/.tm.plugin.sh`, `bin/.tm.plugins.sh`.
        *   Defines `_tm::boot::load`, which adds `TM_BIN` and `TM_PLUGINS_BIN_DIR` to `PATH` and loads all enabled plugins.

*   **Command Scripts (`bin/tm-*` files)**:
    *   Located in `$TM_HOME/bin/`.
    *   These are individual Bash scripts that implement the various `tm-*` commands (e.g., `tm-plugin-install`, `tm-plugin-enable`, `tm-plugin-ls`, `tm-help-commands`).
    *   They utilize functions from the common and plugin management utility scripts.

*   **Utility Scripts**:
    *   **`bin/.tm.common.sh`**: Provides a rich set of common helper functions for logging, error handling (`_err`, `_die`), user input (`_read`), filesystem operations (`_realpath`, `_touch`), argument parsing (`_parse_args`), etc.
    *   **`bin/.tm.util.sh`**: Contains functions for reading and parsing INI configuration files (like `plugins.ini`), enabling structured access to plugin metadata.

*   **Plugin Management Scripts**:
    *   **`bin/.tm.plugin.sh`**: Manages individual plugins.
        *   `_tm::plugin::load`: Loads a specific plugin by sourcing its `.bashrc` (if any), scripts in `bashrc.d/`, and running services in `service.d/`.
        *   `_tm::plugin::enable`/`_tm::plugin::__disable`: Handles enabling/disabling plugins by creating/removing symlinks in `$TM_PLUGINS_ENABLED_DIR` and running plugin-specific lifecycle scripts (`plugin-enable`, `plugin-disable`, `plugin-requires`).
        *   `_tm::plugin::__generate_wrapper_scripts`: Generates wrapper scripts in `$TM_PLUGINS_BIN_DIR` for each command in an enabled plugin. These wrappers set up the plugin's environment before execution.
    *   **`bin/.tm.plugins.sh`**: Manages collections of plugins.
        *   `_tm::plugins::load_all_enabled`: Loads all currently enabled plugins.
        *   `_tm::plugins::install`: Installs new plugins by cloning their Git repositories based on definitions in INI files.
        *   `_tm::plugins::find_all_enabled_dirs`/`_tm::plugins::find_all_installed_dirs`: Lists enabled/installed plugins.
        *   `_tm::plugins::__available_foreach_call`: Iterates over plugins defined in INI files for bulk operations.

*   **Plugin Definition (`plugins.ini`)**:
    *   An INI file (or multiple, via `TM_PLUGINS_REGISTRY_DIR`) that serves as a catalog for available plugins.
    *   Each section defines a plugin, specifying its installation directory name (`dir`), Git repository URL (`repo`), default commit/branch (`commit`), and description (`desc`).
    *   Also includes a `run-mode` (e.g., `direct`, `docker`). The `direct` mode (via generated wrapper scripts) is primarily detailed in the core scripts. The `docker` value implies an alternative execution mechanism.

*   **Directory Structure (Key `TM_*` Environment Variables)**:
    *   `TM_HOME`: Root directory of the Tool Manager installation (e.g., `$HOME/.local/bin/tool-manager`).
    *   `TM_BIN`: Directory containing the core `tm-*` scripts (`$TM_HOME/bin`).
    *   `TM_VAR_DIR`: Base directory for variable data (e.g., `$HOME/.local/share/tool-manager`).
    *   `TM_PLUGINS_INSTALL_DIR`: Where plugin repositories are cloned (`$TM_HOME/plugins`).
    *   `TM_PLUGINS_ENABLED_DIR`: Contains symlinks to enabled plugins (`$TM_VAR_DIR/plugins/enabled`).
    *   `TM_PLUGINS_BIN_DIR`: Contains the generated wrapper scripts for plugin commands, which is added to `PATH` (`$TM_VAR_DIR/plugins-bin`).
    *   `TM_PLUGINS_CFG_DIR`: Directory for user-specific plugin configurations (e.g., `$HOME/.config/tool-manager`). Scripts like `$TM_PLUGINS_CFG_DIR/<plugin_name>.bashrc` are sourced during plugin loading.

## 3. Main Functions/Workflows

*   **Installation of Tool Manager**:
    1.  User runs `install.sh` (e.g., via `curl | bash`).
    2.  Script clones `tool-manager` repo to `$TM_HOME`.
    3.  Script appends a line to `~/.bashrc` to source `$TM_HOME/.bashrc`.

*   **Initialization on Shell Start**:
    1.  User's `~/.bashrc` sources `$TM_HOME/.bashrc`.
    2.  `$TM_HOME/.bashrc` sources `$TM_HOME/bin/.tm.boot.sh`.
    3.  `_tm::boot::init` in bootstrap script sets up environment variables and sources common/plugin utility scripts.
    4.  If `TM_ENABLED` is true, `_tm::boot::load` is called:
        *   `$TM_BIN` and `$TM_PLUGINS_BIN_DIR` are added to `PATH`.
        *   `_tm::plugins::load_all_enabled` is called, which iterates through enabled plugins and calls `_tm::plugin::load` for each.
        *   `_tm::plugin::load` sources the plugin's `.bashrc` and `bashrc.d/` scripts.

*   **Plugin Installation (e.g., `tm-plugin-install <plugin_name>`)**:
    1.  `tm-plugin-install` script calls `_tm::plugins::install`.
    2.  `_tm::plugins::install` scans `TM_PLUGINS_REGISTRY_DIR` and  `TM_PLUGINS_DEFAULT_REGISTRY_DIR` fior plugin files.
    3.  Finds the section for `<plugin_name>`.
    4.  Clones the plugin's Git repo (specified by `repo` and `commit` in INI) into `$TM_PLUGINS_INSTALL_DIR/<vendor>/<plugin-name>`.
    5.  Attempts to call `tm-plugin-enable <vendor>/<plugin_name>`.

*   **Plugin Enabling (e.g., `tm-plugin-enable <plugin_name>`)**:
    1.  `tm-plugin-enable` script calls `_tm::plugin::enable`.
    2.  `_tm::plugin::enable` creates a symlink from `$TM_PLUGINS_ENABLED_DIR/<plugin_name_or_prefixd_name>` to `$TM_PLUGINS_INSTALL_DIR/<plugin_name>`.
    3.  Calls `_tm::plugin::__generate_wrapper_scripts` to generate wrapper scripts in `$TM_PLUGINS_BIN_DIR` for all commands found in the plugin's `bin/` directory.
    4.  Runs `plugin-requires` and `plugin-enable` scripts from the plugin directory if they exist.
    5.  Calls `_tm::plugins::reload_all_enabled` to refresh the environment.

*   **Plugin Disabling (e.g., `tm-plugin-disable <plugin_name>`)**:
    1.  `tm-plugin-disable` script calls `_tm::plugin::disable`.
    2.  `_tm::plugin::disable` runs `plugin-disable` script from the plugin directory if it exists.
    3.  Removes the symlink from `$TM_PLUGINS_ENABLED_DIR`.
    4.  Calls `_tm::plugins::reload_all_enabled`, which clears and regenerates command wrappers in `$TM_PLUGINS_BIN_DIR`, effectively removing those for the disabled plugin.

*   **Plugin Command Execution**:
    1.  User types a command (e.g., `my-plugin-command`).
    2.  Shell finds the wrapper script `$TM_PLUGINS_BIN_DIR/my-plugin-command`.
    3.  The wrapper script executes:
        *   Sets `TM_PLUGIN_*` environment variables.
        *   Adds the actual plugin's `bin` directory to `PATH`.
        *   Sources the plugin's `.bashrc`.
        *   Executes the original script.

*   **Tool Manager Reload/Update**:
    *   `tm-reload` (likely calls `_tm::boot::reload` from bootstrap): Clears caches, removes plugin scripts from `$TM_PLUGINS_BIN_DIR`, re-runs `__tm_boot_init`, regenerates enabled plugin wrappers, and calls `__tm_boot_load`.
    *   `tm-update-self`: Likely performs a `git pull` in `$TM_HOME` and might trigger a reload.

## 4. Key Design Principles

*   **Modularity**: The entire system is built around plugins.
*   **Convention over Configuration**: Standardized naming and directory structures.
*   **Shell-Native Integration**: Deep integration with Bash.
*   **Configuration via INI Files**: `plugins.ini` for plugin discovery.
*   **Namespacing**: Allows multiple configurations of the same plugin.
*   **Wrapper Scripts for Commands**: Provides isolation and control for plugin commands.
*   **Lifecycle Hooks**: Plugins can define scripts for enable/disable phases.
*   **Centralized Utilities**: Common functions are reused.
*   **Explicit Enable/Disable**: Plugins must be actively enabled.
*   **Git-based Distribution**: Core and plugins are Git repositories.

## 5. System Overview Diagram

```mermaid
graph TD
    subgraph User Shell
        A[~/.bashrc] --> B{TM .bashrc};
    end

    subgraph Tool Manager Core [$TM_HOME]
        B --> C[bin/.tm.boot.sh];
        C --> D{_tm::boot::init};
        C --> E{_tm::boot::load};
        D -- sources --> F[bin/.tm.common.sh];
        D -- sources --> G[bin/.tm.plugin.sh];
        D -- sources --> H[bin/.tm.plugins.sh];
        H -- sources --> I[bin/.tm.util.sh];
        E -- adds to PATH --> J[$TM_BIN (tm-* scripts)];
        E -- adds to PATH --> K[$TM_PLUGINS_BIN_DIR (Wrapper Scripts)];
        E -- calls --> L[_tm::plugins::load_all_enabled];

        subgraph Core Commands [bin/]
            J --> tm_install[tm-plugin-install];
            J --> tm_enable[tm-plugin-enable];
            J --> tm_disable[tm-plugin-disable];
            J --> tm_ls[tm-plugin-ls];
            J --> tm_other[...other tm-* scripts];
        end
    end

    subgraph Plugin Management
        L -- reads --> M[$TM_PLUGINS_ENABLED_DIR (Symlinks)];
        M -- points to --> N[$TM_PLUGINS_INSTALL_DIR/pluginA];
        N --> PABin[pluginA/bin/cmd1];
        L -- for each enabled plugin --> O[_tm::plugin::load];
        O -- sources --> PA_bashrc[pluginA/.bashrc];
        
        tm_install -- uses --> H;
        H -- reads --> Q[plugins.ini];
        Q -- defines --> R{Plugin Metadata (repo, dir, commit)};
        tm_install -- clones git repo to --> N;
        
        tm_enable -- uses --> G;
        G -- creates symlink in --> M;
        G -- creates wrapper in --> K;
        K -- wrapper for cmd1 --> PABin;
    end
    
    UserCommand[User executes 'pluginA-cmd1'] --> K;

    style UserShell fill:#f9f,stroke:#333,stroke-width:2px
    style ToolManagerCore fill:#ccf,stroke:#333,stroke-width:2px
    style PluginManagement fill:#cfc,stroke:#333,stroke-width:2px