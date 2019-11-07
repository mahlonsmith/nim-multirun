
Multirun
========

What's this?
------------

This is a simplistic program that runs multiple copies of a single
process, relaying signals received to its children, and managing
cleanup.  It was an exercise in learning the "selector" pattern in
[nim](https://nim-lang.org).

It is meant to be used in a
[daemontools](http://cr.yp.to/daemontools.html) pipeline.

If you need anything more complex, see
[foreman](https://github.com/ddollar/foreman/) or one of its many clones
- this tool is limited to doing only one thing with low resource usage.


Installation
------------

You'll need a working [Nim](http://nim-lang.org) build environment.
Simply run `make release` to build it.  Put it wherever you please.


Usage
-----

### Options

  * [-d|--debug]: Debug: Emit internal information to stderr.
  * [-h|--help]: Help.  You're lookin' at it.
  * [-n|--number]: Number of children processes to execute.
         Defaults to the number of detected processors/cores.
  * [-v|--version]: Display version number.

Example: multirun -n=12 program-to-run arguments


Notes
-----

 * Child processes emitting to stderr/stdout should be unbuffered.
 * These signals are "gatewayed" to the child processes:
   * SIGHUP
   * SIGINT
   * SIGQUIT
   * SIGALRM
   * SIGTERM
   * SIGTSTP
   * SIGCONT
   * SIGUSR1
   * SIGUSR2
 * Sending two consecutive TERM signals will force shutdown everything.
 * The STOP signal is not catchable -- if you want to STOP and RESUME
   children, send TSTP instead.  It has the same default effect.

