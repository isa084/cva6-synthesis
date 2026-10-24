// cva6_sram_1rw backed by FakeRAM macros: one macro per memory, or one 8-bit
// wide macro per byte lane when ByteEn is set. Add a shape here and in
// sram/asap7.cfg and sram/nangate45.cfg, then run sram/generate.sh.
`define CVA6_SRAM_SHAPE(D, W) \
  else if (Depth == D && LaneWidth == W) begin : gen_``D``x``W \
    cva6_sram_``D``x``W i_macro ( \
      .clk(clk_i), .ce_in(req_i), .we_in(lane_we), .addr_in(addr_i), \
      .wd_in(wdata_i[l*LaneWidth+:LaneWidth]), .rd_out(rdata_o[l*LaneWidth+:LaneWidth]) \
    ); \
  end

module cva6_sram_1rw #(
  parameter int unsigned Depth     = 64,
  parameter int unsigned Width     = 8,
  parameter bit          ByteEn    = 1'b0,
  parameter int unsigned AddrWidth = (Depth > 1) ? $clog2(Depth) : 1,
  parameter int unsigned BeWidth   = (Width + 7) / 8
) (
  input  logic                 clk_i,
  input  logic                 req_i,
  input  logic                 we_i,
  input  logic [AddrWidth-1:0] addr_i,
  input  logic [Width-1:0]     wdata_i,
  input  logic [BeWidth-1:0]   be_i,
  output logic [Width-1:0]     rdata_o
);

  localparam int unsigned Lanes     = ByteEn ? BeWidth : 1;
  localparam int unsigned LaneWidth = ByteEn ? 8 : Width;

  if (ByteEn && Width % 8 != 0) begin : gen_bad_width
    $fatal(1, "cva6_sram_1rw: byte-enabled width %0d is not a multiple of 8", Width);
  end

  for (genvar l = 0; l < Lanes; l++) begin : gen_lane
    logic lane_we;
    assign lane_we = we_i & (!ByteEn | be_i[l]);

    if (1'b0) begin : gen_none
    end
    `CVA6_SRAM_SHAPE(64, 8)
    `CVA6_SRAM_SHAPE(64, 25)
    `CVA6_SRAM_SHAPE(64, 28)
    `CVA6_SRAM_SHAPE(64, 256)
    `CVA6_SRAM_SHAPE(128, 8)
    `CVA6_SRAM_SHAPE(256, 8)
    `CVA6_SRAM_SHAPE(256, 26)
    `CVA6_SRAM_SHAPE(256, 48)
    `CVA6_SRAM_SHAPE(512, 8)
    else begin : gen_no_macro
      $fatal(1, "cva6_sram_1rw: no macro for %0dx%0d", Depth, LaneWidth);
    end
  end

endmodule
