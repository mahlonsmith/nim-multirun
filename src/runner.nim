# vim: set et nosta sw=4 ts=4 ft=nim :

import
    osproc,
    selectors,
    streams,
    tables
from posix import nil
from os import nil

import
    ./options,
    ./utils

# The signals we relay to our children.
#
const SIGNALS = [
    posix.SIGHUP,
    posix.SIGINT,
    posix.SIGQUIT,
    posix.SIGALRM,
    posix.SIGTERM,
    posix.SIGTSTP,
    posix.SIGCONT,
    posix.SIGUSR1,
    posix.SIGUSR2
]

type
    Runner = ref object
        shutdown_requested: bool
        running:   bool
        opts:      Options
        selector:  Selector[ int ]
        processes: Table[ int, Process ]


proc newRunner*: Runner =
    ## Create and return a new Runner instance.
    new( result )
    result.shutdown_requested = false
    result.running   = false
    result.opts      = parse_options()
    result.selector  = newSelector[int]()
    result.processes = initTable[ int, Process ]()
    if result.opts.debug: decho $result.opts


proc spawn_processes( self: Runner ): void =
    ## Create child processes.
    for i in 1..self.opts.number:
        let process = start_process(
            command = self.opts.args[ 0 ],
            args    = self.opts.args[ 1 .. self.opts.args.len-1 ],
            options = { poUsePath, poStdErrToStdOut }
        )

        # registerProcess is {.discardable.}, so we need to map its tracking
        # descriptor to the process it is tracking.  (Discardable also
        # isn't GCed, so this should hopefully be addressed in a future
        # nim - this note is as of 1.0.2)
        #
        let pfd = self.selector.register_process( process.process_id, 0 )
        self.processes[ pfd ] = process
        if self.opts.debug: decho pfd, " --> ", repr process
        self.selector.register_handle( process.output_handle.int, {Event.Read}, pfd )


proc register_signals( self: Runner ): void =
    ## Register intent for handling various signals.
    for sig in SIGNALS:
        self.selector.register_signal( sig, sig )


proc cleanup_processes( self: Runner ): void =
    ## Walk through children processes, removing those that are no
    ## longer valid from the selector.
    for pfd, process in self.processes.pairs:
        if not process.running:
            process.close
            self.selector.unregister( pfd )

            var exitcode = process.peek_exit_code
            if exitcode > 128:
                exitcode = exitcode - 128
            if self.opts.debug:
                decho "Child process ", $process.process_id, " exited: ", $exitcode
            self.processes.del( pfd )

    if self.processes.len == 0 and self.running:
        if self.opts.debug: decho "All children have exited, I'm doing the same."
        self.running = false


proc terminate_processes( self: Runner, kill9=false ): void =
    ## Force remove all childen processes.
    let sig = if kill9: posix.SIGKILL else: posix.SIGTERM
    for pfd, process in self.processes.pairs:
        discard posix.kill( process.process_id.cint, sig )
    if kill9: return

    var check  = 0
    while check < 10:
        var active = 0
        for pfd, process in self.processes.pairs:
            if process.running: active = active + 1
        if active > 0:
            if self.opts.debug:
                decho "..."
            check = check + 1
            os.sleep( 500 )

    var active = 0
    for pfd, process in self.processes.pairs:
        if process.running: active = active + 1
    if active > 0:
        if self.opts.debug:
            decho "Forcefully killing children."
        self.terminate_processes( kill9=true )


proc handle_signal( self: Runner, sig: int ): void =
    ## Relay signals this process receives to its children.
    for pfd, process in self.processes.pairs:
        if self.opts.debug: decho "Sending signal ", $sig, " to ", $process.process_id
        discard posix.kill( process.process_id.cint, sig.cint )

    if sig == posix.SIGTERM:
        if self.shutdown_requested:
            decho "Force shutdown requested.  Waiting for children to exit..."
            self.terminate_processes
        else:
            if self.opts.debug: decho "One more TERM to force shutdown..."
            self.shutdown_requested = true


proc handle_output( self: Runner, selector_id: int ): void =
    ## Drain a read reader file descriptor and emit to stdout,
    ## prefxed with the process pid.
    var process: Process
    try:
        process = self.processes[ selector_id ]
    except KeyError:
        return

    var buf    = ""
    let stream = process.output_stream
    var c: char

    while c != '\n':
        c = stream.read_char
        if c != '\n': buf &= c
    echo dcolor( $process.process_id & ": " ) & buf


proc handle_event( self: Runner, ev: ReadyKey ): void =
    ## Dispatch a ready event to a specific handler.
    if self.opts.debug: decho "Received event: ", repr ev
    if Event.Signal in ev.events:
        self.handle_signal( self.selector.get_data(ev.fd) )

    if Event.Process in ev.events:
        self.cleanup_processes

    if Event.Read in ev.events:
        self.handle_output( self.selector.get_data(ev.fd) )

    if Event.Error in ev.events:
        self.cleanup_processes


proc run*( self: Runner ): void =
    ## Setup the environment and go!
    if self.opts.debug: decho posix.getpid(), ": Starting."

    self.register_signals
    self.spawn_processes
    self.running = true

    if self.opts.debug: decho "Waiting for events..."
    while self.running:
        try:
            let events = self.selector.select( -1 )
            for ev in events: self.handle_event( ev )
        except IOSelectorsException as e:
            if self.opts.debug: decho "Unhandled exception in select loop: " & e.msg
            self.cleanup_processes


