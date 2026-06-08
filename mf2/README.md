# tolke_mf2

[![Package Version](https://img.shields.io/hexpm/v/tolke_mf2)](https://hex.pm/packages/tolke_mf2)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/tolke_mf2/)

## Summary

A `ICU MessageFormat 2`–inspired library for `tolke`, loosely based on the MessageFormat TypeScript implementation, but not intended to be a reference implementation or strict conformant to any `ICU` or `MessageFormat 2` specification, and may diverge in semantics and behaviour as needed for design and runtime purposes. Specifically, it does not perform "locale" formatting (numbers, dates etc), but focuses on text only translations.

## Development

```bash
gleam test
```
