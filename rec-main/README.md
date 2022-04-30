# Factorial with a recursive main routine

Originated as a joke, since we wondered if it is possible to write an implementation of factorial that has no subroutines alongside the main routine. It is.

When x86 programs assembled by `gcc` are called from the command-line, `argc` (the argument count) is contained in the `%rdi` register. The main routine recursively calls itself, while decrementing `%rdi` on each subsequent call.

Written in x86 assembly with AT&T syntax. I do not remember if it obeys any calling conventions.

# Assembly

``` sh
gcc -no-pie -o fact.out fact.s
./fact.out
```

# Usage

The usage is ridiculous, as the way to pass the argument to the factorial function is through the number of arguments:

``` sh
[ ~ ]$ ./fact.out two three four five six seven
0! = 1
1! = 1
2! = 2
3! = 6
4! = 24
5! = 120
6! = 720
7! = 5040
```

Or you could generate some dummy arguments with `yes` and pass them with `xargs`:

``` sh
[ ~ ]$ yes | head -n 6 | xargs ./fact.out
0! = 1
1! = 1
2! = 2
3! = 6
4! = 24
5! = 120
6! = 720
7! = 5040
```

