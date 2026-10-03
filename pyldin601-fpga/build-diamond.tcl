# Diamond build only; no Programmer or physical device access.
cd [file dirname [file normalize [info script]]]
if {[catch {
    prj_project open pyldin601_classic.ldf
    prj_run Synthesis -impl impl1
    prj_run Translate -impl impl1
    prj_run Map -impl impl1
    prj_run PAR -impl impl1
    prj_run PAR -impl impl1 -task PARTrace
    set report [open impl1/pyldin601_classic_impl1.twr r]
    set timing [read $report]
    close $report
    set slacks [regexp -all -inline {Cumulative negative slack: (-?[0-9.]+)} $timing]
    if {[llength $slacks] == 0} { error "No timing summary in TRACE report" }
    foreach {match slack} $slacks {
        if {$slack != 0} { error "Timing failed: cumulative negative slack $slack" }
    }
    set untimed [regexp -all -inline {([0-9]+) unconstrained paths found} $timing]
    if {[llength $untimed] == 0} { error "No unconstrained-path audit in TRACE report" }
    foreach {match count} $untimed {
        if {$count != 0} { error "Timing incomplete: $count unconstrained paths" }
    }
    if {![regexp {Preference: MAXDELAY FROM CELL "system/\*" TO CELL "cpu/\*"[^\n]*\n[ \t]*([0-9]+) items scored, ([0-9]+) timing errors detected} $timing match scored errors]
        || $scored == 0 || $errors != 0} {
        error "CPU half-cycle constraint is missing, unmatched or failing"
    }
    prj_run Export -impl impl1 -task Jedecgen
    prj_project close
} message]} {
    puts stderr "Pyldin601 build failed: $message"
    exit 1
}
exit 0
