# Tool Manager (tm)


Manages a set of Bash tools/plugins.

This can install and enable/disable various plugins, and potentially run them in isolated containers.

See the various 'tm-' commands. E.g. 'tm-help-gui'

# Installation

```bash
curl -s "https://github.com/codemucker/tool-manager/blob/main/install.sh" | bash
```

# install plugins

```bash
tm-plugin-install <name-of-plugin>
```

If you provide no name, and hit enter, it will show the list of available plugins


# Design

see [OVERVIEW.md](./docs/OVERVIEW.md)
