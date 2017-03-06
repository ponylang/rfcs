- Feature Name: cli-syntax
- Start Date: 2016-10-24
- RFC PR:
- Pony Issue: https://github.com/ponylang/ponyc/issues/471

# Summary

Provide a standard command line argument syntax for Pony tools and other programs, and a corresponding package to be provided in the standard library.


# Motivation

Having a standard syntax for command line arguments and options will make  Pony command line programs more consistent and thus easier to learn and use by users. Having a standard library package that provides this implementation will make writing conformant programs easier for Pony programmers.


# Detailed design

## Grammar

Command lines are broken up into a series of tokens before they are delivered to a program as an array of strings. There are a number of ways to treat those tokens, but most Unix-like environments have settled on a syntax that combines commands, arguments and flags. The GNU C library doc is a good reference for how the flags or options should be handled:

- http://www.gnu.org/software/libc/manual/html_node/Argument-Syntax.html

Flags are usually enough for simple programs, but more often it is desirable to have a richer grammar with library support for parsing sub-commands and positional arguments in addition to the flags. It's nice not to rewrite that logic everytime, and not to force users to learn different command line syntax for every program they use.

In the Golang world, the Flags in the standard library are fairly weak and not Posix compliant, so a couple of packages have become very popular extensions. The most interesting ones are Kingpin and mow.cli, which present nice interfaces to the programmer and consistent grammars to the program user:

 - https://github.com/alecthomas/kingpin
 - https://github.com/jawher/mow.cli

The command line is treated as a command with optional flags and positional arguments. The command is composed of the root command which represents the program, plus zero or more subcommands. Each leaf command may specify required and optional arguments. And, each command may specify required or optional flags which add to those inherited from its parent.

The general EBNF of a command line looks like:
```
  command_line ::= root_command (flag | command)* (flag | arg)*
  command ::= alphanum_word
  alphanum_word ::= alphachar(alphachar | numchar | '_' | '-')*
  flag ::= longflag | shortflagset
  longflag ::= '--'alphanum_word['='arg | ' 'arg]
  shortflagset := '-'alphachar[alphachar]...['='arg | ' 'arg]
  arg := boolarg | intarg | floatarg | stringarg
  boolarg := 'true' | 'false'
  intarg := ['-'] numchar...
  floatarg ::= ['-'] numchar... ['.' numchar...]
  stringarg ::= anychar
```

## Rules

Another way to describe how command lines are parsed into commands, flags and arguments, is with the following rules.

##### Rule 1
A token consisting of a single hyphen only, `-`, is not a flag.

##### Rule 2
A token that starts with one (but not two) hyphens `-` is a set of one or more short flags, each of which is a single alpha character. Like: `-o`.

##### Rule 3
Multiple short flags may be folded together in a single token, if those flags don't take arguments. So `-abc` is equivalent to `-a -b -c`.

##### Rule 4
A token that starts with 2 hyphens `--` is a single long flag, which must contain only alphanumeric characters, underscores and hyphens. Like: `--data_rate`.

##### Rule 5
Any given flag may take an argument, which may be required or optional. If the argument is required, such an argument not being present is an error.

##### Rule 6
A required argument for a short flag may be specified as the remainder of the token containing the flag. For example in `-ofoo` the flag `o` has the value `foo`. (This form is only allowed for required arguments since there is no way to tell if the `f` in that example is the start of the argument or the next flag.)

##### Rule 7
An argument for a short or long flag may be specified with an `=` between the flag name and the argument. For example, in `--foo=bar` the flag `foo` has the argument `bar`.

##### Rule 8
A required argument for a short or long flag may be provided as the entire following token, even if the token starts with one or more hyphens. Thus `-o -foo` means that flag `o` has the argument `-foo`.


##### Rule 9
A token consisting of exactly two hyphens, `--`, ends flag processing. All following tokens are interpreted as arguments. Note that rule 8 implies that the `--` may actually be an argument and hence not end processing. For example, given the tokens `-o -- -p`, if the flag `o` requires an argument then that argument is `--` and `-p` is processed as the next flag. However, if the flag `o` does not require an argument then `--` ends flag processing and `-p` is not processed as a flag.

##### Rule 10
Flags may appear in any order and may appear more than once. Subsequent appearances overwrite previous ones.


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
  - The resulting parsed command, flag and arg classes.

Pony programs use constructors to create the spec objects for their command line syntax. This spec is checked for correctness at compile time, and represents everything the library needs to know when parsing a command line or displaying syntax help messages.

Programs then use this spec at runtime to parse any given command line. This is often `env.args()`, but could also be commands from files or other input sources. The result of a parse is either a parsed command, or a syntax error.

Programs then query the parsed command to determine the (sub) command specified, and the effective values for all flags and arguments.


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

A simpler flag parser.


# Unresolved questions

Can parsing of environment variables be included?
