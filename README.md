# Tool Manager (tm)

**Tool Manager (tm)** is a lightweight framework for managing collections of Bash shell tools and plugins.  
Think of it as a *package manager for your shell scripts*: it installs, updates, and isolates command-line tools so you can focus on using them—not setting them up.

---

## Why Use Tool Manager?
Developers often accumulate many shell scripts or small CLI tools over time. Tool Manager helps by addressing several common pain points:

- **Centralized Installation**  
  Instead of manually cloning repositories or copying scripts, you can install new tools with a single command. 
  For example, running `tm-plugin-install <vendor>/<tool-name>` will fetch and set up a tool plugin for you.
  This saves time and ensures a consistent install process for any machine.


- **Easy Enable/Disable**  
  Tool Manager lets you enable or disable plugins on demand. This means your shell isn’t cluttered with 
  commands you don’t need – you can turn tools on only when needed and keep others disabled. 
  The system **manages plugins** and can quickly toggle them without manual PATH juggling.

 
- **Isolated Environments**  
  To avoid conflicts between tools, Tool Manager can (now or in the future) run plugins in isolated contexts (like separate containers or virtual environments). 
  This isolation ensures that one tool’s requirements won’t break another’s environment.


- **Multiple Contexts (Prefixes)**  
  If you need the same tool in different configurations (for example, a personal vs. work setup),
  you can install it under distinct prefixes. Tool Manager supports prefixing plugin names (e.g. `my:git-tools` vs `work:git-tools`) 
  so that each has its own config but shares the same code base.
  This solves the issue of **conflicting configurations** by cleanly separating contexts.


- **Dependency Management**  
  A major headache with scripts is managing their dependencies (like Python packages or other binaries). Tool Manager automates this. 
  You can declare dependencies in your script (using special `@require` comments), and Tool Manager will automatically set up a Python virtual environment and install those packages when the tool is run.
  This means no more “it works on my machine” problems due to missing libraries – the required packages are pulled in for you.


- **Discoverability and Updates**  
  Tool Manager keeps track of what plugins are available, installed, or enabled. You can list all available plugins (from its plugin registry or known sources) or see which ones you’ve installed with simple commands.
  This makes it easy to discover new tools and ensure your toolkit is up to date. It also streamlines updates (you could update a plugin by reinstalling or pulling latest changes in its directory, under Tool Manager’s control).


By solving these issues, Tool Manager makes it much easier to maintain a robust set of shell tools, share them with others, and keep your environment clean and consistent.

---

## Key Features
Tool Manager provides a number of features that deliver the above benefits:

- **Unified Command Prefix**  
  All Tool Manager commands and managed tools start with the prefix `tm-`. This means you can type `tm-` and press tab to see available actions, making discovery intuitive.
  For example, `tm-help-commands` will list all tool commands you have installed.
  This consistent naming prevents naming collisions with other system commands and groups plugin actions together for convenience.


- **Plugin Life-Cycle Commands**  
  It offers an array of commands to manage plugin *life cycle*. You can install plugins from remote sources (GitHub by default) using `tm-plugin-install`, 
  edit plugin files (`tm-plugin-edit` opens the installation directory), reload plugins (`tm-reload` regenerates the shell wrappers for tools), and configure plugins (`tm-plugin-cfg` opens their config).
  These commands abstract the fiddly steps of managing script files and shell initialization. For instance, after adding a new script to a plugin, running tm-reload will regenerate wrapper scripts so that the tool is immediately available in your PATH with the correct environment.


- **Flexible Installation Sources**  
  Pull plugins from the public registry, GitHub (`user/repo`), or any Git URL.
  If the tool you want isn’t in the default registry, that’s fine – Tool Manager will try to fetch it from GitHub by convention, or you can point it to any Git repository URL. 
  The tool infers the plugin name and vendor from the URL, so you aren’t limited to a predefined list of plugins. This flexibility means you can install any script repository as a plugin, whether it’s one of the officially known plugins or your own custom repo.


- **Automatic Dependency Provisioning**  
  Tool Manager can automatically handle dependencies for scripts, particularly Python ones. By adding lines like `# @require:python 3.12` or `# @require:pip <package>` in the script, you signal Tool Manager to set up the appropriate Python version and pip packages in an isolated virtual environment.
  The next time you run the script, it will launch with those dependencies available, without you manually creating a virtualenv or installing packages globally. Support for other runtimes (Node, Deno, Java, etc.) is in the works, extending this convenience to tools written in other languages.


- **Plugin Registry and Listings**  
  Tool Manager comes with a plugin registry (a catalog of known tool plugins) which it uses for installations and listings.
  By running commands like `tm-plugin-ls --available` or `tm-plugin-ls --installed`, you get a quick overview of what tools you can add or what you already have. This feature helps you discover new productivity tools and manage existing ones without digging through folders.

