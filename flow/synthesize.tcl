# Generic CVA6 synthesis flow. Target-specific values come only from the
# repository-level synthesis.yaml via flow/run.py.

proc required_env {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        error "required environment variable is not set: $name"
    }
    return $::env($name)
}

proc env_lines {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        return {}
    }
    set result {}
    foreach item [split $::env($name) "\n"] {
        if {$item ne ""} {
            lappend result $item
        }
    }
    return $result
}

set output_dir /workspace/output
set top_name [required_env SYNTH_TOP]
set flist [required_env SYNTH_FLIST]
set liberty_file [required_env LIBERTY_PATH]
set synth_mode [required_env SYNTH_MODE]
set output_netlist [required_env OUTPUT_NETLIST]

if {$synth_mode ne "quick" && $synth_mode ne "full"} {
    error "SYNTH_MODE must be 'quick' or 'full'"
}

puts "TARGET_CFG=$::env(TARGET_CFG)"
puts "Top=$top_name"
puts "Flist=$flist"
puts "Mode=$synth_mode"

yosys -import
plugin -i slang

set read_cmd [list read_slang --top $top_name -keep-hierarchy --ignore-assertions]
foreach define [env_lines SYNTH_DEFINES] {
    lappend read_cmd -D $define
}
lappend read_cmd -f $flist
foreach source [env_lines SYNTH_EXTRA_SOURCES] {
    lappend read_cmd $source
}

tee -o [file join $output_dir read-slang.rpt] {*}$read_cmd

foreach pattern [env_lines SYNTH_EXPECT_PRESENT] {
    select -assert-any $pattern
}
foreach pattern [env_lines SYNTH_EXPECT_ABSENT] {
    select -assert-none $pattern
}
select -clear

# Discard unsupported initialization attributes before generic synthesis.
setattr -unset init

tee -o [file join $output_dir synth-run-top.rpt] synth -top $top_name -noabc -flatten

if {$synth_mode eq "full"} {
    tee -o [file join $output_dir dfflibmap.rpt] dfflibmap -liberty $liberty_file
    tee -o [file join $output_dir abc.rpt] abc -liberty $liberty_file

    hilomap -singleton \
        -hicell [required_env TIE_HIGH_CELL] [required_env TIE_HIGH_PIN] \
        -locell [required_env TIE_LOW_CELL] [required_env TIE_LOW_PIN]
    clean
    tee -o [file join $output_dir stat.rpt] stat -liberty $liberty_file
} else {
    clean
    tee -o [file join $output_dir stat.rpt] stat
}

tee -o [file join $output_dir ltp.rpt] ltp -noff

# Keep hierarchy/net names where Yosys can preserve them. Full mode produces a
# mapped netlist for OpenSTA; quick mode produces a generic synthesized netlist.
write_verilog -noattr -noexpr -nodec -nohex $output_netlist
