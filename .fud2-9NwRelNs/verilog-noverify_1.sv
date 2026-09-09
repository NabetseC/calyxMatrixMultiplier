/* verilator lint_off MULTITOP */
/// =================== Unsigned, Fixed Point =========================
module std_fp_add #(
    parameter WIDTH = 32,
    parameter INT_WIDTH = 16,
    parameter FRAC_WIDTH = 16
) (
    input  logic [WIDTH-1:0] left,
    input  logic [WIDTH-1:0] right,
    output logic [WIDTH-1:0] out
);
  assign out = left + right;
endmodule

module std_fp_sub #(
    parameter WIDTH = 32,
    parameter INT_WIDTH = 16,
    parameter FRAC_WIDTH = 16
) (
    input  logic [WIDTH-1:0] left,
    input  logic [WIDTH-1:0] right,
    output logic [WIDTH-1:0] out
);
  assign out = left - right;
endmodule

module std_fp_mult_pipe #(
    parameter WIDTH = 32,
    parameter INT_WIDTH = 16,
    parameter FRAC_WIDTH = 16,
    parameter SIGNED = 0
) (
    input  logic [WIDTH-1:0] left,
    input  logic [WIDTH-1:0] right,
    input  logic             go,
    input  logic             clk,
    input  logic             reset,
    output logic [WIDTH-1:0] out,
    output logic             done
);
  logic [WIDTH-1:0]          rtmp;
  logic [WIDTH-1:0]          ltmp;
  logic [(WIDTH << 1) - 1:0] out_tmp;
  // Buffer used to walk through the 3 cycles of the pipeline.
  logic done_buf[1:0];

  assign done = done_buf[1];

  assign out = out_tmp[(WIDTH << 1) - INT_WIDTH - 1 : WIDTH - INT_WIDTH];

  // If the done buffer is completely empty and go is high then execution
  // just started.
  logic start;
  assign start = go;

  // Start sending the done signal.
  always_ff @(posedge clk) begin
    if (start)
      done_buf[0] <= 1;
    else
      done_buf[0] <= 0;
  end

  // Push the done signal through the pipeline.
  always_ff @(posedge clk) begin
    if (go) begin
      done_buf[1] <= done_buf[0];
    end else begin
      done_buf[1] <= 0;
    end
  end

  // Register the inputs
  always_ff @(posedge clk) begin
    if (reset) begin
      rtmp <= 0;
      ltmp <= 0;
    end else if (go) begin
      if (SIGNED) begin
        rtmp <= $signed(right);
        ltmp <= $signed(left);
      end else begin
        rtmp <= right;
        ltmp <= left;
      end
    end else begin
      rtmp <= 0;
      ltmp <= 0;
    end

  end

  // Compute the output and save it into out_tmp
  always_ff @(posedge clk) begin
    if (reset) begin
      out_tmp <= 0;
    end else if (go) begin
      if (SIGNED) begin
        // In the first cycle, this performs an invalid computation because
        // ltmp and rtmp only get their actual values in cycle 1
        out_tmp <= $signed(
          { {WIDTH{ltmp[WIDTH-1]}}, ltmp} *
          { {WIDTH{rtmp[WIDTH-1]}}, rtmp}
        );
      end else begin
        out_tmp <= ltmp * rtmp;
      end
    end else begin
      out_tmp <= out_tmp;
    end
  end
endmodule

/* verilator lint_off WIDTH */
module std_fp_div_pipe #(
  parameter WIDTH = 32,
  parameter INT_WIDTH = 16,
  parameter FRAC_WIDTH = 16
) (
    input  logic             go,
    input  logic             clk,
    input  logic             reset,
    input  logic [WIDTH-1:0] left,
    input  logic [WIDTH-1:0] right,
    output logic [WIDTH-1:0] out_remainder,
    output logic [WIDTH-1:0] out_quotient,
    output logic             done
);
    localparam ITERATIONS = WIDTH + FRAC_WIDTH;

    logic [WIDTH-1:0] quotient, quotient_next;
    logic [WIDTH:0] acc, acc_next;
    logic [$clog2(ITERATIONS)-1:0] idx;
    logic start, running, finished, dividend_is_zero;

    assign start = go && !running;
    assign dividend_is_zero = start && left == 0;
    assign finished = idx == ITERATIONS - 1 && running;

    always_ff @(posedge clk) begin
      if (reset || finished || dividend_is_zero)
        running <= 0;
      else if (start)
        running <= 1;
      else
        running <= running;
    end

    always @* begin
      if (acc >= {1'b0, right}) begin
        acc_next = acc - right;
        {acc_next, quotient_next} = {acc_next[WIDTH-1:0], quotient, 1'b1};
      end else begin
        {acc_next, quotient_next} = {acc, quotient} << 1;
      end
    end

    // `done` signaling
    always_ff @(posedge clk) begin
      if (dividend_is_zero || finished)
        done <= 1;
      else
        done <= 0;
    end

    always_ff @(posedge clk) begin
      if (running)
        idx <= idx + 1;
      else
        idx <= 0;
    end

    always_ff @(posedge clk) begin
      if (reset) begin
        out_quotient <= 0;
        out_remainder <= 0;
      end else if (start) begin
        out_quotient <= 0;
        out_remainder <= left;
      end else if (go == 0) begin
        out_quotient <= out_quotient;
        out_remainder <= out_remainder;
      end else if (dividend_is_zero) begin
        out_quotient <= 0;
        out_remainder <= 0;
      end else if (finished) begin
        out_quotient <= quotient_next;
        out_remainder <= out_remainder;
      end else begin
        out_quotient <= out_quotient;
        if (right <= out_remainder)
          out_remainder <= out_remainder - right;
        else
          out_remainder <= out_remainder;
      end
    end

    always_ff @(posedge clk) begin
      if (reset) begin
        acc <= 0;
        quotient <= 0;
      end else if (start) begin
        {acc, quotient} <= {{WIDTH{1'b0}}, left, 1'b0};
      end else begin
        acc <= acc_next;
        quotient <= quotient_next;
      end
    end
endmodule

module std_fp_gt #(
    parameter WIDTH = 32,
    parameter INT_WIDTH = 16,
    parameter FRAC_WIDTH = 16
) (
    input  logic [WIDTH-1:0] left,
    input  logic [WIDTH-1:0] right,
    output logic             out
);
  assign out = left > right;
endmodule

/// =================== Signed, Fixed Point =========================
module std_fp_sadd #(
    parameter WIDTH = 32,
    parameter INT_WIDTH = 16,
    parameter FRAC_WIDTH = 16
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed [WIDTH-1:0] out
);
  assign out = $signed(left + right);
endmodule

module std_fp_ssub #(
    parameter WIDTH = 32,
    parameter INT_WIDTH = 16,
    parameter FRAC_WIDTH = 16
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed [WIDTH-1:0] out
);

  assign out = $signed(left - right);
endmodule

module std_fp_smult_pipe #(
    parameter WIDTH = 32,
    parameter INT_WIDTH = 16,
    parameter FRAC_WIDTH = 16
) (
    input  [WIDTH-1:0]              left,
    input  [WIDTH-1:0]              right,
    input  logic                    reset,
    input  logic                    go,
    input  logic                    clk,
    output logic [WIDTH-1:0]        out,
    output logic                    done
);
  std_fp_mult_pipe #(
    .WIDTH(WIDTH),
    .INT_WIDTH(INT_WIDTH),
    .FRAC_WIDTH(FRAC_WIDTH),
    .SIGNED(1)
  ) comp (
    .clk(clk),
    .done(done),
    .reset(reset),
    .go(go),
    .left(left),
    .right(right),
    .out(out)
  );
endmodule

module std_fp_sdiv_pipe #(
    parameter WIDTH = 32,
    parameter INT_WIDTH = 16,
    parameter FRAC_WIDTH = 16
) (
    input                     clk,
    input                     go,
    input                     reset,
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed [WIDTH-1:0] out_quotient,
    output signed [WIDTH-1:0] out_remainder,
    output logic              done
);

  logic signed [WIDTH-1:0] left_abs, right_abs, comp_out_q, comp_out_r, right_save, out_rem_intermediate;

  // Registers to figure out how to transform outputs.
  logic different_signs, left_sign, right_sign;

  // Latch the value of control registers so that their available after
  // go signal becomes low.
  always_ff @(posedge clk) begin
    if (go) begin
      right_save <= right_abs;
      left_sign <= left[WIDTH-1];
      right_sign <= right[WIDTH-1];
    end else begin
      left_sign <= left_sign;
      right_save <= right_save;
      right_sign <= right_sign;
    end
  end

  assign right_abs = right[WIDTH-1] ? -right : right;
  assign left_abs = left[WIDTH-1] ? -left : left;

  assign different_signs = left_sign ^ right_sign;
  assign out_quotient = different_signs ? -comp_out_q : comp_out_q;

  // Remainder is computed as:
  //  t0 = |left| % |right|
  //  t1 = if left * right < 0 and t0 != 0 then |right| - t0 else t0
  //  rem = if right < 0 then -t1 else t1
  assign out_rem_intermediate = different_signs & |comp_out_r ? $signed(right_save - comp_out_r) : comp_out_r;
  assign out_remainder = right_sign ? -out_rem_intermediate : out_rem_intermediate;

  std_fp_div_pipe #(
    .WIDTH(WIDTH),
    .INT_WIDTH(INT_WIDTH),
    .FRAC_WIDTH(FRAC_WIDTH)
  ) comp (
    .reset(reset),
    .clk(clk),
    .done(done),
    .go(go),
    .left(left_abs),
    .right(right_abs),
    .out_quotient(comp_out_q),
    .out_remainder(comp_out_r)
  );
endmodule

module std_fp_sgt #(
    parameter WIDTH = 32,
    parameter INT_WIDTH = 16,
    parameter FRAC_WIDTH = 16
) (
    input  logic signed [WIDTH-1:0] left,
    input  logic signed [WIDTH-1:0] right,
    output logic signed             out
);
  assign out = $signed(left > right);
endmodule

module std_fp_slt #(
    parameter WIDTH = 32,
    parameter INT_WIDTH = 16,
    parameter FRAC_WIDTH = 16
) (
   input logic signed [WIDTH-1:0] left,
   input logic signed [WIDTH-1:0] right,
   output logic signed            out
);
  assign out = $signed(left < right);
endmodule

/// =================== Unsigned, Bitnum =========================
module std_mult_pipe #(
    parameter WIDTH = 32
) (
    input  logic [WIDTH-1:0] left,
    input  logic [WIDTH-1:0] right,
    input  logic             reset,
    input  logic             go,
    input  logic             clk,
    output logic [WIDTH-1:0] out,
    output logic             done
);
  std_fp_mult_pipe #(
    .WIDTH(WIDTH),
    .INT_WIDTH(WIDTH),
    .FRAC_WIDTH(0),
    .SIGNED(0)
  ) comp (
    .reset(reset),
    .clk(clk),
    .done(done),
    .go(go),
    .left(left),
    .right(right),
    .out(out)
  );
endmodule

