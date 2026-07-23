# Selene XAML CLI

The native `selene-xaml` command compiles XAML and a typed business contract
into generated MoonBit source. Generated source is checked into the consuming
project and compiled together with the rest of the application.

## Run from a source checkout

Install the native executable from a Selene XAML source checkout:

```bash
moon install ./src/cmd/selene-xaml
```

For repository-local development, invoke it through Moon without installing:

```bash
moon run src/cmd/selene-xaml --target native -- <command>
```

## Commands

| Command | Purpose |
| --- | --- |
| [`generate`](generate.md) | Generate an Embedded View package from `.mbti`. |

The current CLI exposes only `generate`.

## Global options

```mooncram
$ selene-xaml --version
selene-xaml 0.1.0
```

```mooncram
$ selene-xaml --help
Usage: selene-xaml <command>

Compile Selene XAML into typed MoonBit View packages.

Commands:
  generate  Generate an Embedded View package.

Options:
  -h, --help     Show help information.
  -V, --version  Show version information.
```

## Process contract

Successful commands write a short result summary to stdout. Diagnostics are
written to stderr, and a failed command exits with a non-zero status. A failed
generation leaves an existing output package unchanged.

```mooncram {output_stream: stderr}
$ selene-xaml
error: the following required argument was not provided: 'subcommand'

Usage: selene-xaml <command>

Compile Selene XAML into typed MoonBit View packages.

Commands:
  generate  Generate an Embedded View package.

Options:
  -h, --help     Show help information.
  -V, --version  Show version information.
[1]
```

Registry distribution is planned but is not currently part of the published
CLI workflow. Compiler architecture, artifact ownership, determinism, and
diagnostic source mapping are specified separately in
[Generate Command](../engineering/generate-view.md).
