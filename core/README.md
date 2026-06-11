# tolke

[![BSD 3 Clause License](https://img.shields.io/github/license/nigeleke/tolke?style=plastic)](https://github.com/nigeleke/tolke/blob/master/LICENSE)
[![Language](https://img.shields.io/badge/language-Gleam-blue.svg?style=plastic)](https://gleam.run/)
[![Package Version](https://img.shields.io/hexpm/v/tolke)](https://hex.pm/packages/tolke)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/tolke/)


## Background

This program reads internationalisation files written in ICU MessageFormat 2.0 and processes them as structured input. It parses the message definitions and checks them for consistency and correctness, including issues such as missing variables, mismatched parameters, and invalid or inconsistent formatting patterns.

It then generates Gleam code from these message files as a pre-build projection of the MF2 messages, so that they can be used directly in the application code. This removes the need for runtime string lookups or manual formatting and makes message usage explicit and statically checked where possible. The overall purpose is to move internationalisation handling into the build process and provide a more reliable interface between translation data and application code.

So the entry

```mf2
hello-world := Hello {$name}
```

will create a locale bundled equivalent (see usage) for:

```gleam
pub fn hello_world(name: String) -> String {...}
```

The name `tolke` is Danish / Norwegian for "interpret".

Further documentation can be found at <https://hexdocs.pm/tolke>.
