# vim: set et nosta sw=4 ts=4 ft=nim :

import
    terminal

system.add_quit_proc( resetAttributes )

proc decho*( msg: varargs[string, `$`] ): void =
    ## "Debug Echo": Emit a debug message with terminal highlights to stderr.
    var output = ansi_foreground_colorcode( fgBlack, true )
    for str in msg: output.add( str )
    output.add( "\e[0m" )
    stderr.write_line( output )


proc dcolor*( msg: string ): string =
    ## Return a string wrapped in terminal highlights.
    result = ansi_foreground_colorcode( fgBlack, true )
    result.add( msg )
    result.add( "\e[0m" )

