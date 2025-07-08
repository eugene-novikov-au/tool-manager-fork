# Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## Running Tests

The project uses [ShellCheck](https://www.shellcheck.net/) and [Bats](https://github.com/bats-core/bats-core) for basic testing.
To run the checks locally:

```bash
sudo apt-get update
sudo apt-get install -y shellcheck bats

shellcheck bin/*.sh bin-internal/*.sh
bats tests
```
