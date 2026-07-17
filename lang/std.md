# Standard library

## Defining

```lisp
(defn name args expr)
```
defines a function where `name` is an identifier, `args` is a list of identifier and `expr` is the expression executed
by the function.

```lisp
(lambda args expr)
```
returns an anonymous function with `args` a list of identifier and `expr` an expression.

```lisp
(type a)
```
returns the type of `a`.

```lisp
(boolean a)
(string a)
(number a)
```
converts `a` to another type.

```lisp
(set name value)
```
sets a variable.

```lisp
(export var1 var2...)
```
exports `var1`, `var2`...

## Integers and booleans operators
```lisp
(+ a b)
(- a b)
(* a b)
(/ a b)
(% a b)
(pow a b)
```
are the mathematical operators.

```lisp
(= a b)
(> a b)
(< a b)
(>= a b)
(<= a b)
```
are the mathematical comparison operators.

```lisp
(and a b)
(or a b)
(not a b)
(nor a b)
(nand a b)
(xor a b)
```
are the logical operators.

```lisp
(| a b)
(& a b)
(^ a b)
(~ a b)
(<< a b)
(>> a b)
```
are the bitwise operators.

## Control flow

```lisp
(if cond a b)
```
executes `a` if `(= cond true)` or b otherwise.

```lisp
(check cond a)
```
executes `a` if `(= cond true)`.
It is equivalent to `(if cond a ())`.

```lisp
(case value [cond expression])
```
executes the `expression` if `(= (cond $value) true)`.

```lisp
(do exprs)
```
executes multiple expressions where `exprs` is a list of expressions.

## Lists and strings
```lisp
(append a b)
```
appends `b` to `a`.

```lisp
(prepend a b)
```
prepends `b` to `a`.

```lisp
(head a)
```
returns the first element of `a`.

```lisp
(tail a)
```
returns every element after the first one.

```lisp
(get i a)
```
returns the `i`th element of `a`.
It is more idiomatic to use `head` and `tail`.

```lisp
(len a)
```
returns the length of `a`.

```lisp
(empty? a)
```
returns `true` if a is empty.
It is equivalent to `(= (len a) 0)`.

```lisp
(map a b)
```
returns `a` mapped with `b`.

```lisp
(reduce l acc r)
```
returns `l` reduced to `acc` with `r`.

```lisp
(join a b)
```
returns `a` joined with `b`.

```lisp
(reverse a)
```
returns `a` reversed.

## Stdin, stdout and stderr
```lisp
(| a b)
(< a b)
(> a b)
(>> a b)
```
are the equivalent of `a | b`, `a < b`, `a > b` and `a >> b` in POSIX Shell.
`<<` is useless, because
```lisp
cat "Hello
world"
```
is valid.

```lisp
$stdout
$stderr
```
contains the content of the linked `/dev/std{out,err}`.

```
$?
$status
```
contains the exit code of the last expression executed.

```lisp
(> $stderr $stdout)
```
is equivalent to `2>&1` in POSIX Shell.

## Files
```lisp
(exists? a)
```
returns `true` if the path `a` exists.

```lisp
(kind a)
```
returns the kind of path `a` (file, folder, socket, pipe...).
