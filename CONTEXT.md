# Gleam parser language

A parser and formatter for Gleam source text, with the compiler's AST and
lossless tokens.

## Language rules

**Keyword**: One of the compiler's grammar words, such as `fn` or `echo`.

**Reserved keyword**: A keyword that a dialect excludes from ordinary names.
A dialect can reserve a subset of the compiler's keywords.

## Source coordinates

**Byte offset**: A zero-based position measured in UTF-8 bytes. A byte offset
can identify the end of a source, and need not be a character boundary.

**UTF-16 offset**: A zero-based position measured in UTF-16 code units.
A UTF-16 offset is distinct from a byte offset.

**Source span**: A half-open range of byte offsets. The start belongs to the
range. The end does not. An empty span has equal endpoints.

**Compiler EOF location**: The compiler's `start..0` location for an error
whose inner error reached the end of the source. At zero, this has the same
representation as an empty source span.

**Source position**: A one-based line number and column number. Columns
count Unicode code points. CRLF and a lone CR each end one line.

**Line count**: The number of lines in a source. Even an empty source has
one line.

## AST and traversal values

**Tuple index**: A zero-based tuple element index in the compiler's full
unsigned 64-bit range.

**Bit array unit**: The compiler AST's byte-sized unit value, from 0 to 255.
Gleam source syntax accepts units from 1 to 255.

**Child index**: A zero-based index within one named field of a node.
A field with one child uses index zero.

**Node depth**: The number of parent edges from a traversal's start node.
The start node has depth zero.

## Nesting policy

**Nesting limit**: A caller policy that is either unlimited or has a finite
budget. It does not depend on the target's machine stack size.

**Nesting budget**: A positive maximum number of syntax operations that can
be open at the same time. An operation returns its unit when it closes.
