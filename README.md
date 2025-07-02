# Tool Manager (tm)


Manages a set of Bash tools/plugins.

This can install and enable/disable various plugins, and potentially run them in isolated containers.

See the various 'tm-' commands. E.g. 'tm-help-gui'

# Installation

```bash
curl -s "https://raw.githubusercontent.com/codemucker/tool-manager/refs/heads/main/install.sh" | bash
```

or for a given version

```bash
curl -s  https://raw.githubusercontent.com/codemucker/tool-manager/refs/tags/0.0.1/install.sh | bash
```

alternatively, clone this repo to '$HOME/.tool-manager' (or wherever you like) , and add the following to your "$HOME/.bashrc"

```bash
if [[ -f "$HOME/.tool-manager/.bashrc" ]]; then
  source "$HOME/.tool-manager/.bashrc"
fi
```
then either create a new shell or source the '$HOME/.tool-manager/.bashrc' to have it available in your shell

All the tool-manager commands start with 'tm-', so you can just type 'tm-' and TAB, for auto complete

For all the tool commands installed, run 'tm-help-commands' or 'tm-help-commands-gui'

# Installing plugins

```bash
tm-plugin-install <name-of-plugin>                #(you can pass -h or --help for options)
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
tm-plugin-edit <plugin-name> #(you can pass -h or --help for options)
```

or

```bash
tm-plugin-edit 
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
