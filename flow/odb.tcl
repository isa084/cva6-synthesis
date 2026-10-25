# Reads ODB_FILE (a floorplan) and prints:
#   "SRAM <master> <instances>" for every cva6_sram_* macro master;
#   "MOD <path> <module> <logic> <sram>" for the top module ("-") and every
#   module instance, with the cell area (um^2) of that module only.
read_db $::env(ODB_FILE)
set block [ord::get_db_block]
set dbu [$block getDbUnitsPerMicron]

set count [dict create]
foreach inst [$block getInsts] {
  set master [[$inst getMaster] getName]
  if {[string match cva6_sram_* $master]} {
    dict incr count $master
  }
}
dict for {master n} $count {
  puts "SRAM $master $n"
}

proc own {module} {
  set logic 0.0
  set sram 0.0
  foreach inst [$module getInsts] {
    set master [$inst getMaster]
    set area [expr {double([$master getWidth]) * [$master getHeight] / $::dbu / $::dbu}]
    if {[string match cva6_sram_* [$master getName]]} {
      set sram [expr {$sram + $area}]
    } else {
      set logic [expr {$logic + $area}]
    }
  }
  return "$logic $sram"
}
set top [$block getTopModule]
puts "MOD - [$top getName] [own $top]"
foreach mi [$block getModInsts] {
  puts "MOD [$mi getHierarchicalName] [[$mi getMaster] getName] [own [$mi getMaster]]"
}