All these features work together so that adding a new bash tool or sharing your custom script with teammates becomes a frictionless process. In short, Tool Manager abstracts away the setup chores and lets you focus on using or developing the tools.

---

## Typical Usage Scenarios

### 1. Installing an Open-Source Toolkit
```bash
# Add a set of Git helper scripts published on GitHub
tm-plugin-install codemucker/git-tools
# Now commands like `git-each` are ready to use
```

### 2. Separating Work & Personal Configs
```bash
# Install the same plugin twice with different prefixes
tm-plugin-install work:codemucker/git-tools
tm-plugin-install personal:codemucker/git-tools

# Use work-scoped commands
work-git-each ...

# Use personal-scoped commands
personal-git-each ...
```

### 3. Sharing Internal Dev Tools
```bash
# Teammate onboarding
tm-plugin-install yourcompany/internal-dev-tools
# Dependencies are auto-installed; everyone has the same setup
```

### 4. Automatic Python Env for a Script
Inside myscript.sh:
```bash
# @require:python 3.12
# @require:pip requests
```
Run myscript — Tool Manager silently provisions Python 3.12 + requests in an isolated virtualenv.

# Installation

```bash
curl -s "https://raw.githubusercontent.com/codemucker/tool-manager/refs/heads/main/install.sh" | bash
```

or for a given version

```bash
curl -s  https://raw.githubusercontent.com/codemucker/tool-manager/refs/tags/0.0.1/install.sh | bash
```

alternatively, clone this repo to `$HOME/.tool-manager` (or wherever you like) , and add the following to your `$HOME/.bashrc`

```bash
if [[ -f "$HOME/.tool-manager/.bashrc" ]]; then
  source "$HOME/.tool-manager/.bashrc"
fi
```
then either create a new shell or source the `$HOME/.tool-manager/.bashrc` to have it available in your shell

All the tool-manager commands start with `tm-`, so you can just type `tm-` and TAB, for auto complete

For all the tool commands installed, run `tm-help-commands` or `tm-help-commands-gui`

# Installing plugins

```bash
tm-plugin-install <name-of-plugin>                # you can pass -h or --help for options.
tm-plugin-install --vendor codemucker git-tools
tm-plugin-install codemucker/git-tools            # same as above
tm-plugin-install my:codemucker/git-tools         # will prefix 'my-' on all the git tools scripts
tm-plugin-install --prefix my --vendor codemucker --name git-tools # same as above
tm-plugin-install my:codemucker/git-tools@main    # will install from the main branch
```
The 'prefix' is so that you can have the same plugin used in different contexts, say a 'my-git-each' and 'work-git-each', 
with separate config, but the same codebase

If there is no plugin with the name in any of the plugin registry files, it will default with trying to install from github, using the form:

```
git@github.com:<vendor>/<plugin-name>.git
```

or you can install using a git url

```bash
tm-plugin-install <url-of-git-repo>
```

where the vendor name and plugin name will be auto extracted.

You can also have it list the available plugins, by providing no name and hit enter, it will show the list of available plugins

For the default available plugins, run:

```bash
tm-plugin-ls --help
tm-plugin-ls --available
tm-plugin-ls --installed
tm-plugin-ls --enabled
tm-plugin-ls --enabled --format plain
```

If you are developing plugins, you can call:

```bash
tm-edit <plugin-name> #(you can pass -h or --help for options)
```

or

```bash
tm-edit 
```
to get to the top plugin install dir

If you add any new plugin scripts, you will need to call 

```bash
tm-reload     # reloads all plugins
tm-reload <my-plugin> # reload just the given plugin (regen the wrapper scripts)
tm-reload <my-plugin> -f # force reload just the given plugin (disabled, then re-enables it)
```

for the wrapper scripts to be generated. This ensures your script env is set up
before invoking your real script.

To edit the plugin config, run:

```bash
tm-plugin-cfg # base config dir
tm-plugin-cfg codemucker/git-tools # config for the given plugin
tm-plugin-cfg my:codemucker/git-tools # config for the given plugin
```

# Dependencies

There is support for automatic python env provisioning, using either a python venv or a uv env. All you need to do is add '@require' directives
to your python scripts:

```python
#!/usr/bin/env tm-env-python        # note the shebang line. Required for now, but later we might not need it

# @require:venv     script          # none|script|plugin. 'Script' means one env just for this script, 'plugin' for a shared env for this plugin
# @require:python   3.12            # version of python to use. Notice how comments after directives are allowed
# @require:pip      tk              # a pip dependency
# @require:pip      ttkbootstrap    # another pip dependency
```

Support for node/deno/bash/java/kotlin etc dependencies is under development

Your script can end in '.py' or not. It will appear in your path without the extension

# Design

see [OVERVIEW.md](./docs/OVERVIEW.md)

# Contributing
Pull requests are welcome! Feel free to open issues for feature requests or bug reports.
For larger contributions, please discuss the idea first to ensure it aligns with the project roadmap.

# License
This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
