# tolke

[![BSD 3 Clause License](https://img.shields.io/github/license/nigeleke/tolke?style=plastic)](https://github.com/nigeleke/tolke/blob/master/LICENSE)
[![Language](https://img.shields.io/badge/language-Gleam-blue.svg?style=plastic)](https://gleam.run/)
[![Package Version](https://img.shields.io/hexpm/v/tolke)](https://hex.pm/packages/tolke)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/tolke/)

## Background

This `tolke` respository is a set of [Gleam](https://gleam.run) packages to enable internationalisation in client programs.

The primary program is designed to run as part of a build pipeline, which will read and check locale resource files, then generate source code for formatting the messages in one of the locales.

## Usage

### data files - folder structure

`tolke` will look at all files under configured folders, determining the locale of the content from the file path, e.g.:

```bash
i18n/
  en-GB.mf2
  it-IT.mf2
```

```bash
i18n/
  en/
    en-GB/
      foo_component.mf2
      app_errors.mf2
      etc
    en-US/
      etc
  fr/
    fr-FR/
      etc
    fr-CA/
      etc
  etc
```

### data files - content

A list of key / message format 2 messages.

```mf2
app-title = My App
hello := Hello {$name} !!
```

### generate code

```bash
gleam add --dev tolke_dev_tools
gleam run -m tolke/dev
```

### gleam.toml

```toml
[tools.tolke]
mf2_sources = ["./i18n/"]
canonical = "en-GB"
primaries = []
target = "./src/generated/tolke"
```

### use translations

```gleam
import tolke as t

pub fn main() {
  let i18n = t.bundle()

  assert i18n |> t.app_title() == "My App"
  assert i18n |> t.hello("World") == "Hello World !!"
}
```

## Development

### mise 

```bash
mise build
mise test
```

### non mise

```bash
cd dev
gleam run --module __TODO__
```

```bash
cd dev_tools
gleam test
gleam build
```

### packages

| Package          | Description |
|------------------|-------------|
| `build_pipeline` | Part of `tolke`'s internal build pipeline |
| `dev_test`       | Part of `tolke`'s internal testing framework |
| `dev_tools`      | The `tolke development tooling` for clients of `tolke` |
| `mf2_parser`     | A parser for [MessageFormat 2](https://messageformat.unicode.org/) messages |
| `mf2`            | A formatter for [MessageFormat 2](https://messageformat.unicode.org/) messages |
