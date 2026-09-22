# Minimal pre-layout STA. Deliberately constrain only the main clock and emit a
# raw report; no interpretation, scoring, or sign-off claim is made here.

proc required_env {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        error "required environment variable is not set: $name"
    }
    return $::env($name)
}

set liberty_file [required_env LIBERTY_PATH]
set netlist [required_env MAPPED_NETLIST]
set top_name [required_env SYNTH_TOP]
set clock_port [required_env CLOCK_PORT]
set clock_period [required_env CLOCK_PERIOD_NS]
set timing_report [required_env TIMING_REPORT]

read_liberty $liberty_file
read_verilog $netlist
link_design $top_name

set clock_ports [get_ports $clock_port]
if {[llength $clock_ports] == 0} {
    error "clock port '$clock_port' was not found on '$top_name'"
}

create_clock -name core_clk -period $clock_period $clock_ports

# Restrict the initial report to paths captured by the configured main clock.
# Primary-I/O timing is intentionally not modeled yet.
report_checks \
    -path_delay max \
    -path_group core_clk \
    -group_path_count 10 \
    -sort_by_slack \
    -format full_clock_expanded \
    -fields {capacitance slew fanout net} \
    > $timing_report