module std_div_pipe #(
    parameter WIDTH = 32
) (
    input                    reset,
    input                    clk,
    input                    go,
    input        [WIDTH-1:0] left,
    input        [WIDTH-1:0] right,
    output logic [WIDTH-1:0] out_remainder,
    output logic [WIDTH-1:0] out_quotient,
    output logic             done
);

  logic [WIDTH-1:0] dividend;
  logic [(WIDTH-1)*2:0] divisor;
  logic [WIDTH-1:0] quotient;
  logic [WIDTH-1:0] quotient_msk;
  logic start, running, finished, dividend_is_zero;

  assign start = go && !running;
  assign finished = quotient_msk == 0 && running;
  assign dividend_is_zero = start && left == 0;

  always_ff @(posedge clk) begin
    // Early return if the divisor is zero.
    if (finished || dividend_is_zero)
      done <= 1;
    else
      done <= 0;
  end

  always_ff @(posedge clk) begin
    if (reset || finished || dividend_is_zero)
      running <= 0;
    else if (start)
      running <= 1;
    else
      running <= running;
  end

  // Outputs
  always_ff @(posedge clk) begin
    if (dividend_is_zero || start) begin
      out_quotient <= 0;
      out_remainder <= 0;
    end else if (finished) begin
      out_quotient <= quotient;
      out_remainder <= dividend;
    end else begin
      // Otherwise, explicitly latch the values.
      out_quotient <= out_quotient;
      out_remainder <= out_remainder;
    end
  end

  // Calculate the quotient mask.
  always_ff @(posedge clk) begin
    if (start)
      quotient_msk <= 1 << WIDTH - 1;
    else if (running)
      quotient_msk <= quotient_msk >> 1;
    else
      quotient_msk <= quotient_msk;
  end

  // Calculate the quotient.
  always_ff @(posedge clk) begin
    if (start)
      quotient <= 0;
    else if (divisor <= dividend)
      quotient <= quotient | quotient_msk;
    else
      quotient <= quotient;
  end

  // Calculate the dividend.
  always_ff @(posedge clk) begin
    if (start)
      dividend <= left;
    else if (divisor <= dividend)
      dividend <= dividend - divisor;
    else
      dividend <= dividend;
  end

  always_ff @(posedge clk) begin
    if (start) begin
      divisor <= right << WIDTH - 1;
    end else if (finished) begin
      divisor <= 0;
    end else begin
      divisor <= divisor >> 1;
    end
  end

  // Simulation self test against unsynthesizable implementation.
  `ifdef VERILATOR
    logic [WIDTH-1:0] l, r;
    always_ff @(posedge clk) begin
      if (go) begin
        l <= left;
        r <= right;
      end else begin
        l <= l;
        r <= r;
      end
    end

    always @(posedge clk) begin
      if (done && $unsigned(out_remainder) != $unsigned(l % r))
        $error(
          "\nstd_div_pipe (Remainder): Computed and golden outputs do not match!\n",
          "left: %0d", $unsigned(l),
          "  right: %0d\n", $unsigned(r),
          "expected: %0d", $unsigned(l % r),
          "  computed: %0d", $unsigned(out_remainder)
        );

      if (done && $unsigned(out_quotient) != $unsigned(l / r))
        $error(
          "\nstd_div_pipe (Quotient): Computed and golden outputs do not match!\n",
          "left: %0d", $unsigned(l),
          "  right: %0d\n", $unsigned(r),
          "expected: %0d", $unsigned(l / r),
          "  computed: %0d", $unsigned(out_quotient)
        );
    end
  `endif
endmodule

/// =================== Signed, Bitnum =========================
module std_sadd #(
    parameter WIDTH = 32
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed [WIDTH-1:0] out
);
  assign out = $signed(left + right);
endmodule

module std_ssub #(
    parameter WIDTH = 32
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed [WIDTH-1:0] out
);
  assign out = $signed(left - right);
endmodule

module std_smult_pipe #(
    parameter WIDTH = 32
) (
    input  logic                    reset,
    input  logic                    go,
    input  logic                    clk,
    input  signed       [WIDTH-1:0] left,
    input  signed       [WIDTH-1:0] right,
    output logic signed [WIDTH-1:0] out,
    output logic                    done
);
  std_fp_mult_pipe #(
    .WIDTH(WIDTH),
    .INT_WIDTH(WIDTH),
    .FRAC_WIDTH(0),
    .SIGNED(1)
  ) comp (
    .reset(reset),
    .clk(clk),
    .done(done),
    .go(go),
    .left(left),
    .right(right),
    .out(out)
  );
endmodule

/* verilator lint_off WIDTH */
module std_sdiv_pipe #(
    parameter WIDTH = 32
) (
    input                           reset,
    input                           clk,
    input                           go,
    input  logic signed [WIDTH-1:0] left,
    input  logic signed [WIDTH-1:0] right,
    output logic signed [WIDTH-1:0] out_quotient,
    output logic signed [WIDTH-1:0] out_remainder,
    output logic                    done
);

  logic signed [WIDTH-1:0] left_abs, right_abs, comp_out_q, comp_out_r, right_save, out_rem_intermediate;

  // Registers to figure out how to transform outputs.
  logic different_signs, left_sign, right_sign;

  // Latch the value of control registers so that their available after
  // go signal becomes low.
  always_ff @(posedge clk) begin
    if (go) begin
      right_save <= right_abs;
      left_sign <= left[WIDTH-1];
      right_sign <= right[WIDTH-1];
    end else begin
      left_sign <= left_sign;
      right_save <= right_save;
      right_sign <= right_sign;
    end
  end

  assign right_abs = right[WIDTH-1] ? -right : right;
  assign left_abs = left[WIDTH-1] ? -left : left;

  assign different_signs = left_sign ^ right_sign;
  assign out_quotient = different_signs ? -comp_out_q : comp_out_q;

  // Remainder is computed as:
  //  t0 = |left| % |right|
  //  t1 = if left * right < 0 and t0 != 0 then |right| - t0 else t0
  //  rem = if right < 0 then -t1 else t1
  assign out_rem_intermediate = different_signs & |comp_out_r ? $signed(right_save - comp_out_r) : comp_out_r;
  assign out_remainder = right_sign ? -out_rem_intermediate : out_rem_intermediate;

  std_div_pipe #(
    .WIDTH(WIDTH)
  ) comp (
    .reset(reset),
    .clk(clk),
    .done(done),
    .go(go),
    .left(left_abs),
    .right(right_abs),
    .out_quotient(comp_out_q),
    .out_remainder(comp_out_r)
  );

  // Simulation self test against unsynthesizable implementation.
  `ifdef VERILATOR
    logic signed [WIDTH-1:0] l, r;
    always_ff @(posedge clk) begin
      if (go) begin
        l <= left;
        r <= right;
      end else begin
        l <= l;
        r <= r;
      end
    end

    always @(posedge clk) begin
      if (done && out_quotient != $signed(l / r))
        $error(
          "\nstd_sdiv_pipe (Quotient): Computed and golden outputs do not match!\n",
          "left: %0d", l,
          "  right: %0d\n", r,
          "expected: %0d", $signed(l / r),
          "  computed: %0d", $signed(out_quotient),
        );
      if (done && out_remainder != $signed(((l % r) + r) % r))
        $error(
          "\nstd_sdiv_pipe (Remainder): Computed and golden outputs do not match!\n",
          "left: %0d", l,
          "  right: %0d\n", r,
          "expected: %0d", $signed(((l % r) + r) % r),
          "  computed: %0d", $signed(out_remainder),
        );
    end
  `endif
endmodule

module std_sgt #(
    parameter WIDTH = 32
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed             out
);
  assign out = $signed(left > right);
endmodule

module std_slt #(
    parameter WIDTH = 32
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed             out
);
  assign out = $signed(left < right);
endmodule

module std_seq #(
    parameter WIDTH = 32
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed             out
);
  assign out = $signed(left == right);
endmodule

module std_sneq #(
    parameter WIDTH = 32
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed             out
);
  assign out = $signed(left != right);
endmodule

module std_sge #(
    parameter WIDTH = 32
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed             out
);
  assign out = $signed(left >= right);
endmodule

module std_sle #(
    parameter WIDTH = 32
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed             out
);
  assign out = $signed(left <= right);
endmodule

module std_slsh #(
    parameter WIDTH = 32
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed [WIDTH-1:0] out
);
  assign out = left <<< right;
endmodule

module std_srsh #(
    parameter WIDTH = 32
) (
    input  signed [WIDTH-1:0] left,
    input  signed [WIDTH-1:0] right,
    output signed [WIDTH-1:0] out
);
  assign out = left >>> right;
endmodule

// Signed extension
module std_signext #(
  parameter IN_WIDTH  = 32,
  parameter OUT_WIDTH = 32
) (
  input wire logic [IN_WIDTH-1:0]  in,
  output logic     [OUT_WIDTH-1:0] out
);
  localparam EXTEND = OUT_WIDTH - IN_WIDTH;
  assign out = { {EXTEND {in[IN_WIDTH-1]}}, in};

  `ifdef VERILATOR
    always_comb begin
      if (IN_WIDTH > OUT_WIDTH)
        $error(
          "std_signext: Output width less than input width\n",
          "IN_WIDTH: %0d", IN_WIDTH,
          "OUT_WIDTH: %0d", OUT_WIDTH
        );
    end
  `endif
endmodule

module std_const_mult #(
    parameter WIDTH = 32,
    parameter VALUE = 1
) (
    input  signed [WIDTH-1:0] in,
    output signed [WIDTH-1:0] out
);
  assign out = in * VALUE;
endmodule

module comb_mem_d1 #(
    parameter WIDTH = 32,
    parameter SIZE = 16,
    parameter IDX_SIZE = 4
) (
   input wire                logic [IDX_SIZE-1:0] addr0,
   input wire                logic [ WIDTH-1:0] write_data,
   input wire                logic write_en,
   input wire                logic clk,
   input wire                logic reset,
   output logic [ WIDTH-1:0] read_data,
   output logic              done
);

  logic [WIDTH-1:0] mem[SIZE-1:0];

  /* verilator lint_off WIDTH */
  assign read_data = mem[addr0];

  always_ff @(posedge clk) begin
    if (reset)
      done <= '0;
    else if (write_en)
      done <= '1;
    else
      done <= '0;
  end

  always_ff @(posedge clk) begin
    if (!reset && write_en)
      mem[addr0] <= write_data;
  end

  // Check for out of bounds access
  `ifdef VERILATOR
    always_comb begin
      if (addr0 >= SIZE)
        $error(
          "comb_mem_d1: Out of bounds access\n",
          "addr0: %0d\n", addr0,
          "SIZE: %0d", SIZE
        );
    end
  `endif
endmodule

module comb_mem_d2 #(
    parameter WIDTH = 32,
    parameter D0_SIZE = 16,
    parameter D1_SIZE = 16,
    parameter D0_IDX_SIZE = 4,
    parameter D1_IDX_SIZE = 4
) (
   input wire                logic [D0_IDX_SIZE-1:0] addr0,
   input wire                logic [D1_IDX_SIZE-1:0] addr1,
   input wire                logic [ WIDTH-1:0] write_data,
   input wire                logic write_en,
   input wire                logic clk,
   input wire                logic reset,
   output logic [ WIDTH-1:0] read_data,
   output logic              done
);

  /* verilator lint_off WIDTH */
  logic [WIDTH-1:0] mem[D0_SIZE-1:0][D1_SIZE-1:0];

  assign read_data = mem[addr0][addr1];

  always_ff @(posedge clk) begin
    if (reset)
      done <= '0;
    else if (write_en)
      done <= '1;
    else
      done <= '0;
  end

  always_ff @(posedge clk) begin
    if (!reset && write_en)
      mem[addr0][addr1] <= write_data;
  end

  // Check for out of bounds access
  `ifdef VERILATOR
    always_comb begin
      if (addr0 >= D0_SIZE)
        $error(
          "comb_mem_d2: Out of bounds access\n",
          "addr0: %0d\n", addr0,
          "D0_SIZE: %0d", D0_SIZE
        );
      if (addr1 >= D1_SIZE)
        $error(
          "comb_mem_d2: Out of bounds access\n",
          "addr1: %0d\n", addr1,
          "D1_SIZE: %0d", D1_SIZE
        );
    end
  `endif
endmodule

