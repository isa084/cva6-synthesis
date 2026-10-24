# Prints "SRAM <master> <instances>" for every cva6_sram_* macro in ODB_FILE.
read_db $::env(ODB_FILE)
set count [dict create]
foreach inst [[ord::get_db_block] getInsts] {
  set master [[$inst getMaster] getName]
  if {[string match cva6_sram_* $master]} {
    dict incr count $master
  }
}
dict for {master n} $count {
  puts "SRAM $master $n"
}
