# Diamond build only; no Programmer or physical device access.
cd [file dirname [file normalize [info script]]]
# Fail closed if a broad/later preference overrides one of the SRAM budgets.
proc require_scored {report preference} {
    set start [string first "Preference: $preference" $report]
    if {$start < 0} { error "Missing timing preference: $preference" }
    set section [string range $report $start [expr {$start + 450}]]
    if {![regexp {
[ \t]*([0-9]+) items? scored, ([0-9]+) timing errors? detected} $section match scored errors]
        || $scored == 0 || $errors != 0} {
        error "Timing preference unmatched or failing: $preference"
    }
}
if {[catch {
    # Synplify may continue with an undefined ROM when an init file is absent.
    foreach path {build/boot.mem rtl/font_boot.mem rtl/ps2_set2.mem rtl/keyboard_translate.mem rtl/pal_waveform.mem rtl/pal_rgb332.mem rtl/ay8910.mem rtl/ay8910_init.vh} {
        if {![file exists $path] || [file size $path] == 0} {
            error "Missing generated ROM input: $path (run make firmware)"
        }
    }
    prj_project open pyldin601_classic.ldf
    prj_run Synthesis -impl impl1
    # Behavioural readmemh tests cannot verify Synplify's deep-ROM address order.
    puts [exec python3 tests/check_pal_ebr.py impl1/pyldin601_classic_impl1.edi]
    puts [exec python3 tests/check_ay_ebr.py impl1/pyldin601_classic_impl1.edi]
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
    foreach preference {
        {FREQUENCY NET "clk_fast" 96.000000 MHz ;}
        {FREQUENCY NET "cpu_clk" 8.000000 MHz ;}
        {MULTICYCLE FROM CLKNET "cpu_clk" TO CLKNET "clk" 2.000000 X ;}
        {MULTICYCLE FROM CLKNET "cpu_clk" TO CLKNET "clk_fast" 4.000000 X ;}
        {MAXDELAY FROM CELL "system/runtime_memory/cpu_result*" TO CELL "cpu/*" 27.000000 ns DATAPATH_ONLY ;}
        {CLOCK_TO_OUT PORT "SRAM_ADDR[*]" 6.000000 ns CLKNET "clk_fast" ;}
        {CLOCK_TO_OUT PORT "SRAM_DATA[*]" 10.500000 ns CLKNET "clk_fast" ;}
        {CLOCK_TO_OUT PORT "SRAM_CE" 6.000000 ns CLKNET "clk_fast" ;}
        {CLOCK_TO_OUT PORT "SRAM_OE" 6.000000 ns CLKNET "clk_fast" ;}
        {CLOCK_TO_OUT PORT "SRAM_LB" 6.000000 ns CLKNET "clk_fast" ;}
        {CLOCK_TO_OUT PORT "SRAM_UB" 6.000000 ns CLKNET "clk_fast" ;}
        {CLOCK_TO_OUT PORT "SRAM_WE" 6.000000 ns CLKNET "clk_fast" ;}
        {INPUT_SETUP PORT "SRAM_DATA[*]" 8.000000 ns HOLD 0.000000 ns CLKNET "clk_fast" ;}
    } { require_scored $timing $preference }
    prj_run Export -impl impl1 -task Jedecgen
    prj_project close
} message]} {
    puts stderr "Pyldin601 build failed: $message"
    exit 1
}
exit 0