module comb_mem_d3 #(
    parameter WIDTH = 32,
    parameter D0_SIZE = 16,
    parameter D1_SIZE = 16,
    parameter D2_SIZE = 16,
    parameter D0_IDX_SIZE = 4,
    parameter D1_IDX_SIZE = 4,
    parameter D2_IDX_SIZE = 4
) (
   input wire                logic [D0_IDX_SIZE-1:0] addr0,
   input wire                logic [D1_IDX_SIZE-1:0] addr1,
   input wire                logic [D2_IDX_SIZE-1:0] addr2,
   input wire                logic [ WIDTH-1:0] write_data,
   input wire                logic write_en,
   input wire                logic clk,
   input wire                logic reset,
   output logic [ WIDTH-1:0] read_data,
   output logic              done
);

  /* verilator lint_off WIDTH */
  logic [WIDTH-1:0] mem[D0_SIZE-1:0][D1_SIZE-1:0][D2_SIZE-1:0];

  assign read_data = mem[addr0][addr1][addr2];

  always_ff @(posedge clk) begin
    if (reset)
      done <= '0;
    else if (write_en)
      done <= '1;
    else
      done <= '0;
  end

  always_ff @(posedge clk) begin
    if (!reset && write_en)
      mem[addr0][addr1][addr2] <= write_data;
  end

  // Check for out of bounds access
  `ifdef VERILATOR
    always_comb begin
      if (addr0 >= D0_SIZE)
        $error(
          "comb_mem_d3: Out of bounds access\n",
          "addr0: %0d\n", addr0,
          "D0_SIZE: %0d", D0_SIZE
        );
      if (addr1 >= D1_SIZE)
        $error(
          "comb_mem_d3: Out of bounds access\n",
          "addr1: %0d\n", addr1,
          "D1_SIZE: %0d", D1_SIZE
        );
      if (addr2 >= D2_SIZE)
        $error(
          "comb_mem_d3: Out of bounds access\n",
          "addr2: %0d\n", addr2,
          "D2_SIZE: %0d", D2_SIZE
        );
    end
  `endif
endmodule

module comb_mem_d4 #(
    parameter WIDTH = 32,
    parameter D0_SIZE = 16,
    parameter D1_SIZE = 16,
    parameter D2_SIZE = 16,
    parameter D3_SIZE = 16,
    parameter D0_IDX_SIZE = 4,
    parameter D1_IDX_SIZE = 4,
    parameter D2_IDX_SIZE = 4,
    parameter D3_IDX_SIZE = 4
) (
   input wire                logic [D0_IDX_SIZE-1:0] addr0,
   input wire                logic [D1_IDX_SIZE-1:0] addr1,
   input wire                logic [D2_IDX_SIZE-1:0] addr2,
   input wire                logic [D3_IDX_SIZE-1:0] addr3,
   input wire                logic [ WIDTH-1:0] write_data,
   input wire                logic write_en,
   input wire                logic clk,
   input wire                logic reset,
   output logic [ WIDTH-1:0] read_data,
   output logic              done
);

  /* verilator lint_off WIDTH */
  logic [WIDTH-1:0] mem[D0_SIZE-1:0][D1_SIZE-1:0][D2_SIZE-1:0][D3_SIZE-1:0];

  assign read_data = mem[addr0][addr1][addr2][addr3];

  always_ff @(posedge clk) begin
    if (reset)
      done <= '0;
    else if (write_en)
      done <= '1;
    else
      done <= '0;
  end

  always_ff @(posedge clk) begin
    if (!reset && write_en)
      mem[addr0][addr1][addr2][addr3] <= write_data;
  end

  // Check for out of bounds access
  `ifdef VERILATOR
    always_comb begin
      if (addr0 >= D0_SIZE)
        $error(
          "comb_mem_d4: Out of bounds access\n",
          "addr0: %0d\n", addr0,
          "D0_SIZE: %0d", D0_SIZE
        );
      if (addr1 >= D1_SIZE)
        $error(
          "comb_mem_d4: Out of bounds access\n",
          "addr1: %0d\n", addr1,
          "D1_SIZE: %0d", D1_SIZE
        );
      if (addr2 >= D2_SIZE)
        $error(
          "comb_mem_d4: Out of bounds access\n",
          "addr2: %0d\n", addr2,
          "D2_SIZE: %0d", D2_SIZE
        );
      if (addr3 >= D3_SIZE)
        $error(
          "comb_mem_d4: Out of bounds access\n",
          "addr3: %0d\n", addr3,
          "D3_SIZE: %0d", D3_SIZE
        );
    end
  `endif
endmodule

/**
 * Core primitives for Calyx.
 * Implements core primitives used by the compiler.
 *
 * Conventions:
 * - All parameter names must be SNAKE_CASE and all caps.
 * - Port names must be snake_case, no caps.
 */

module std_slice #(
    parameter IN_WIDTH  = 32,
    parameter OUT_WIDTH = 32
) (
   input wire                   logic [ IN_WIDTH-1:0] in,
   output logic [OUT_WIDTH-1:0] out
);
  assign out = in[OUT_WIDTH-1:0];

  `ifdef VERILATOR
    always_comb begin
      if (IN_WIDTH < OUT_WIDTH)
        $error(
          "std_slice: Input width less than output width\n",
          "IN_WIDTH: %0d", IN_WIDTH,
          "OUT_WIDTH: %0d", OUT_WIDTH
        );
    end
  `endif
endmodule

module std_pad #(
    parameter IN_WIDTH  = 32,
    parameter OUT_WIDTH = 32
) (
   input wire logic [IN_WIDTH-1:0]  in,
   output logic     [OUT_WIDTH-1:0] out
);
  localparam EXTEND = OUT_WIDTH - IN_WIDTH;
  assign out = { {EXTEND {1'b0}}, in};

  `ifdef VERILATOR
    always_comb begin
      if (IN_WIDTH > OUT_WIDTH)
        $error(
          "std_pad: Output width less than input width\n",
          "IN_WIDTH: %0d", IN_WIDTH,
          "OUT_WIDTH: %0d", OUT_WIDTH
        );
    end
  `endif
endmodule

module std_cat #(
  parameter LEFT_WIDTH  = 32,
  parameter RIGHT_WIDTH = 32,
  parameter OUT_WIDTH = 64
) (
  input wire logic [LEFT_WIDTH-1:0] left,
  input wire logic [RIGHT_WIDTH-1:0] right,
  output logic [OUT_WIDTH-1:0] out
);
  assign out = {left, right};

  `ifdef VERILATOR
    always_comb begin
      if (LEFT_WIDTH + RIGHT_WIDTH != OUT_WIDTH)
        $error(
          "std_cat: Output width must equal sum of input widths\n",
          "LEFT_WIDTH: %0d", LEFT_WIDTH,
          "RIGHT_WIDTH: %0d", RIGHT_WIDTH,
          "OUT_WIDTH: %0d", OUT_WIDTH
        );
    end
  `endif
endmodule

module std_not #(
    parameter WIDTH = 32
) (
   input wire               logic [WIDTH-1:0] in,
   output logic [WIDTH-1:0] out
);
  assign out = ~in;
endmodule

module std_and #(
    parameter WIDTH = 32
) (
   input wire               logic [WIDTH-1:0] left,
   input wire               logic [WIDTH-1:0] right,
   output logic [WIDTH-1:0] out
);
  assign out = left & right;
endmodule

module std_or #(
    parameter WIDTH = 32
) (
   input wire               logic [WIDTH-1:0] left,
   input wire               logic [WIDTH-1:0] right,
   output logic [WIDTH-1:0] out
);
  assign out = left | right;
endmodule

module std_xor #(
    parameter WIDTH = 32
) (
   input wire               logic [WIDTH-1:0] left,
   input wire               logic [WIDTH-1:0] right,
   output logic [WIDTH-1:0] out
);
  assign out = left ^ right;
endmodule

module std_sub #(
    parameter WIDTH = 32
) (
   input wire               logic [WIDTH-1:0] left,
   input wire               logic [WIDTH-1:0] right,
   output logic [WIDTH-1:0] out
);
  assign out = left - right;
endmodule

module std_gt #(
    parameter WIDTH = 32
) (
   input wire   logic [WIDTH-1:0] left,
   input wire   logic [WIDTH-1:0] right,
   output logic out
);
  assign out = left > right;
endmodule

module std_lt #(
    parameter WIDTH = 32
) (
   input wire   logic [WIDTH-1:0] left,
   input wire   logic [WIDTH-1:0] right,
   output logic out
);
  assign out = left < right;
endmodule

module std_eq #(
    parameter WIDTH = 32
) (
   input wire   logic [WIDTH-1:0] left,
   input wire   logic [WIDTH-1:0] right,
   output logic out
);
  assign out = left == right;
endmodule

module std_neq #(
    parameter WIDTH = 32
) (
   input wire   logic [WIDTH-1:0] left,
   input wire   logic [WIDTH-1:0] right,
   output logic out
);
  assign out = left != right;
endmodule

module std_ge #(
    parameter WIDTH = 32
) (
    input wire   logic [WIDTH-1:0] left,
    input wire   logic [WIDTH-1:0] right,
    output logic out
);
  assign out = left >= right;
endmodule

module std_le #(
    parameter WIDTH = 32
) (
   input wire   logic [WIDTH-1:0] left,
   input wire   logic [WIDTH-1:0] right,
   output logic out
);
  assign out = left <= right;
endmodule

module std_rsh #(
    parameter WIDTH = 32
) (
   input wire               logic [WIDTH-1:0] left,
   input wire               logic [WIDTH-1:0] right,
   output logic [WIDTH-1:0] out
);
  assign out = left >> right;
endmodule

/// this primitive is intended to be used
/// for lowering purposes (not in source programs)
module std_mux #(
    parameter WIDTH = 32
) (
   input wire               logic cond,
   input wire               logic [WIDTH-1:0] tru,
   input wire               logic [WIDTH-1:0] fal,
   output logic [WIDTH-1:0] out
);
  assign out = cond ? tru : fal;
endmodule

module std_bit_slice #(
    parameter IN_WIDTH = 32,
    parameter START_IDX = 0,
    parameter END_IDX = 31,
    parameter OUT_WIDTH = 32
)(
   input wire logic [IN_WIDTH-1:0] in,
   output logic [OUT_WIDTH-1:0] out
);
  assign out = in[END_IDX:START_IDX];

  `ifdef VERILATOR
    always_comb begin
      if (START_IDX < 0 || END_IDX > IN_WIDTH-1)
        $error(
          "std_bit_slice: Slice range out of bounds\n",
          "IN_WIDTH: %0d", IN_WIDTH,
          "START_IDX: %0d", START_IDX,
          "END_IDX: %0d", END_IDX,
        );
    end
  `endif

endmodule

module std_skid_buffer #(
    parameter WIDTH = 32
)(
    input wire logic [WIDTH-1:0] in,
    input wire logic i_valid,
    input wire logic i_ready,
    input wire logic clk,
    input wire logic reset,
    output logic [WIDTH-1:0] out,
    output logic o_valid,
    output logic o_ready
);
  logic [WIDTH-1:0] val;
  logic bypass_rg;
  always @(posedge clk) begin
    // Reset  
    if (reset) begin      
      // Internal Registers
      val <= '0;     
      bypass_rg <= 1'b1;
    end   
    // Out of reset
    else begin      
      // Bypass state      
      if (bypass_rg) begin         
        if (!i_ready && i_valid) begin
          val <= in;          // Data skid happened, store to buffer
          bypass_rg <= 1'b0;  // To skid mode  
        end 
      end 
      // Skid state
      else begin         
        if (i_ready) begin
          bypass_rg <= 1'b1;  // Back to bypass mode           
        end
      end
    end
  end

  assign o_ready = bypass_rg;
  assign out = bypass_rg ? in : val;
  assign o_valid = bypass_rg ? i_valid : 1'b1;
endmodule

module std_bypass_reg #(
    parameter WIDTH = 32
)(
    input wire logic [WIDTH-1:0] in,
    input wire logic write_en,
    input wire logic clk,
    input wire logic reset,
    output logic [WIDTH-1:0] out,
    output logic done
);
  logic [WIDTH-1:0] val;
  assign out = write_en ? in : val;

  always_ff @(posedge clk) begin
    if (reset) begin
      val <= 0;
      done <= 0;
    end else if (write_en) begin
      val <= in;
      done <= 1'd1;
    end else done <= 1'd0;
  end
endmodule

