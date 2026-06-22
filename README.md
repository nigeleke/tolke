# tolke

[![BSD 3 Clause License](https://img.shields.io/github/license/nigeleke/tolke?style=plastic)](https://github.com/nigeleke/tolke/blob/master/LICENSE)
[![Language](https://img.shields.io/badge/language-Gleam-blue.svg?style=plastic)](https://gleam.run/)
[![Package Version](https://img.shields.io/hexpm/v/tolke)](https://hex.pm/packages/tolke)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/tolke/)

## Background

This `tolke` respository is a set of [Gleam](https://gleam.run) packages to enable internationalisation in client programs.

The primary program is designed to run as part of a build pipeline, which will read and check locale resource files, then generate source code for formatting the messages in one of the locales.

## Terminology

A _Canonical_ locale _document_ is the master against which all other _documents_ are compared.

_Primary_ locale _documents_ are _documents_ in other locales that provide their translations 
from the _Canonical_ _document_.

_Variant_ locale _documents_ are _documents_ using the same _language root_ as a _Canonical_ or
_Primary_ _document_, but have different _regions_.

A "_locale_" _document_ is formed from multiple files within the _sources_ paths (Gleam.toml [tools.tolke]).

The _locale_ of a mf2 file is determined from path naming. If the file name is a locale
(e.g. `./i18n/en-GB.mf2`, or `./i18n/errors/en-GB.mf2`) then that will be deemed the locale
of its contents. If the file name is more descriptive (e.g. `./i18n/en/en-GB/errors.mf2`),
then its locale will be deemed to be the first parent segment which represents a valid
locale according to BCP 47. In the example's case this is `en-GB`, not `en`.

__Note: A name such as `./i18n/en/en-GB/fr.mf2` will be deemed `french (fr)`, which may not be as intended.__

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

`dev_tools` is the key package here.
