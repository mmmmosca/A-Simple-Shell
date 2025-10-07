# ASS - A Simple Shell

> ASS is a shell made in D that, at it's core, can do whatever a more traditional shell (for example bash) does.

## Commands list
It has a very basic list of commands:
`pcdc` - print current directory content

`pcd` - print current directory

`jtd [dir]` - jump to directory [dir]

`jtpd` - jump to previous directory (you can also do "jtd ..")

`rsf [file]` - remove specified file [file]

`rsd [dir]` - remove specified directory [dir]

`cnf [filename]` - create new file

`cnd [dirname]` - create new directory

`csc` - clear screen content

`etf` [exename] - execute the file [exename]

`butt [butname]` - run a .but file

`qtp` - quit the program

`help` - displays the help message


## Butt: ASS's scripting language

Butt uses ASS's commands with the addition of:
- `print` for outputting stuff
- variables, defined like this: `$[varname] = [varvalue]` and if you insert a `@` as the value of a variable you can take user input
- loops with the `loop` keyword which takes this syntax:
  ```
  loop [number of iterations] do
    [code]
  end
  ```
- if statements which take up this other syntax: `if [cond] then [expr] else [expr]`
