// cva6_sram_1rw as a behavioural array with byte lanes; synthesis maps it to
// flip-flops. The read data holds its value when no read is requested.
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

  logic [Width-1:0] mem[Depth];

  always_ff @(posedge clk_i) begin
    if (req_i) begin
      if (we_i) begin
        for (int unsigned i = 0; i < Width; i++) begin
          if (!ByteEn || be_i[i/8]) mem[addr_i][i] <= wdata_i[i];
        end
      end else begin
        rdata_o <= mem[addr_i];
      end
    end
  end

endmodule
