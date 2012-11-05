Staircase - A practical Vim-Tmux bridge for Scala coding
=======================================================

Staircase is the port of my other plugins [Beduino]()
and [Cumino]() to Scala mode. It allows you to quickly send functions,
objects and classes to your Scala REPL (either with Scala standalone or
with SBT console).

* Read the [Wiki](https://github.com/adinapoli/cumino/wiki/Getting-Started) to get started

# Prerequisites

* Vim with Python support enabled
* Tmux >= 1.5
* A terminal emulator
  * Staircase was tested against *gnome-terminal*, *xterm*, *urxvt* and *mlterm*.

# Features

* Send to Scala your types, function and instances definitions
* Type your function invocation in Vim an watch them be evaluated in Scala REPL
* Test in isolation snippet of code sending visual selection to the REPL
* Show the type of the function under the cursor
* Test your code **environmentwise**: if you start Vim inside an [SBT]()
  project, Staircase will automatically run the associated console.


# Installation

Like any other Pathogen bundle.

# Contribute

Yes, please. You can open an issue or fork fix and pull, like usual.
