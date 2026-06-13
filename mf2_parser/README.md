# mf2_parser

## Summary

A parser for the `ICU MessageFormat 2` grammar as specified in the `Unicode MessageFormat Working Group` 
(specification)[https://github.com/unicode-org/message-format-wg/blob/main/spec/message.abnf], producing
a structured AST with diagnostic (issue) annotations, intended for use within `tolke` and not guaranteed
to be fully conformant to any reference implementation or evolving standard.

## Development

```bash
gleam test
```
