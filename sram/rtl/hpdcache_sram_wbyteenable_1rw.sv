// Substitute for the HPDcache behavioural SRAM with write byte enable (same
// ports): backed by cva6_sram_1rw with one macro per byte lane.
module hpdcache_sram_wbyteenable_1rw #(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1
) (
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              cs,
    input  logic                              we,
    input  logic [ADDR_SIZE-1:0]              addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   wdata,
    input  logic [NDATA-1:0][DATA_SIZE/8-1:0] wbyteenable,
    output logic [NDATA-1:0][DATA_SIZE-1:0]   rdata
);

  cva6_sram_1rw #(
    .Depth  ( DEPTH ),
    .Width  ( NDATA*DATA_SIZE ),
    .ByteEn ( 1'b1 )
  ) i_sram (
    .clk_i   ( clk         ),
    .req_i   ( cs          ),
    .we_i    ( we          ),
    .addr_i  ( addr        ),
    .wdata_i ( wdata       ),
    .be_i    ( wbyteenable ),
    .rdata_o ( rdata       )
  );

endmodule