module undef #(
    parameter WIDTH = 32
) (
   output logic [WIDTH-1:0] out
);
assign out = 'x;
endmodule

module std_const #(
    parameter WIDTH = 32,
    parameter VALUE = 32
) (
   output logic [WIDTH-1:0] out
);
assign out = VALUE;
endmodule

module std_wire #(
    parameter WIDTH = 32
) (
   input wire logic [WIDTH-1:0] in,
   output logic [WIDTH-1:0] out
);
assign out = in;
endmodule

module std_add #(
    parameter WIDTH = 32
) (
   input wire logic [WIDTH-1:0] left,
   input wire logic [WIDTH-1:0] right,
   output logic [WIDTH-1:0] out
);
assign out = left + right;
endmodule

module std_lsh #(
    parameter WIDTH = 32
) (
   input wire logic [WIDTH-1:0] left,
   input wire logic [WIDTH-1:0] right,
   output logic [WIDTH-1:0] out
);
assign out = left << right;
endmodule

module std_reg #(
    parameter WIDTH = 32
) (
   input wire logic [WIDTH-1:0] in,
   input wire logic write_en,
   input wire logic clk,
   input wire logic reset,
   output logic [WIDTH-1:0] out,
   output logic done
);
always_ff @(posedge clk) begin
    if (reset) begin
       out <= 0;
       done <= 0;
    end else if (write_en) begin
      out <= in;
      done <= 1'd1;
    end else done <= 1'd0;
  end
endmodule

module init_one_reg #(
    parameter WIDTH = 32
) (
   input wire logic [WIDTH-1:0] in,
   input wire logic write_en,
   input wire logic clk,
   input wire logic reset,
   output logic [WIDTH-1:0] out,
   output logic done
);
always_ff @(posedge clk) begin
    if (reset) begin
       out <= 1;
       done <= 0;
    end else if (write_en) begin
      out <= in;
      done <= 1'd1;
    end else done <= 1'd0;
  end
endmodule

module main(
  input logic go,
  output logic done,
  input logic clk,
  input logic reset
);
// COMPONENT START: main
string DATA;
int CODE;
initial begin
    CODE = $value$plusargs("DATA=%s", DATA);
    $display("DATA (path to meminit files): %s", DATA);
    $readmemh({DATA, "/arr1.dat"}, arr1.mem);
    $readmemh({DATA, "/arr2.dat"}, arr2.mem);
    $readmemh({DATA, "/arrOut.dat"}, arrOut.mem);
end
final begin
    $writememh({DATA, "/arr1.out"}, arr1.mem);
    $writememh({DATA, "/arr2.out"}, arr2.mem);
    $writememh({DATA, "/arrOut.out"}, arrOut.mem);
