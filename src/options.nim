# vim: set et nosta sw=4 ts=4 ft=nim :

import
    cpuinfo,
    os,
    parseopt,
    strutils

const
    VERSION* = "v0.0.1"
    USAGE = """
./multirun [-d][-h][-n][-v] -- <process> [<args> ...]

  -d: Debug: Emit internal information to stderr.
  -h: Help.  You're lookin' at it.
  -n: Number of children processes to execute.
      Defaults to the number of detected processors/cores.
  -v: Display version number.

Example: multirun -n=12 program-to-run arguments
    """


type
    Options* = object
      debug*:   bool        # Spew out internals
      number*:  Natural     # How many processes to spawn?
      args*:    seq[string] # remainings arguments to exec


proc parse_options*: Options =
    ## Populate the config object with command line switches.

    # Options object defaults.
    #
    result = Options(
        debug:   false,
        args:    @[],
        number:  count_processors()
    )

    # always set debug mode if development build.
    result.debug = defined( testing )

    var parser = init_opt_parser()
    for kind, key, val in parser.getopt:
        case kind

        of cmdArgument:
            result.args.add( key )
            break

        of cmdLongOption, cmdShortOption:
            case key
                of "": # --
                    break

                of "debug", "d":
                    result.debug = true

                of "help", "h":
                    echo USAGE
                    quit( 0 )

                of "version", "v":
                    echo "multirun " & VERSION
                    quit( 0 )

                of "number", "n":
                    if val == "":
                        echo( "Process count (-n) requires an argument." )
                        quit( 1 )

                    result.number = val.parse_int
                    if result.number < 2 and not result.debug:
                        echo( "There's no need to use multirun in this context. (< 2 processes)" )
                        quit( 1 )

                else:
                    discard

        of cmdEnd:
            discard

    for arg in parser.cmd_line_rest.parse_cmd_line:
        result.args.add( arg )

    if result.args.len == 0:
        echo USAGE
        quit( 1 )


