// Zero-delay testbench for cva6: the RTL, or the post-synthesis netlist when
// GATE is defined. It loads a program (64-bit words) at DramBase, starts the
// core there, and stops when the program writes its exit status to tohost.
// tohost and fromhost are outside the cached region, so the write reaches the
// bus also with a write-back data cache. Any other value written to tohost is
// a system call: fromhost acknowledges it, and a write to stdout is printed.
//
// Plusargs: +hex=<program> [+max_cycles=<n>]
// Last line: "GSIM PASS", "GSIM FAIL <exit code>" or "GSIM TIMEOUT".
module gsim_tb;
  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  localparam logic [63:0] DramBase = 64'h8000_0000;
  localparam logic [63:0] HostBase = 64'h6000_0000;  // tohost; fromhost at +0x40
  localparam int unsigned MemWords = 2 ** 17;          // 1 MiB

  // Bus types: the defaults of the cva6 module.
  typedef struct packed {
    logic [CVA6Cfg.AxiIdWidth-1:0]   id;
    logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
    axi_pkg::len_t                   len;
    axi_pkg::size_t                  size;
    axi_pkg::burst_t                 burst;
    logic                            lock;
    axi_pkg::cache_t                 cache;
    axi_pkg::prot_t                  prot;
    axi_pkg::qos_t                   qos;
    axi_pkg::region_t                region;
    logic [CVA6Cfg.AxiUserWidth-1:0] user;
  } ar_chan_t;
  typedef struct packed {
    logic [CVA6Cfg.AxiIdWidth-1:0]   id;
    logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
    axi_pkg::len_t                   len;
    axi_pkg::size_t                  size;
    axi_pkg::burst_t                 burst;
    logic                            lock;
    axi_pkg::cache_t                 cache;
    axi_pkg::prot_t                  prot;
    axi_pkg::qos_t                   qos;
    axi_pkg::region_t                region;
    axi_pkg::atop_t                  atop;
    logic [CVA6Cfg.AxiUserWidth-1:0] user;
  } aw_chan_t;
  typedef struct packed {
    logic [CVA6Cfg.AxiDataWidth-1:0]     data;
    logic [(CVA6Cfg.AxiDataWidth/8)-1:0] strb;
    logic                                last;
    logic [CVA6Cfg.AxiUserWidth-1:0]     user;
  } w_chan_t;
  typedef struct packed {
    logic [CVA6Cfg.AxiIdWidth-1:0]   id;
    axi_pkg::resp_t                  resp;
    logic [CVA6Cfg.AxiUserWidth-1:0] user;
  } b_chan_t;
  typedef struct packed {
    logic [CVA6Cfg.AxiIdWidth-1:0]   id;
    logic [CVA6Cfg.AxiDataWidth-1:0] data;
    axi_pkg::resp_t                  resp;
    logic                            last;
    logic [CVA6Cfg.AxiUserWidth-1:0] user;
  } r_chan_t;
  typedef struct packed {
    aw_chan_t aw;
    logic     aw_valid;
    w_chan_t  w;
    logic     w_valid;
    logic     b_ready;
    ar_chan_t ar;
    logic     ar_valid;
    logic     r_ready;
  } noc_req_t;
  typedef struct packed {
    logic    aw_ready;
    logic    ar_ready;
    logic    w_ready;
    logic    b_valid;
    b_chan_t b;
    logic    r_valid;
    r_chan_t r;
  } noc_resp_t;

  logic      clk = 1'b0;
  logic      rst_n = 1'b0;
  noc_req_t  req;
  noc_resp_t resp;

  always #5 clk = ~clk;