end
logic [31:0] arr1_addr0;
logic [31:0] arr1_addr1;
logic [31:0] arr1_write_data;
logic arr1_write_en;
logic arr1_clk;
logic arr1_reset;
logic [31:0] arr1_read_data;
logic arr1_done;
logic [31:0] arr2_addr0;
logic [31:0] arr2_addr1;
logic [31:0] arr2_write_data;
logic arr2_write_en;
logic arr2_clk;
logic arr2_reset;
logic [31:0] arr2_read_data;
logic arr2_done;
logic [31:0] arrOut_addr0;
logic [31:0] arrOut_addr1;
logic [31:0] arrOut_write_data;
logic arrOut_write_en;
logic arrOut_clk;
logic arrOut_reset;
logic [31:0] arrOut_read_data;
logic arrOut_done;
logic [31:0] i_in;
logic i_write_en;
logic i_clk;
logic i_reset;
logic [31:0] i_out;
logic i_done;
logic [31:0] j_in;
logic j_write_en;
logic j_clk;
logic j_reset;
logic [31:0] j_out;
logic j_done;
logic [31:0] k_in;
logic k_write_en;
logic k_clk;
logic k_reset;
logic [31:0] k_out;
logic k_done;
logic [31:0] ltI_left;
logic [31:0] ltI_right;
logic ltI_out;
logic [31:0] add1_left;
logic [31:0] add1_right;
logic [31:0] add1_out;
logic [31:0] add2_left;
logic [31:0] add2_right;
logic [31:0] add2_out;
logic multE_clk;
logic multE_reset;
logic multE_go;
logic [31:0] multE_left;
logic [31:0] multE_right;
logic [31:0] multE_out;
logic multE_done;
logic [31:0] outE_in;
logic outE_write_en;
logic outE_clk;
logic outE_reset;
logic [31:0] outE_out;
logic outE_done;
logic [31:0] addOut_left;
logic [31:0] addOut_right;
logic [31:0] addOut_out;
logic [31:0] element1_in;
logic element1_write_en;
logic element1_clk;
logic element1_reset;
logic [31:0] element1_out;
logic element1_done;
logic [31:0] element2_in;
logic element2_write_en;
logic element2_clk;
logic element2_reset;
logic [31:0] element2_out;
logic element2_done;
logic comb_reg_in;
logic comb_reg_write_en;
logic comb_reg_clk;
logic comb_reg_reset;
logic comb_reg_out;
logic comb_reg_done;
logic comb_reg0_in;
logic comb_reg0_write_en;
logic comb_reg0_clk;
logic comb_reg0_reset;
logic comb_reg0_out;
logic comb_reg0_done;
logic comb_reg1_in;
logic comb_reg1_write_en;
logic comb_reg1_clk;
logic comb_reg1_reset;
logic comb_reg1_out;
logic comb_reg1_done;
logic [2:0] fsm_in;
logic fsm_write_en;
logic fsm_clk;
logic fsm_reset;
logic [2:0] fsm_out;
logic fsm_done;
logic ud1_out;
logic ud2_out;
logic [2:0] adder_left;
logic [2:0] adder_right;
logic [2:0] adder_out;
logic ud3_out;
logic ud4_out;
logic ud5_out;
logic signal_reg_in;
logic signal_reg_write_en;
logic signal_reg_clk;
logic signal_reg_reset;
logic signal_reg_out;
logic signal_reg_done;
logic pd_in;
logic pd_write_en;
logic pd_clk;
logic pd_reset;
logic pd_out;
logic pd_done;
logic [2:0] fsm0_in;
logic fsm0_write_en;
logic fsm0_clk;
logic fsm0_reset;
logic [2:0] fsm0_out;
logic fsm0_done;
logic pd0_in;
logic pd0_write_en;
logic pd0_clk;
logic pd0_reset;
logic pd0_out;
logic pd0_done;
logic pd1_in;
logic pd1_write_en;
logic pd1_clk;
logic pd1_reset;
logic pd1_out;
logic pd1_done;
logic [2:0] fsm1_in;
logic fsm1_write_en;
logic fsm1_clk;
logic fsm1_reset;
logic [2:0] fsm1_out;
logic fsm1_done;
logic pd2_in;
logic pd2_write_en;
logic pd2_clk;
logic pd2_reset;
logic pd2_out;
logic pd2_done;
logic [2:0] fsm2_in;
logic fsm2_write_en;
logic fsm2_clk;
logic fsm2_reset;
logic [2:0] fsm2_out;
logic fsm2_done;
logic writeArrOut_go_in;
logic writeArrOut_go_out;
logic writeArrOut_done_in;
logic writeArrOut_done_out;
logic invoke0_go_in;
logic invoke0_go_out;
logic invoke0_done_in;
logic invoke0_done_out;
logic invoke1_go_in;
logic invoke1_go_out;
logic invoke1_done_in;
logic invoke1_done_out;
logic invoke7_go_in;
logic invoke7_go_out;
logic invoke7_done_in;
logic invoke7_done_out;
logic invoke8_go_in;
logic invoke8_go_out;
logic invoke8_done_in;
logic invoke8_done_out;
logic early_reset_static_par_thread_go_in;
logic early_reset_static_par_thread_go_out;
logic early_reset_static_par_thread_done_in;
logic early_reset_static_par_thread_done_out;
logic early_reset_condK0_go_in;
logic early_reset_condK0_go_out;
logic early_reset_condK0_done_in;
logic early_reset_condK0_done_out;
logic early_reset_static_seq_go_in;
logic early_reset_static_seq_go_out;
logic early_reset_static_seq_done_in;
logic early_reset_static_seq_done_out;
logic early_reset_condJ00_go_in;
logic early_reset_condJ00_go_out;
logic early_reset_condJ00_done_in;
logic early_reset_condJ00_done_out;
logic early_reset_condI00_go_in;
logic early_reset_condI00_go_out;
logic early_reset_condI00_done_in;
logic early_reset_condI00_done_out;
logic wrapper_early_reset_condI00_go_in;
logic wrapper_early_reset_condI00_go_out;
logic wrapper_early_reset_condI00_done_in;
logic wrapper_early_reset_condI00_done_out;
logic wrapper_early_reset_condJ00_go_in;
logic wrapper_early_reset_condJ00_go_out;
logic wrapper_early_reset_condJ00_done_in;
logic wrapper_early_reset_condJ00_done_out;
logic wrapper_early_reset_static_par_thread_go_in;
logic wrapper_early_reset_static_par_thread_go_out;
logic wrapper_early_reset_static_par_thread_done_in;
logic wrapper_early_reset_static_par_thread_done_out;
logic wrapper_early_reset_condK0_go_in;
logic wrapper_early_reset_condK0_go_out;
logic wrapper_early_reset_condK0_done_in;
logic wrapper_early_reset_condK0_done_out;
logic while_wrapper_early_reset_static_seq_go_in;
logic while_wrapper_early_reset_static_seq_go_out;
logic while_wrapper_early_reset_static_seq_done_in;
logic while_wrapper_early_reset_static_seq_done_out;
logic par0_go_in;
logic par0_go_out;
logic par0_done_in;
logic par0_done_out;
logic tdcc_go_in;
logic tdcc_go_out;
logic tdcc_done_in;
logic tdcc_done_out;
logic par1_go_in;
logic par1_go_out;
logic par1_done_in;
logic par1_done_out;
logic tdcc0_go_in;
logic tdcc0_go_out;
logic tdcc0_done_in;
logic tdcc0_done_out;
logic tdcc1_go_in;
logic tdcc1_go_out;
logic tdcc1_done_in;
logic tdcc1_done_out;
comb_mem_d2 # (
    .D0_IDX_SIZE(32),
    .D0_SIZE(6),
    .D1_IDX_SIZE(32),
    .D1_SIZE(5),
    .WIDTH(32)
) arr1 (
    .addr0(arr1_addr0),
    .addr1(arr1_addr1),
    .clk(arr1_clk),
    .done(arr1_done),
    .read_data(arr1_read_data),
    .reset(arr1_reset),
    .write_data(arr1_write_data),
    .write_en(arr1_write_en)
);
comb_mem_d2 # (
    .D0_IDX_SIZE(32),
    .D0_SIZE(5),
    .D1_IDX_SIZE(32),
    .D1_SIZE(7),
    .WIDTH(32)
) arr2 (
    .addr0(arr2_addr0),
    .addr1(arr2_addr1),
    .clk(arr2_clk),
    .done(arr2_done),
    .read_data(arr2_read_data),
    .reset(arr2_reset),
    .write_data(arr2_write_data),
    .write_en(arr2_write_en)
);
comb_mem_d2 # (
    .D0_IDX_SIZE(32),
    .D0_SIZE(6),
    .D1_IDX_SIZE(32),
    .D1_SIZE(7),
    .WIDTH(32)
) arrOut (
    .addr0(arrOut_addr0),
    .addr1(arrOut_addr1),
    .clk(arrOut_clk),
    .done(arrOut_done),
    .read_data(arrOut_read_data),
    .reset(arrOut_reset),
    .write_data(arrOut_write_data),
    .write_en(arrOut_write_en)
);
std_reg # (
    .WIDTH(32)
) i (
    .clk(i_clk),
    .done(i_done),
    .in(i_in),
    .out(i_out),
    .reset(i_reset),
    .write_en(i_write_en)
);
std_reg # (
    .WIDTH(32)
) j (
    .clk(j_clk),
    .done(j_done),
    .in(j_in),
    .out(j_out),
    .reset(j_reset),
    .write_en(j_write_en)
);
std_reg # (
    .WIDTH(32)
) k (
    .clk(k_clk),
    .done(k_done),
    .in(k_in),
    .out(k_out),
    .reset(k_reset),
    .write_en(k_write_en)
);
std_lt # (
    .WIDTH(32)
) ltI (
    .left(ltI_left),
    .out(ltI_out),
    .right(ltI_right)
);
std_add # (
    .WIDTH(32)
) add1 (
    .left(add1_left),
    .out(add1_out),
    .right(add1_right)
);
std_add # (
    .WIDTH(32)
) add2 (
    .left(add2_left),
    .out(add2_out),
    .right(add2_right)
);
std_mult_pipe # (
    .WIDTH(32)
) multE (
    .clk(multE_clk),
    .done(multE_done),
    .go(multE_go),
    .left(multE_left),
    .out(multE_out),
    .reset(multE_reset),
    .right(multE_right)
);
std_reg # (
    .WIDTH(32)
) outE (
    .clk(outE_clk),
    .done(outE_done),
    .in(outE_in),
    .out(outE_out),
    .reset(outE_reset),
    .write_en(outE_write_en)
);
std_add # (
    .WIDTH(32)
) addOut (
    .left(addOut_left),
    .out(addOut_out),
    .right(addOut_right)
);
std_reg # (
    .WIDTH(32)
) element1 (
    .clk(element1_clk),
    .done(element1_done),
    .in(element1_in),
    .out(element1_out),
    .reset(element1_reset),
    .write_en(element1_write_en)
);
std_reg # (
    .WIDTH(32)
) element2 (
    .clk(element2_clk),
    .done(element2_done),
    .in(element2_in),
    .out(element2_out),
    .reset(element2_reset),
    .write_en(element2_write_en)
);
std_reg # (
    .WIDTH(1)
) comb_reg (
    .clk(comb_reg_clk),
    .done(comb_reg_done),
    .in(comb_reg_in),
    .out(comb_reg_out),
    .reset(comb_reg_reset),
    .write_en(comb_reg_write_en)
);
std_reg # (
    .WIDTH(1)
) comb_reg0 (
    .clk(comb_reg0_clk),
    .done(comb_reg0_done),
    .in(comb_reg0_in),
    .out(comb_reg0_out),
    .reset(comb_reg0_reset),
    .write_en(comb_reg0_write_en)
);
std_reg # (
    .WIDTH(1)
) comb_reg1 (
    .clk(comb_reg1_clk),
    .done(comb_reg1_done),
    .in(comb_reg1_in),
    .out(comb_reg1_out),
    .reset(comb_reg1_reset),
    .write_en(comb_reg1_write_en)
);
std_reg # (
    .WIDTH(3)
) fsm (
    .clk(fsm_clk),
    .done(fsm_done),
    .in(fsm_in),
    .out(fsm_out),
    .reset(fsm_reset),
    .write_en(fsm_write_en)
);
undef # (
    .WIDTH(1)
) ud1 (
    .out(ud1_out)
);
undef # (
    .WIDTH(1)
) ud2 (
    .out(ud2_out)
);
std_add # (
    .WIDTH(3)
) adder (
    .left(adder_left),
    .out(adder_out),
    .right(adder_right)
);
undef # (
    .WIDTH(1)
) ud3 (
    .out(ud3_out)
);
undef # (
    .WIDTH(1)
) ud4 (
    .out(ud4_out)
);
undef # (
    .WIDTH(1)
) ud5 (
    .out(ud5_out)
);
std_reg # (
    .WIDTH(1)
) signal_reg (
    .clk(signal_reg_clk),
    .done(signal_reg_done),
    .in(signal_reg_in),
    .out(signal_reg_out),
    .reset(signal_reg_reset),
    .write_en(signal_reg_write_en)
);
std_reg # (
    .WIDTH(1)
) pd (
    .clk(pd_clk),
    .done(pd_done),
    .in(pd_in),
    .out(pd_out),
    .reset(pd_reset),
    .write_en(pd_write_en)
);
std_reg # (
    .WIDTH(3)
) fsm0 (
    .clk(fsm0_clk),
    .done(fsm0_done),
    .in(fsm0_in),
    .out(fsm0_out),
    .reset(fsm0_reset),
    .write_en(fsm0_write_en)
);
std_reg # (
    .WIDTH(1)
) pd0 (
    .clk(pd0_clk),
    .done(pd0_done),
    .in(pd0_in),
    .out(pd0_out),
    .reset(pd0_reset),
    .write_en(pd0_write_en)
);
std_reg # (
    .WIDTH(1)
) pd1 (
    .clk(pd1_clk),
    .done(pd1_done),
    .in(pd1_in),
    .out(pd1_out),
    .reset(pd1_reset),
    .write_en(pd1_write_en)
);
std_reg # (
    .WIDTH(3)
) fsm1 (
    .clk(fsm1_clk),
    .done(fsm1_done),
    .in(fsm1_in),
    .out(fsm1_out),
    .reset(fsm1_reset),
    .write_en(fsm1_write_en)
);
std_reg # (
    .WIDTH(1)
) pd2 (
    .clk(pd2_clk),
    .done(pd2_done),
    .in(pd2_in),
    .out(pd2_out),
    .reset(pd2_reset),
    .write_en(pd2_write_en)
);
std_reg # (
    .WIDTH(3)
) fsm2 (
    .clk(fsm2_clk),
    .done(fsm2_done),
    .in(fsm2_in),
    .out(fsm2_out),
    .reset(fsm2_reset),
    .write_en(fsm2_write_en)
);
std_wire # (
    .WIDTH(1)
) writeArrOut_go (
    .in(writeArrOut_go_in),
    .out(writeArrOut_go_out)
);
std_wire # (
    .WIDTH(1)
) writeArrOut_done (
    .in(writeArrOut_done_in),
    .out(writeArrOut_done_out)
);
std_wire # (
    .WIDTH(1)
) invoke0_go (
    .in(invoke0_go_in),
    .out(invoke0_go_out)
);
std_wire # (
    .WIDTH(1)
) invoke0_done (
    .in(invoke0_done_in),
    .out(invoke0_done_out)
);
std_wire # (
    .WIDTH(1)
) invoke1_go (
    .in(invoke1_go_in),
    .out(invoke1_go_out)
);
std_wire # (
    .WIDTH(1)
) invoke1_done (
    .in(invoke1_done_in),
    .out(invoke1_done_out)
);
std_wire # (
    .WIDTH(1)
) invoke7_go (
    .in(invoke7_go_in),
    .out(invoke7_go_out)
);
std_wire # (
    .WIDTH(1)
) invoke7_done (
    .in(invoke7_done_in),
    .out(invoke7_done_out)
);
std_wire # (
    .WIDTH(1)
) invoke8_go (
    .in(invoke8_go_in),
    .out(invoke8_go_out)
);
std_wire # (
    .WIDTH(1)
) invoke8_done (
    .in(invoke8_done_in),
    .out(invoke8_done_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_static_par_thread_go (
    .in(early_reset_static_par_thread_go_in),
    .out(early_reset_static_par_thread_go_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_static_par_thread_done (
    .in(early_reset_static_par_thread_done_in),
    .out(early_reset_static_par_thread_done_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_condK0_go (
    .in(early_reset_condK0_go_in),
    .out(early_reset_condK0_go_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_condK0_done (
    .in(early_reset_condK0_done_in),
    .out(early_reset_condK0_done_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_static_seq_go (
    .in(early_reset_static_seq_go_in),
    .out(early_reset_static_seq_go_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_static_seq_done (
    .in(early_reset_static_seq_done_in),
    .out(early_reset_static_seq_done_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_condJ00_go (
    .in(early_reset_condJ00_go_in),
    .out(early_reset_condJ00_go_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_condJ00_done (
    .in(early_reset_condJ00_done_in),
    .out(early_reset_condJ00_done_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_condI00_go (
    .in(early_reset_condI00_go_in),
    .out(early_reset_condI00_go_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_condI00_done (
    .in(early_reset_condI00_done_in),
    .out(early_reset_condI00_done_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_condI00_go (
    .in(wrapper_early_reset_condI00_go_in),
    .out(wrapper_early_reset_condI00_go_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_condI00_done (
    .in(wrapper_early_reset_condI00_done_in),
    .out(wrapper_early_reset_condI00_done_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_condJ00_go (
    .in(wrapper_early_reset_condJ00_go_in),
    .out(wrapper_early_reset_condJ00_go_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_condJ00_done (
    .in(wrapper_early_reset_condJ00_done_in),
    .out(wrapper_early_reset_condJ00_done_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_static_par_thread_go (
    .in(wrapper_early_reset_static_par_thread_go_in),
    .out(wrapper_early_reset_static_par_thread_go_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_static_par_thread_done (
    .in(wrapper_early_reset_static_par_thread_done_in),
    .out(wrapper_early_reset_static_par_thread_done_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_condK0_go (
    .in(wrapper_early_reset_condK0_go_in),
    .out(wrapper_early_reset_condK0_go_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_condK0_done (
    .in(wrapper_early_reset_condK0_done_in),
    .out(wrapper_early_reset_condK0_done_out)
);
std_wire # (
    .WIDTH(1)
) while_wrapper_early_reset_static_seq_go (
    .in(while_wrapper_early_reset_static_seq_go_in),
    .out(while_wrapper_early_reset_static_seq_go_out)
);
std_wire # (
    .WIDTH(1)
) while_wrapper_early_reset_static_seq_done (
    .in(while_wrapper_early_reset_static_seq_done_in),
    .out(while_wrapper_early_reset_static_seq_done_out)
);
std_wire # (
    .WIDTH(1)
) par0_go (
    .in(par0_go_in),
    .out(par0_go_out)
);
std_wire # (
    .WIDTH(1)
) par0_done (
    .in(par0_done_in),
    .out(par0_done_out)
);
std_wire # (
    .WIDTH(1)
) tdcc_go (
    .in(tdcc_go_in),
    .out(tdcc_go_out)
);
std_wire # (
    .WIDTH(1)
) tdcc_done (
    .in(tdcc_done_in),
    .out(tdcc_done_out)
);
std_wire # (
    .WIDTH(1)
) par1_go (
    .in(par1_go_in),
    .out(par1_go_out)
);
std_wire # (
    .WIDTH(1)
) par1_done (
    .in(par1_done_in),
    .out(par1_done_out)
);
std_wire # (
    .WIDTH(1)
) tdcc0_go (
    .in(tdcc0_go_in),
    .out(tdcc0_go_out)
);
std_wire # (
    .WIDTH(1)
) tdcc0_done (
    .in(tdcc0_done_in),
    .out(tdcc0_done_out)
);
std_wire # (
    .WIDTH(1)
) tdcc1_go (
    .in(tdcc1_go_in),
    .out(tdcc1_go_out)
);
std_wire # (
    .WIDTH(1)
) tdcc1_done (
    .in(tdcc1_done_in),
    .out(tdcc1_done_out)
);
wire _guard0 = 1;
wire _guard1 = fsm_out == 3'd0;
wire _guard2 = early_reset_static_seq_go_out;
wire _guard3 = _guard1 & _guard2;
wire _guard4 = fsm_out == 3'd0;
wire _guard5 = early_reset_static_seq_go_out;
wire _guard6 = _guard4 & _guard5;
wire _guard7 = invoke1_go_out;
wire _guard8 = invoke7_go_out;
wire _guard9 = _guard7 | _guard8;
wire _guard10 = invoke1_go_out;
wire _guard11 = invoke7_go_out;
wire _guard12 = invoke8_go_out;
wire _guard13 = invoke8_go_out;
wire _guard14 = tdcc1_done_out;
wire _guard15 = fsm_out != 3'd5;
wire _guard16 = early_reset_static_seq_go_out;
wire _guard17 = _guard15 & _guard16;
wire _guard18 = fsm_out == 3'd5;
wire _guard19 = early_reset_static_seq_go_out;
wire _guard20 = _guard18 & _guard19;
wire _guard21 = _guard17 | _guard20;
wire _guard22 = fsm_out != 3'd5;
wire _guard23 = early_reset_static_seq_go_out;
wire _guard24 = _guard22 & _guard23;
wire _guard25 = fsm_out == 3'd5;
wire _guard26 = early_reset_static_seq_go_out;
wire _guard27 = _guard25 & _guard26;
wire _guard28 = early_reset_static_seq_go_out;
wire _guard29 = early_reset_static_seq_go_out;
wire _guard30 = wrapper_early_reset_static_par_thread_done_out;
wire _guard31 = ~_guard30;
wire _guard32 = fsm0_out == 3'd0;
wire _guard33 = _guard31 & _guard32;
wire _guard34 = tdcc_go_out;
wire _guard35 = _guard33 & _guard34;
wire _guard36 = fsm1_out == 3'd4;
wire _guard37 = invoke7_go_out;
wire _guard38 = invoke7_go_out;
wire _guard39 = early_reset_condI00_go_out;
wire _guard40 = early_reset_condI00_go_out;
wire _guard41 = early_reset_condJ00_go_out;
wire _guard42 = early_reset_condK0_go_out;
wire _guard43 = fsm_out == 3'd5;
wire _guard44 = early_reset_static_seq_go_out;
wire _guard45 = _guard43 & _guard44;
wire _guard46 = _guard42 | _guard45;
wire _guard47 = early_reset_condI00_go_out;
wire _guard48 = early_reset_condK0_go_out;
wire _guard49 = fsm_out == 3'd5;
wire _guard50 = early_reset_static_seq_go_out;
wire _guard51 = _guard49 & _guard50;
wire _guard52 = _guard48 | _guard51;
wire _guard53 = early_reset_condJ00_go_out;
wire _guard54 = early_reset_condI00_go_out;
wire _guard55 = early_reset_condK0_go_out;
wire _guard56 = fsm_out == 3'd5;
wire _guard57 = early_reset_static_seq_go_out;
wire _guard58 = _guard56 & _guard57;
wire _guard59 = _guard55 | _guard58;
wire _guard60 = early_reset_condK0_go_out;
wire _guard61 = fsm_out == 3'd5;
wire _guard62 = early_reset_static_seq_go_out;
wire _guard63 = _guard61 & _guard62;
wire _guard64 = _guard60 | _guard63;
wire _guard65 = fsm1_out == 3'd4;
wire _guard66 = fsm1_out == 3'd0;
wire _guard67 = invoke1_done_out;
wire _guard68 = _guard66 & _guard67;
wire _guard69 = tdcc0_go_out;
wire _guard70 = _guard68 & _guard69;
wire _guard71 = _guard65 | _guard70;
wire _guard72 = fsm1_out == 3'd1;
wire _guard73 = wrapper_early_reset_condJ00_done_out;
wire _guard74 = comb_reg0_out;
wire _guard75 = _guard73 & _guard74;
wire _guard76 = _guard72 & _guard75;
wire _guard77 = tdcc0_go_out;
wire _guard78 = _guard76 & _guard77;
wire _guard79 = _guard71 | _guard78;
wire _guard80 = fsm1_out == 3'd3;
wire _guard81 = wrapper_early_reset_condJ00_done_out;
wire _guard82 = comb_reg0_out;
wire _guard83 = _guard81 & _guard82;
wire _guard84 = _guard80 & _guard83;
wire _guard85 = tdcc0_go_out;
wire _guard86 = _guard84 & _guard85;
wire _guard87 = _guard79 | _guard86;
wire _guard88 = fsm1_out == 3'd2;
wire _guard89 = par0_done_out;
wire _guard90 = _guard88 & _guard89;
wire _guard91 = tdcc0_go_out;
wire _guard92 = _guard90 & _guard91;
wire _guard93 = _guard87 | _guard92;
wire _guard94 = fsm1_out == 3'd1;
wire _guard95 = wrapper_early_reset_condJ00_done_out;
wire _guard96 = comb_reg0_out;
wire _guard97 = ~_guard96;
wire _guard98 = _guard95 & _guard97;
wire _guard99 = _guard94 & _guard98;
wire _guard100 = tdcc0_go_out;
wire _guard101 = _guard99 & _guard100;
wire _guard102 = _guard93 | _guard101;
wire _guard103 = fsm1_out == 3'd3;
wire _guard104 = wrapper_early_reset_condJ00_done_out;
wire _guard105 = comb_reg0_out;
wire _guard106 = ~_guard105;
wire _guard107 = _guard104 & _guard106;
wire _guard108 = _guard103 & _guard107;
wire _guard109 = tdcc0_go_out;
wire _guard110 = _guard108 & _guard109;
wire _guard111 = _guard102 | _guard110;
wire _guard112 = fsm1_out == 3'd1;
wire _guard113 = wrapper_early_reset_condJ00_done_out;
wire _guard114 = comb_reg0_out;
wire _guard115 = _guard113 & _guard114;
wire _guard116 = _guard112 & _guard115;
wire _guard117 = tdcc0_go_out;
wire _guard118 = _guard116 & _guard117;
wire _guard119 = fsm1_out == 3'd3;
wire _guard120 = wrapper_early_reset_condJ00_done_out;
wire _guard121 = comb_reg0_out;
wire _guard122 = _guard120 & _guard121;
wire _guard123 = _guard119 & _guard122;
wire _guard124 = tdcc0_go_out;
wire _guard125 = _guard123 & _guard124;
wire _guard126 = _guard118 | _guard125;
wire _guard127 = fsm1_out == 3'd1;
wire _guard128 = wrapper_early_reset_condJ00_done_out;
wire _guard129 = comb_reg0_out;
wire _guard130 = ~_guard129;
wire _guard131 = _guard128 & _guard130;
wire _guard132 = _guard127 & _guard131;
wire _guard133 = tdcc0_go_out;
wire _guard134 = _guard132 & _guard133;
wire _guard135 = fsm1_out == 3'd3;
wire _guard136 = wrapper_early_reset_condJ00_done_out;
wire _guard137 = comb_reg0_out;
wire _guard138 = ~_guard137;
wire _guard139 = _guard136 & _guard138;
wire _guard140 = _guard135 & _guard139;
wire _guard141 = tdcc0_go_out;
wire _guard142 = _guard140 & _guard141;
wire _guard143 = _guard134 | _guard142;
wire _guard144 = fsm1_out == 3'd0;
wire _guard145 = invoke1_done_out;
wire _guard146 = _guard144 & _guard145;
wire _guard147 = tdcc0_go_out;
wire _guard148 = _guard146 & _guard147;
wire _guard149 = fsm1_out == 3'd4;
wire _guard150 = fsm1_out == 3'd2;
wire _guard151 = par0_done_out;
wire _guard152 = _guard150 & _guard151;
wire _guard153 = tdcc0_go_out;
wire _guard154 = _guard152 & _guard153;
wire _guard155 = wrapper_early_reset_condI00_done_out;
wire _guard156 = ~_guard155;
wire _guard157 = fsm2_out == 3'd1;
wire _guard158 = _guard156 & _guard157;
wire _guard159 = tdcc1_go_out;
wire _guard160 = _guard158 & _guard159;
wire _guard161 = wrapper_early_reset_condI00_done_out;
wire _guard162 = ~_guard161;
wire _guard163 = fsm2_out == 3'd3;
wire _guard164 = _guard162 & _guard163;
wire _guard165 = tdcc1_go_out;
wire _guard166 = _guard164 & _guard165;
wire _guard167 = _guard160 | _guard166;
wire _guard168 = while_wrapper_early_reset_static_seq_done_out;
wire _guard169 = ~_guard168;
wire _guard170 = fsm0_out == 3'd2;
wire _guard171 = _guard169 & _guard170;
wire _guard172 = tdcc_go_out;
wire _guard173 = _guard171 & _guard172;
wire _guard174 = par1_done_out;
wire _guard175 = ~_guard174;
wire _guard176 = fsm2_out == 3'd2;
wire _guard177 = _guard175 & _guard176;
wire _guard178 = tdcc1_go_out;
wire _guard179 = _guard177 & _guard178;
wire _guard180 = fsm_out == 3'd0;
wire _guard181 = early_reset_static_seq_go_out;
wire _guard182 = _guard180 & _guard181;
wire _guard183 = fsm_out == 3'd0;
wire _guard184 = early_reset_static_seq_go_out;
wire _guard185 = _guard183 & _guard184;
wire _guard186 = early_reset_condJ00_go_out;
wire _guard187 = early_reset_condJ00_go_out;
wire _guard188 = pd1_out;
wire _guard189 = pd2_out;
wire _guard190 = _guard188 & _guard189;
wire _guard191 = invoke8_done_out;
wire _guard192 = par1_go_out;
wire _guard193 = _guard191 & _guard192;
wire _guard194 = _guard190 | _guard193;
wire _guard195 = invoke8_done_out;
wire _guard196 = par1_go_out;
wire _guard197 = _guard195 & _guard196;
wire _guard198 = pd1_out;
wire _guard199 = pd2_out;
wire _guard200 = _guard198 & _guard199;
wire _guard201 = invoke0_done_out;
wire _guard202 = ~_guard201;
wire _guard203 = fsm2_out == 3'd0;
wire _guard204 = _guard202 & _guard203;
wire _guard205 = tdcc1_go_out;
wire _guard206 = _guard204 & _guard205;
wire _guard207 = pd0_out;
wire _guard208 = tdcc_done_out;
wire _guard209 = _guard207 | _guard208;
wire _guard210 = ~_guard209;
wire _guard211 = par0_go_out;
wire _guard212 = _guard210 & _guard211;
wire _guard213 = fsm_out == 3'd0;
wire _guard214 = early_reset_static_seq_go_out;
wire _guard215 = _guard213 & _guard214;
wire _guard216 = fsm_out == 3'd0;
wire _guard217 = early_reset_static_seq_go_out;
wire _guard218 = _guard216 & _guard217;
wire _guard219 = fsm0_out == 3'd4;
wire _guard220 = fsm0_out == 3'd0;
wire _guard221 = wrapper_early_reset_static_par_thread_done_out;
wire _guard222 = _guard220 & _guard221;
wire _guard223 = tdcc_go_out;
wire _guard224 = _guard222 & _guard223;
wire _guard225 = _guard219 | _guard224;
wire _guard226 = fsm0_out == 3'd1;
wire _guard227 = wrapper_early_reset_condK0_done_out;
wire _guard228 = _guard226 & _guard227;
wire _guard229 = tdcc_go_out;
wire _guard230 = _guard228 & _guard229;
wire _guard231 = _guard225 | _guard230;
wire _guard232 = fsm0_out == 3'd2;
wire _guard233 = while_wrapper_early_reset_static_seq_done_out;
wire _guard234 = _guard232 & _guard233;
wire _guard235 = tdcc_go_out;
wire _guard236 = _guard234 & _guard235;
wire _guard237 = _guard231 | _guard236;
wire _guard238 = fsm0_out == 3'd3;
wire _guard239 = writeArrOut_done_out;
wire _guard240 = _guard238 & _guard239;
wire _guard241 = tdcc_go_out;
wire _guard242 = _guard240 & _guard241;
wire _guard243 = _guard237 | _guard242;
wire _guard244 = fsm0_out == 3'd1;
wire _guard245 = wrapper_early_reset_condK0_done_out;
wire _guard246 = _guard244 & _guard245;
wire _guard247 = tdcc_go_out;
wire _guard248 = _guard246 & _guard247;
wire _guard249 = fsm0_out == 3'd3;
wire _guard250 = writeArrOut_done_out;
wire _guard251 = _guard249 & _guard250;
wire _guard252 = tdcc_go_out;
wire _guard253 = _guard251 & _guard252;
wire _guard254 = fsm0_out == 3'd0;
wire _guard255 = wrapper_early_reset_static_par_thread_done_out;
wire _guard256 = _guard254 & _guard255;
wire _guard257 = tdcc_go_out;
wire _guard258 = _guard256 & _guard257;
wire _guard259 = fsm0_out == 3'd4;
wire _guard260 = fsm0_out == 3'd2;
wire _guard261 = while_wrapper_early_reset_static_seq_done_out;
wire _guard262 = _guard260 & _guard261;
wire _guard263 = tdcc_go_out;
wire _guard264 = _guard262 & _guard263;
wire _guard265 = fsm2_out == 3'd4;
wire _guard266 = fsm2_out == 3'd0;
wire _guard267 = invoke0_done_out;
wire _guard268 = _guard266 & _guard267;
wire _guard269 = tdcc1_go_out;
wire _guard270 = _guard268 & _guard269;
wire _guard271 = _guard265 | _guard270;
wire _guard272 = fsm2_out == 3'd1;
wire _guard273 = wrapper_early_reset_condI00_done_out;
wire _guard274 = comb_reg_out;
wire _guard275 = _guard273 & _guard274;
wire _guard276 = _guard272 & _guard275;
wire _guard277 = tdcc1_go_out;
wire _guard278 = _guard276 & _guard277;
wire _guard279 = _guard271 | _guard278;
wire _guard280 = fsm2_out == 3'd3;
wire _guard281 = wrapper_early_reset_condI00_done_out;
wire _guard282 = comb_reg_out;
wire _guard283 = _guard281 & _guard282;
wire _guard284 = _guard280 & _guard283;
wire _guard285 = tdcc1_go_out;
wire _guard286 = _guard284 & _guard285;
wire _guard287 = _guard279 | _guard286;
wire _guard288 = fsm2_out == 3'd2;
wire _guard289 = par1_done_out;
wire _guard290 = _guard288 & _guard289;
wire _guard291 = tdcc1_go_out;
wire _guard292 = _guard290 & _guard291;
wire _guard293 = _guard287 | _guard292;
wire _guard294 = fsm2_out == 3'd1;
wire _guard295 = wrapper_early_reset_condI00_done_out;
wire _guard296 = comb_reg_out;
wire _guard297 = ~_guard296;
wire _guard298 = _guard295 & _guard297;
wire _guard299 = _guard294 & _guard298;
wire _guard300 = tdcc1_go_out;
wire _guard301 = _guard299 & _guard300;
wire _guard302 = _guard293 | _guard301;
wire _guard303 = fsm2_out == 3'd3;
wire _guard304 = wrapper_early_reset_condI00_done_out;
wire _guard305 = comb_reg_out;
wire _guard306 = ~_guard305;
wire _guard307 = _guard304 & _guard306;
wire _guard308 = _guard303 & _guard307;
wire _guard309 = tdcc1_go_out;
wire _guard310 = _guard308 & _guard309;
wire _guard311 = _guard302 | _guard310;
wire _guard312 = fsm2_out == 3'd1;
wire _guard313 = wrapper_early_reset_condI00_done_out;
wire _guard314 = comb_reg_out;
wire _guard315 = _guard313 & _guard314;
wire _guard316 = _guard312 & _guard315;
wire _guard317 = tdcc1_go_out;
wire _guard318 = _guard316 & _guard317;
wire _guard319 = fsm2_out == 3'd3;
wire _guard320 = wrapper_early_reset_condI00_done_out;
wire _guard321 = comb_reg_out;
wire _guard322 = _guard320 & _guard321;
wire _guard323 = _guard319 & _guard322;
wire _guard324 = tdcc1_go_out;
wire _guard325 = _guard323 & _guard324;
wire _guard326 = _guard318 | _guard325;
wire _guard327 = fsm2_out == 3'd1;
wire _guard328 = wrapper_early_reset_condI00_done_out;
wire _guard329 = comb_reg_out;
wire _guard330 = ~_guard329;
wire _guard331 = _guard328 & _guard330;
wire _guard332 = _guard327 & _guard331;
wire _guard333 = tdcc1_go_out;
wire _guard334 = _guard332 & _guard333;
wire _guard335 = fsm2_out == 3'd3;
wire _guard336 = wrapper_early_reset_condI00_done_out;
wire _guard337 = comb_reg_out;
wire _guard338 = ~_guard337;
wire _guard339 = _guard336 & _guard338;
wire _guard340 = _guard335 & _guard339;
wire _guard341 = tdcc1_go_out;
wire _guard342 = _guard340 & _guard341;
wire _guard343 = _guard334 | _guard342;
wire _guard344 = fsm2_out == 3'd0;
wire _guard345 = invoke0_done_out;
wire _guard346 = _guard344 & _guard345;
wire _guard347 = tdcc1_go_out;
wire _guard348 = _guard346 & _guard347;
wire _guard349 = fsm2_out == 3'd4;
wire _guard350 = fsm2_out == 3'd2;
wire _guard351 = par1_done_out;
wire _guard352 = _guard350 & _guard351;
wire _guard353 = tdcc1_go_out;
wire _guard354 = _guard352 & _guard353;
wire _guard355 = pd1_out;
wire _guard356 = invoke8_done_out;
wire _guard357 = _guard355 | _guard356;
wire _guard358 = ~_guard357;
wire _guard359 = par1_go_out;
wire _guard360 = _guard358 & _guard359;
wire _guard361 = pd2_out;
wire _guard362 = tdcc0_done_out;
wire _guard363 = _guard361 | _guard362;
wire _guard364 = ~_guard363;
wire _guard365 = par1_go_out;
wire _guard366 = _guard364 & _guard365;
wire _guard367 = early_reset_static_par_thread_go_out;
wire _guard368 = fsm_out == 3'd0;
wire _guard369 = early_reset_static_seq_go_out;
wire _guard370 = _guard368 & _guard369;
wire _guard371 = _guard367 | _guard370;
wire _guard372 = early_reset_static_par_thread_go_out;
wire _guard373 = fsm_out == 3'd0;
wire _guard374 = early_reset_static_seq_go_out;
wire _guard375 = _guard373 & _guard374;
wire _guard376 = pd_out;
wire _guard377 = pd0_out;
wire _guard378 = _guard376 & _guard377;
wire _guard379 = pd1_out;
wire _guard380 = pd2_out;
wire _guard381 = _guard379 & _guard380;
wire _guard382 = tdcc0_done_out;
wire _guard383 = par1_go_out;
wire _guard384 = _guard382 & _guard383;
wire _guard385 = _guard381 | _guard384;
wire _guard386 = tdcc0_done_out;
wire _guard387 = par1_go_out;
wire _guard388 = _guard386 & _guard387;
wire _guard389 = pd1_out;
wire _guard390 = pd2_out;
wire _guard391 = _guard389 & _guard390;
wire _guard392 = invoke1_done_out;
wire _guard393 = ~_guard392;
wire _guard394 = fsm1_out == 3'd0;
wire _guard395 = _guard393 & _guard394;
wire _guard396 = tdcc0_go_out;
wire _guard397 = _guard395 & _guard396;
wire _guard398 = while_wrapper_early_reset_static_seq_go_out;
wire _guard399 = invoke0_go_out;
wire _guard400 = invoke8_go_out;
wire _guard401 = _guard399 | _guard400;
wire _guard402 = invoke8_go_out;
wire _guard403 = invoke0_go_out;
wire _guard404 = fsm_out >= 3'd1;
wire _guard405 = fsm_out < 3'd4;
wire _guard406 = _guard404 & _guard405;
wire _guard407 = early_reset_static_seq_go_out;
wire _guard408 = _guard406 & _guard407;
wire _guard409 = fsm_out >= 3'd1;
wire _guard410 = fsm_out < 3'd4;
wire _guard411 = _guard409 & _guard410;
wire _guard412 = early_reset_static_seq_go_out;
wire _guard413 = _guard411 & _guard412;
wire _guard414 = fsm_out >= 3'd1;
wire _guard415 = fsm_out < 3'd4;
wire _guard416 = _guard414 & _guard415;
wire _guard417 = early_reset_static_seq_go_out;
wire _guard418 = _guard416 & _guard417;
wire _guard419 = signal_reg_out;
wire _guard420 = _guard0 & _guard0;
wire _guard421 = signal_reg_out;
wire _guard422 = ~_guard421;
wire _guard423 = _guard420 & _guard422;
wire _guard424 = wrapper_early_reset_condI00_go_out;
wire _guard425 = _guard423 & _guard424;
wire _guard426 = _guard419 | _guard425;
wire _guard427 = _guard0 & _guard0;
wire _guard428 = signal_reg_out;
wire _guard429 = ~_guard428;
wire _guard430 = _guard427 & _guard429;
wire _guard431 = wrapper_early_reset_condJ00_go_out;
wire _guard432 = _guard430 & _guard431;
wire _guard433 = _guard426 | _guard432;
wire _guard434 = _guard0 & _guard0;
wire _guard435 = signal_reg_out;
wire _guard436 = ~_guard435;
wire _guard437 = _guard434 & _guard436;
wire _guard438 = wrapper_early_reset_static_par_thread_go_out;
wire _guard439 = _guard437 & _guard438;
wire _guard440 = _guard433 | _guard439;
wire _guard441 = _guard0 & _guard0;
wire _guard442 = signal_reg_out;
wire _guard443 = ~_guard442;
wire _guard444 = _guard441 & _guard443;
wire _guard445 = wrapper_early_reset_condK0_go_out;
wire _guard446 = _guard444 & _guard445;
wire _guard447 = _guard440 | _guard446;
wire _guard448 = _guard0 & _guard0;
wire _guard449 = signal_reg_out;
wire _guard450 = ~_guard449;
wire _guard451 = _guard448 & _guard450;
wire _guard452 = wrapper_early_reset_condI00_go_out;
wire _guard453 = _guard451 & _guard452;
wire _guard454 = _guard0 & _guard0;
wire _guard455 = signal_reg_out;
wire _guard456 = ~_guard455;
wire _guard457 = _guard454 & _guard456;
wire _guard458 = wrapper_early_reset_condJ00_go_out;
wire _guard459 = _guard457 & _guard458;
wire _guard460 = _guard453 | _guard459;
wire _guard461 = _guard0 & _guard0;
wire _guard462 = signal_reg_out;
wire _guard463 = ~_guard462;
wire _guard464 = _guard461 & _guard463;
wire _guard465 = wrapper_early_reset_static_par_thread_go_out;
wire _guard466 = _guard464 & _guard465;
wire _guard467 = _guard460 | _guard466;
wire _guard468 = _guard0 & _guard0;
wire _guard469 = signal_reg_out;
wire _guard470 = ~_guard469;
wire _guard471 = _guard468 & _guard470;
wire _guard472 = wrapper_early_reset_condK0_go_out;
wire _guard473 = _guard471 & _guard472;
wire _guard474 = _guard467 | _guard473;
wire _guard475 = signal_reg_out;
wire _guard476 = wrapper_early_reset_static_par_thread_go_out;
wire _guard477 = wrapper_early_reset_condJ00_done_out;
wire _guard478 = ~_guard477;
wire _guard479 = fsm1_out == 3'd1;
wire _guard480 = _guard478 & _guard479;
wire _guard481 = tdcc0_go_out;
wire _guard482 = _guard480 & _guard481;
wire _guard483 = wrapper_early_reset_condJ00_done_out;
wire _guard484 = ~_guard483;
wire _guard485 = fsm1_out == 3'd3;
wire _guard486 = _guard484 & _guard485;
wire _guard487 = tdcc0_go_out;
wire _guard488 = _guard486 & _guard487;
wire _guard489 = _guard482 | _guard488;
wire _guard490 = pd1_out;
wire _guard491 = pd2_out;
wire _guard492 = _guard490 & _guard491;
wire _guard493 = fsm2_out == 3'd4;
wire _guard494 = early_reset_static_par_thread_go_out;
wire _guard495 = fsm_out == 3'd4;
wire _guard496 = early_reset_static_seq_go_out;
wire _guard497 = _guard495 & _guard496;
wire _guard498 = _guard494 | _guard497;
wire _guard499 = early_reset_static_par_thread_go_out;
wire _guard500 = fsm_out == 3'd4;
wire _guard501 = early_reset_static_seq_go_out;
wire _guard502 = _guard500 & _guard501;
wire _guard503 = pd_out;
wire _guard504 = pd0_out;
wire _guard505 = _guard503 & _guard504;
wire _guard506 = invoke7_done_out;
wire _guard507 = par0_go_out;
wire _guard508 = _guard506 & _guard507;
wire _guard509 = _guard505 | _guard508;
wire _guard510 = invoke7_done_out;
wire _guard511 = par0_go_out;
wire _guard512 = _guard510 & _guard511;
wire _guard513 = pd_out;
wire _guard514 = pd0_out;
wire _guard515 = _guard513 & _guard514;
wire _guard516 = pd_out;
wire _guard517 = pd0_out;
wire _guard518 = _guard516 & _guard517;
wire _guard519 = tdcc_done_out;
wire _guard520 = par0_go_out;
wire _guard521 = _guard519 & _guard520;
wire _guard522 = _guard518 | _guard521;
wire _guard523 = tdcc_done_out;
wire _guard524 = par0_go_out;
wire _guard525 = _guard523 & _guard524;
wire _guard526 = pd_out;
wire _guard527 = pd0_out;
wire _guard528 = _guard526 & _guard527;
wire _guard529 = wrapper_early_reset_condI00_go_out;
wire _guard530 = signal_reg_out;
wire _guard531 = wrapper_early_reset_condK0_done_out;
wire _guard532 = ~_guard531;
wire _guard533 = fsm0_out == 3'd1;
wire _guard534 = _guard532 & _guard533;
wire _guard535 = tdcc_go_out;
wire _guard536 = _guard534 & _guard535;
wire _guard537 = writeArrOut_go_out;
wire _guard538 = writeArrOut_go_out;
wire _guard539 = writeArrOut_go_out;
wire _guard540 = signal_reg_out;
wire _guard541 = signal_reg_out;
wire _guard542 = signal_reg_out;
wire _guard543 = fsm0_out == 3'd4;
wire _guard544 = comb_reg1_out;
wire _guard545 = ~_guard544;
wire _guard546 = fsm_out == 3'd0;
wire _guard547 = _guard546 & _guard0;
wire _guard548 = _guard545 & _guard547;
wire _guard549 = fsm_out == 3'd0;
wire _guard550 = early_reset_static_seq_go_out;
wire _guard551 = _guard549 & _guard550;
wire _guard552 = fsm_out == 3'd0;
wire _guard553 = early_reset_static_seq_go_out;
wire _guard554 = _guard552 & _guard553;
wire _guard555 = fsm_out == 3'd4;
wire _guard556 = early_reset_static_seq_go_out;
wire _guard557 = _guard555 & _guard556;
wire _guard558 = fsm_out == 3'd4;
wire _guard559 = early_reset_static_seq_go_out;
wire _guard560 = _guard558 & _guard559;
wire _guard561 = writeArrOut_done_out;
wire _guard562 = ~_guard561;
wire _guard563 = fsm0_out == 3'd3;
wire _guard564 = _guard562 & _guard563;
wire _guard565 = tdcc_go_out;
wire _guard566 = _guard564 & _guard565;
wire _guard567 = wrapper_early_reset_condK0_go_out;
wire _guard568 = pd_out;
wire _guard569 = invoke7_done_out;
wire _guard570 = _guard568 | _guard569;
wire _guard571 = ~_guard570;
wire _guard572 = par0_go_out;
wire _guard573 = _guard571 & _guard572;
wire _guard574 = wrapper_early_reset_condJ00_go_out;
wire _guard575 = par0_done_out;
wire _guard576 = ~_guard575;
wire _guard577 = fsm1_out == 3'd2;
wire _guard578 = _guard576 & _guard577;
wire _guard579 = tdcc0_go_out;
wire _guard580 = _guard578 & _guard579;
assign element1_write_en = _guard3;
assign element1_clk = clk;
assign element1_reset = reset;
assign element1_in = arr1_read_data;
assign invoke7_done_in = j_done;
assign j_write_en = _guard9;
assign j_clk = clk;
assign j_reset = reset;
assign j_in =
  _guard10 ? 32'd0 :
  _guard11 ? add2_out :
  'x;
assign add1_left = i_out;
assign add1_right = 32'd1;
assign done = _guard14;
assign fsm_write_en = _guard21;
assign fsm_clk = clk;
assign fsm_reset = reset;
assign fsm_in =
  _guard24 ? adder_out :
  _guard27 ? 3'd0 :
  3'd0;
assign adder_left =
  _guard28 ? fsm_out :
  3'd0;
assign adder_right =
  _guard29 ? 3'd1 :
  3'd0;
assign wrapper_early_reset_static_par_thread_go_in = _guard35;
assign tdcc0_done_in = _guard36;
assign add2_left = j_out;
assign add2_right = 32'd1;
assign comb_reg_write_en = _guard39;
assign comb_reg_clk = clk;
assign comb_reg_reset = reset;
assign comb_reg_in =
  _guard40 ? ltI_out :
  1'd0;
assign writeArrOut_done_in = arrOut_done;
assign ltI_left =
  _guard41 ? j_out :
  _guard46 ? k_out :
  _guard47 ? i_out :
  32'd0;
assign ltI_right =
  _guard52 ? 32'd5 :
  _guard53 ? 32'd7 :
  _guard54 ? 32'd6 :
  32'd0;
assign comb_reg1_write_en = _guard59;
assign comb_reg1_clk = clk;
assign comb_reg1_reset = reset;
assign comb_reg1_in =
  _guard64 ? ltI_out :
  1'd0;
assign fsm1_write_en = _guard111;
assign fsm1_clk = clk;
assign fsm1_reset = reset;
assign fsm1_in =
  _guard126 ? 3'd2 :
  _guard143 ? 3'd4 :
  _guard148 ? 3'd1 :
  _guard149 ? 3'd0 :
  _guard154 ? 3'd3 :
  3'd0;
assign wrapper_early_reset_condI00_go_in = _guard167;
assign while_wrapper_early_reset_static_seq_go_in = _guard173;
assign par1_go_in = _guard179;
assign arr2_write_en = 1'd0;
assign arr2_clk = clk;
assign arr2_addr0 =
  _guard182 ? j_out :
  32'd0;
assign arr2_reset = reset;
assign arr2_addr1 =
  _guard185 ? k_out :
  32'd0;
assign comb_reg0_write_en = _guard186;
assign comb_reg0_clk = clk;
assign comb_reg0_reset = reset;
assign comb_reg0_in =
  _guard187 ? ltI_out :
  1'd0;
assign pd1_write_en = _guard194;
assign pd1_clk = clk;
assign pd1_reset = reset;
assign pd1_in =
  _guard197 ? 1'd1 :
  _guard200 ? 1'd0 :
  1'd0;
assign invoke0_go_in = _guard206;
assign tdcc_go_in = _guard212;
assign element2_write_en = _guard215;
assign element2_clk = clk;
assign element2_reset = reset;
assign element2_in = arr2_read_data;
assign fsm0_write_en = _guard243;
assign fsm0_clk = clk;
assign fsm0_reset = reset;
assign fsm0_in =
  _guard248 ? 3'd2 :
  _guard253 ? 3'd4 :
  _guard258 ? 3'd1 :
  _guard259 ? 3'd0 :
  _guard264 ? 3'd3 :
  3'd0;
assign fsm2_write_en = _guard311;
assign fsm2_clk = clk;
assign fsm2_reset = reset;
assign fsm2_in =
  _guard326 ? 3'd2 :
  _guard343 ? 3'd4 :
  _guard348 ? 3'd1 :
  _guard349 ? 3'd0 :
  _guard354 ? 3'd3 :
  3'd0;
assign invoke8_go_in = _guard360;
assign tdcc0_go_in = _guard366;
assign k_write_en = _guard371;
assign k_clk = clk;
assign k_reset = reset;
assign k_in =
  _guard372 ? 32'd0 :
  _guard375 ? add2_out :
  'x;
assign invoke8_done_in = i_done;
assign par0_done_in = _guard378;
assign pd2_write_en = _guard385;
assign pd2_clk = clk;
assign pd2_reset = reset;
assign pd2_in =
  _guard388 ? 1'd1 :
  _guard391 ? 1'd0 :
  1'd0;
assign invoke0_done_in = i_done;
assign invoke1_go_in = _guard397;
assign early_reset_static_seq_go_in = _guard398;
assign i_write_en = _guard401;
assign i_clk = clk;
assign i_reset = reset;
assign i_in =
  _guard402 ? add1_out :
  _guard403 ? 32'd0 :
  'x;
assign multE_clk = clk;
assign multE_left = element1_out;
assign multE_go = _guard413;
assign multE_reset = reset;
assign multE_right = element2_out;
assign signal_reg_write_en = _guard447;
assign signal_reg_clk = clk;
assign signal_reg_reset = reset;
assign signal_reg_in =
  _guard474 ? 1'd1 :
  _guard475 ? 1'd0 :
  1'd0;
assign early_reset_static_par_thread_go_in = _guard476;
assign wrapper_early_reset_condJ00_go_in = _guard489;
assign par1_done_in = _guard492;
assign tdcc1_done_in = _guard493;
assign outE_write_en = _guard498;
assign outE_clk = clk;
assign outE_reset = reset;
assign outE_in =
  _guard499 ? 32'd0 :
  _guard502 ? addOut_out :
  'x;
assign pd_write_en = _guard509;
assign pd_clk = clk;
assign pd_reset = reset;
assign pd_in =
  _guard512 ? 1'd1 :
  _guard515 ? 1'd0 :
  1'd0;
assign pd0_write_en = _guard522;
assign pd0_clk = clk;
assign pd0_reset = reset;
assign pd0_in =
  _guard525 ? 1'd1 :
  _guard528 ? 1'd0 :
  1'd0;
assign early_reset_condI00_go_in = _guard529;
assign early_reset_condI00_done_in = ud5_out;
assign wrapper_early_reset_static_par_thread_done_in = _guard530;
assign wrapper_early_reset_condK0_go_in = _guard536;
assign arrOut_write_en = 1'd0;
assign arrOut_clk = clk;
assign arrOut_addr0 =
  _guard537 ? i_out :
  32'd0;
assign arrOut_reset = reset;
assign arrOut_write_data = outE_out;
assign arrOut_addr1 =
  _guard539 ? j_out :
  32'd0;
assign early_reset_static_seq_done_in = ud3_out;
assign wrapper_early_reset_condI00_done_in = _guard540;
assign wrapper_early_reset_condJ00_done_in = _guard541;
assign wrapper_early_reset_condK0_done_in = _guard542;
assign tdcc_done_in = _guard543;
assign while_wrapper_early_reset_static_seq_done_in = _guard548;
assign arr1_write_en = 1'd0;
assign arr1_clk = clk;
assign arr1_addr0 =
  _guard551 ? i_out :
  32'd0;
assign arr1_reset = reset;
assign arr1_addr1 =
  _guard554 ? k_out :
  32'd0;
assign addOut_left = multE_out;
assign addOut_right = outE_out;
assign writeArrOut_go_in = _guard566;
assign invoke1_done_in = j_done;
assign early_reset_static_par_thread_done_in = ud1_out;
assign early_reset_condK0_go_in = _guard567;
assign early_reset_condK0_done_in = ud2_out;
assign early_reset_condJ00_done_in = ud4_out;
assign tdcc1_go_in = go;
assign invoke7_go_in = _guard573;
assign early_reset_condJ00_go_in = _guard574;
assign par0_go_in = _guard580;
// COMPONENT END: main
endmodule
