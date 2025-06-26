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
then either create a new shell or source the '$HOME/.tool-manager/.bashrc' to have ti available in your shell

All the tool-manager commands start with 'tm-', so you can just type 'tm-' and TAB, for auto complete

For all the tool commands installed, run 'tm-help-commands' or 'tm-help-commands-gui'


# installing plugins

```bash
tm-plugin-install <name-of-plugin>
```

or

```bash
tm-plugin-install <url-of-git-repo>
```

If you provide no name, and hit enter, it will show the list of available plugins

For the default available plugins, run:

```bash
tm-plugin-ls --help
```

If you are developing plugins, you can call:

```bash
tm-edit <plugin-name>
```

or

```bash
tm-edit 
```
to get to the top plugin install dir

If you add any new plugin scripts, you will need to call 'tm-reload' for the wrapper scripts to be generated. These ensure your script env is setup
before invoking your real script

# Design

see [OVERVIEW.md](./docs/OVERVIEW.md)
