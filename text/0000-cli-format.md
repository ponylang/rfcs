- Feature Name: cli-syntax
- Start Date: 2016-10-24
- RFC PR:
- Pony Issue: https://github.com/ponylang/ponyc/issues/471

# Summary

Provide a standard command line argument syntax for Pony tools and other programs, and a corresponding package to be provided in the standard library.


# Motivation

Having a standard syntax for command line arguments and options will make Pony command line programs more consistent and thus easier to learn and use by users. Having a standard library package that provides this implementation will make writing conformant programs easier for Pony programmers.


# Detailed design

## Grammar

Command lines are broken up into a series of tokens before they are delivered to a program as an array of strings. There are a number of ways to treat those tokens, but most Unix-like environments have settled on a syntax that combines commands, arguments and options. The GNU C library doc is a good reference for how the options should be handled:

- http://www.gnu.org/software/libc/manual/html_node/Argument-Syntax.html

Options are usually enough for simple programs, but more often it is desirable to have a richer grammar with library support for parsing sub-commands and positional arguments in addition to the options. It's nice not to have to rewrite that logic every time, and not to force users to learn a different command line syntax for every program they use.

In the Golang world, the Flags in the standard library are fairly weak and not Posix compliant, so a couple of packages have become very popular extensions. The most interesting ones are Kingpin and mow.cli, which present nice interfaces to the programmer and consistent grammars to the program user:

 - https://github.com/alecthomas/kingpin
 - https://github.com/jawher/mow.cli

The command line is treated as a command with options and positional arguments. The command is composed of the root command which represents the program, plus zero or more subcommands. Each leaf command may specify required and optional arguments. And, each command may specify required or optional options which add to those inherited from its parent.

The general EBNF of a command line looks like:
```
  command_line ::= root_command (option | command)* (option | arg)*
  command ::= alphanum_word
  alphanum_word ::= alphachar(alphachar | numchar | '_' | '-')*
  option ::= longoption | shortoptionset
  longoption ::= '--'alphanum_word['='arg | ' 'arg]
  shortoptionset := '-'alphachar[alphachar]...['='arg | ' 'arg]
  arg := boolarg | intarg | floatarg | stringarg
  boolarg := 'true' | 'false'
  intarg := ['-'] numchar...
  floatarg ::= ['-'] numchar... ['.' numchar...]
  stringarg ::= anychar
```

## Rules

Another way to describe how command lines are parsed into commands, options and arguments, is with the following rules.

##### Rule 1
A token consisting of a single hyphen only, `-`, is not an option.

##### Rule 2
A token that starts with one (but not two) hyphens `-` is a set of one or more short options, each of which is a single alpha character. Like: `-O`.

##### Rule 3
Multiple short options may be folded together in a single token as long as those options don't take arguments. So `-abc` is equivalent to `-a -b -c`.

##### Rule 4
A token that starts with 2 hyphens `--` is a single long option, which must contain only alphanumeric characters, underscores and hyphens. Like: `--data_rate`.

##### Rule 5
Arguments for option types other than Bool are required. Bool options (aka flags) default to a 'true' argument if none is supplied. Thus, `-F` is the same as `-F=true`.

##### Rule 6
A required argument for a short option may be specified as the remainder of the token containing the option. For example in `-Ofoo` the option `O` has the value `foo`. (This form is only allowed for required arguments since there is no way to tell if the `O` in that example is the start of the argument or the next option.)

##### Rule 7
An argument for a short or long option may be specified with an `=` between the option name and the argument. For example, in `--foo=bar` the option `foo` has the argument `bar`.

##### Rule 8
A required argument for a short or long option may be provided as the entire following token, even if the token starts with one or more hyphens. Thus `-O -foo` means that option `O` has the argument `-foo`.


##### Rule 9
A token consisting of exactly two hyphens, `--`, ends option processing. All following tokens are interpreted as arguments. Note that rule 8 implies that the `--` may actually be an argument and hence not end processing. For example, given the tokens `-O -- -p`, if the option `O` requires an argument then that argument is `--` and `-p` is processed as the next option. However, if the option `O` does not require an argument then `--` ends option processing and `-p` is not processed as an option.

##### Rule 10
Options may appear in any order and may appear more than once. Subsequent appearances overwrite previous ones.

##### Rule 11
Option may be specified as being required. Such options not being present is an error.


## Examples

```
  tool action --switch1 --option2=42 sub_action -o 9 arg1 arg2
  chat --channel=main say hello
  chat handle fred --email=fred@com.com
```

## Library

The types in the CLI package are broken down into three groups:

  - The spec classes and primitives which are used to declare a CLI grammar.
  - The parser class which is used to parse a command line against a spec.
  - The resulting parsed command, option and arg classes.

### Specs

Pony programs use constructors to create the spec objects for their command line syntax. This spec is checked for correctness at compile time, and represents everything the library needs to know when parsing a command line or displaying syntax help messages.

### Parser

Programs then use this spec at runtime to parse any given command line. This is often `env.args()`, but could also be commands from files or other input sources. The result of a parse is either a parsed command, or a syntax error.

### Commands

Programs then query the parsed command to determine the (sub) command specified, and the effective values for all options and arguments.


# How We Teach This

The CLI package would have reference doc for all of the types like any other library package.

The following existing tools will need to be updated to use this new package in leu of Options:
  - `packages/stdlib/_test.pony`

And these examples will need to be updated in the same way:
  - `examples/printargs/printargs.pony`
  - `examples/mandelbrot/mandelbrot.pony`
  - `examples/gups_basic/main.pony`
  - `examples/gups_opt/main.pony`
  - `examples/yield/main.pony`
  - `examples/httpget/httpget.pony`

A new section should be added to the Tutorial that goes into more detail on command line handling in general, and the use of this library specifically.


# How We Test This

A complete unit test suite should be written to validate the implementation of this RFC.


# Drawbacks

This complete CLI library may be overkill for small tools.


# Alternatives

A simpler options parser.


# Unresolved questions

Can parsing of environment variables be included?
