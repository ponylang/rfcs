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

Flags are usually enough for simple programs, but more often it is desirable to have consistent grammar and library support for parsing sub-commands and positional arguments in addition to the flags. It's nice not to have to rewrite that logic in every program, and not to force users to learn different command line syntax for every program they use.

In the Golang world, the Flags in the standard library are fairly weak and not posix compliant, so a couple of packages have become very popular extensions. The most interesting one is Kingpin, which presents a nice interface to the programmer and a consistent grammar to the program user:

 - https://github.com/alecthomas/kingpin

The command line is treated as a command with optional flags and positional arguments. The command is composed of the root command which represents the program, plus zero or more subcommand tokens. Each leaf command may specify required and optional arguments. And, each command may specify required or optional flags which add to those inherited from its parent.

The general EBNF of a command line looks like:
```
  command_line ::= root_command (flag* command*)* (flag | arg)*
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

Some Examples:
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

Pony programs use a builder pattern to create the spec for their command line syntax. This spec is checked for correctness at compile time, and represents everything the library needs to know when parsing a command line or displaying syntax help messages.

Programs then use this spec at runtime to parse any given command line. This is often `env.args()`, but could also be commands from files or other input sources. The result of a parse is either a parsed command, or a syntax error.

Programs then query the parsed command to determine the (sub) command specified, and the effective values for all flags and arguments.


# How We Teach This

The CLI package would have reference doc for all of the types like any other library package. We would also update existing tools to use this grammar and library when possible to serve as examples. Other types of doc should be written such as patterns and examples.


# How We Test This

A complete unit test suite should be written to validate the implementation of this RFC.


# Drawbacks

This complete CLI library may be overkill for small tools.


# Alternatives

A simpler flag parser.


# Unresolved questions

Can parsing of environment variables be included?