`ifdef GATE
  logic [$bits(noc_req_t)-1:0] req_bits;
  assign req = noc_req_t'(req_bits);
  cva6 i_dut (
    .clk_i       (clk),
    .rst_ni      (rst_n),
    .boot_addr_i (DramBase[CVA6Cfg.VLEN-1:0]),
    .hart_id_i   ('0),
    .irq_i       ('0),
    .ipi_i       (1'b0),
    .time_irq_i  (1'b0),
    .debug_req_i (1'b0),
    .cvxif_req_o (),
    .cvxif_resp_i('0),
    .noc_req_o   (req_bits),
    .noc_resp_i  (resp)
  );
`else
  cva6 #(.CVA6Cfg(CVA6Cfg)) i_dut (
    .clk_i        (clk),
    .rst_ni       (rst_n),
    .boot_addr_i  (DramBase[CVA6Cfg.VLEN-1:0]),
    .hart_id_i    ('0),
    .irq_i        ('0),
    .ipi_i        (1'b0),
    .time_irq_i   (1'b0),
    .debug_req_i  (1'b0),
    .rvfi_probes_o(),
    .cvxif_req_o  (),
    .cvxif_resp_i ('0),
    .noc_req_o    (req),
    .noc_resp_i   (resp)
  );
`endif

  // Memory, tohost and fromhost
  logic [63:0] mem[MemWords];
  logic [63:0] tohost, fromhost;
  longint unsigned cycles, max_cycles;
  bit trace;  // +trace: print each bus transaction

  function automatic logic is_dram(logic [63:0] addr);
    return addr >= DramBase && addr < DramBase + 8 * MemWords;
  endfunction

  function automatic logic [63:0] read64(logic [63:0] addr);
    if (is_dram(addr)) return mem[(addr - DramBase) >> 3];
    if (addr[63:6] == HostBase[63:6]) return tohost;
    if (addr[63:6] == HostBase[63:6] + 1) return fromhost;
    return '0;
  endfunction

  function automatic logic [7:0] read8(logic [63:0] addr);
    logic [63:0] word = read64(addr);
    return word[8*addr[2:0]+:8];
  endfunction

  // Next beat address of an AXI burst.
  function automatic logic [63:0] next_addr(logic [63:0] addr, aw_chan_t c);
    logic [63:0] step = 64'(1) << c.size, span = step * (64'(c.len) + 1);
    if (c.burst == axi_pkg::BURST_FIXED) return addr;
    if (c.burst == axi_pkg::BURST_WRAP) return (addr & ~(span - 1)) | ((addr + step) & (span - 1));
    return (addr & ~(step - 1)) + step;
  endfunction

  // A system call: magic_mem = {which, arg0, arg1, arg2}.
  task automatic syscall(logic [63:0] magic);
    logic [63:0] which = read64(magic), fd = read64(magic + 8), text = read64(magic + 16), len = read64(magic + 24);
    if (which == 64 && fd == 1)  // SYS_write to stdout
      for (longint unsigned i = 0; i < len; i++) $write("%c", read8(text + i));
    fromhost <= 64'd1;
  endtask

  // Write channel: one burst at a time.
  aw_chan_t    aw;
  logic [63:0] w_addr;
  logic        w_busy, b_pending;
  // Read channel: one burst at a time.
  ar_chan_t    ar;
  logic [63:0] r_addr;
  logic [7:0]  r_left;
  logic        r_busy;

  assign resp.aw_ready = !w_busy && !b_pending;
  assign resp.w_ready  = w_busy;
  assign resp.b_valid  = b_pending;
  assign resp.b        = '{id: aw.id, resp: axi_pkg::RESP_OKAY, user: '0};
  assign resp.ar_ready = !r_busy;
  assign resp.r_valid  = r_busy;
  assign resp.r        = '{id: ar.id, data: read64(r_addr), resp: axi_pkg::RESP_OKAY, last: r_left == 0, user: '0};

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      w_busy    <= 1'b0;
      b_pending <= 1'b0;
      r_busy    <= 1'b0;
      tohost    <= '0;
      fromhost  <= '0;
    end else begin
      if (trace && req.aw_valid && resp.aw_ready) $display("%0d AW %h len %0d size %0d", cycles, req.aw.addr, req.aw.len, req.aw.size);
      if (trace && req.w_valid && resp.w_ready) $display("%0d W  %h strb %h", cycles, req.w.data, req.w.strb);
      if (trace && req.ar_valid && resp.ar_ready) $display("%0d AR %h len %0d size %0d", cycles, req.ar.addr, req.ar.len, req.ar.size);
      if (req.aw_valid && resp.aw_ready) begin
        if (req.aw.atop != '0) begin
          $display("\nGSIM FAIL unsupported AXI atomic operation");
          $finish;
        end
        aw     <= req.aw;
        w_addr <= req.aw.addr;
        w_busy <= 1'b1;
      end
      if (req.w_valid && resp.w_ready) begin
        for (int b = 0; b < 8; b++) if (req.w.strb[b]) begin
          if (is_dram(w_addr)) mem[(w_addr - DramBase) >> 3][8*b+:8] <= req.w.data[8*b+:8];
          else if (w_addr[63:6] == HostBase[63:6] + 1) fromhost[8*b+:8] <= req.w.data[8*b+:8];
          else if (w_addr[63:6] == HostBase[63:6]) tohost[8*b+:8] <= req.w.data[8*b+:8];
        end
        // tohost: an odd value is the exit status, (code << 1) | 1.
        if (w_addr[63:6] == HostBase[63:6] && req.w.strb[3:0] != '0 && req.w.data[31:0] != '0) begin
          if (req.w.data[0]) begin
            if (req.w.data[31:1] == '0) $display("\nGSIM PASS after %0d cycles", cycles);
            else $display("\nGSIM FAIL %0d after %0d cycles", req.w.data[31:1], cycles);
            $finish;
          end else syscall({16'b0, req.w.data[47:0]});
        end
        w_addr <= next_addr(w_addr, aw);
        if (req.w.last) begin
          w_busy    <= 1'b0;
          b_pending <= 1'b1;
        end
      end
      if (b_pending && req.b_ready) b_pending <= 1'b0;

      if (req.ar_valid && resp.ar_ready) begin
        ar     <= req.ar;
        r_addr <= req.ar.addr;
        r_left <= req.ar.len;
        r_busy <= 1'b1;
      end
      if (r_busy && req.r_ready) begin
        if (r_left == 0) r_busy <= 1'b0;
        r_addr <= next_addr(r_addr, aw_chan_t'{burst: ar.burst, size: ar.size, len: ar.len, default: '0});
        r_left <= r_left - 1;
      end
    end
  end

  always_ff @(posedge clk) begin
    cycles <= cycles + 1;
    if (cycles >= max_cycles) begin
      $display("\nGSIM TIMEOUT after %0d cycles (aw_valid %b w_valid %b b_pending %b ar_valid %b r_busy %b)",
               cycles, req.aw_valid, req.w_valid, b_pending, req.ar_valid, r_busy);
      $finish;
    end
  end

  initial begin
    string hex;
    if (!$value$plusargs("hex=%s", hex)) $fatal(1, "missing +hex=<program>");
    if (!$value$plusargs("max_cycles=%d", max_cycles)) max_cycles = 2_000_000;
    trace = $test$plusargs("trace");
    cycles = 0;
    for (int i = 0; i < MemWords; i++) mem[i] = '0;
    $readmemh(hex, mem);
    repeat (20) @(posedge clk);
    rst_n = 1'b1;
  end
endmodule
