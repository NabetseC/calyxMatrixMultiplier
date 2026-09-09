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
logic [31:0] add1_left;
logic [31:0] add1_right;
logic [31:0] add1_out;
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
logic [1:0] fsm_in;
logic fsm_write_en;
logic fsm_clk;
logic fsm_reset;
logic [1:0] fsm_out;
logic fsm_done;
logic [1:0] fsm0_in;
logic fsm0_write_en;
logic fsm0_clk;
logic fsm0_reset;
logic [1:0] fsm0_out;
logic fsm0_done;
logic [2:0] fsm1_in;
logic fsm1_write_en;
logic fsm1_clk;
logic fsm1_reset;
logic [2:0] fsm1_out;
logic fsm1_done;
logic [2:0] fsm2_in;
logic fsm2_write_en;
logic fsm2_clk;
logic fsm2_reset;
logic [2:0] fsm2_out;
logic fsm2_done;
logic [2:0] fsm3_in;
logic fsm3_write_en;
logic fsm3_clk;
logic fsm3_reset;
logic [2:0] fsm3_out;
logic fsm3_done;
logic [2:0] fsm4_in;
logic fsm4_write_en;
logic fsm4_clk;
logic fsm4_reset;
logic [2:0] fsm4_out;
logic fsm4_done;
logic [2:0] fsm5_in;
logic fsm5_write_en;
logic fsm5_clk;
logic fsm5_reset;
logic [2:0] fsm5_out;
logic fsm5_done;
logic [1:0] adder_left;
logic [1:0] adder_right;
logic [1:0] adder_out;
logic [1:0] adder0_left;
logic [1:0] adder0_right;
logic [1:0] adder0_out;
logic [2:0] adder1_left;
logic [2:0] adder1_right;
logic [2:0] adder1_out;
logic [2:0] adder2_left;
logic [2:0] adder2_right;
logic [2:0] adder2_out;
logic [2:0] adder3_left;
logic [2:0] adder3_right;
logic [2:0] adder3_out;
logic [2:0] adder4_left;
logic [2:0] adder4_right;
logic [2:0] adder4_out;
logic [2:0] adder5_left;
logic [2:0] adder5_right;
logic [2:0] adder5_out;
logic ud_out;
logic ud0_out;
logic ud1_out;
logic ud2_out;
logic signal_reg_in;
logic signal_reg_write_en;
logic signal_reg_clk;
logic signal_reg_reset;
logic signal_reg_out;
logic signal_reg_done;
logic early_reset_static_seq_go_in;
logic early_reset_static_seq_go_out;
logic early_reset_static_seq_done_in;
logic early_reset_static_seq_done_out;
logic early_reset_static_seq0_go_in;
logic early_reset_static_seq0_go_out;
logic early_reset_static_seq0_done_in;
logic early_reset_static_seq0_done_out;
logic early_reset_static_par_thread0_go_in;
logic early_reset_static_par_thread0_go_out;
logic early_reset_static_par_thread0_done_in;
logic early_reset_static_par_thread0_done_out;
logic early_reset_static_seq2_go_in;
logic early_reset_static_seq2_go_out;
logic early_reset_static_seq2_done_in;
logic early_reset_static_seq2_done_out;
logic wrapper_early_reset_static_seq_go_in;
logic wrapper_early_reset_static_seq_go_out;
logic wrapper_early_reset_static_seq_done_in;
logic wrapper_early_reset_static_seq_done_out;
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
std_add # (
    .WIDTH(32)
) add1 (
    .left(add1_left),
    .out(add1_out),
    .right(add1_right)
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
    .WIDTH(2)
) fsm (
    .clk(fsm_clk),
    .done(fsm_done),
    .in(fsm_in),
    .out(fsm_out),
    .reset(fsm_reset),
    .write_en(fsm_write_en)
);
std_reg # (
    .WIDTH(2)
) fsm0 (
    .clk(fsm0_clk),
    .done(fsm0_done),
    .in(fsm0_in),
    .out(fsm0_out),
    .reset(fsm0_reset),
    .write_en(fsm0_write_en)
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
    .WIDTH(3)
) fsm2 (
    .clk(fsm2_clk),
    .done(fsm2_done),
    .in(fsm2_in),
    .out(fsm2_out),
    .reset(fsm2_reset),
    .write_en(fsm2_write_en)
);
std_reg # (
    .WIDTH(3)
) fsm3 (
    .clk(fsm3_clk),
    .done(fsm3_done),
    .in(fsm3_in),
    .out(fsm3_out),
    .reset(fsm3_reset),
    .write_en(fsm3_write_en)
);
std_reg # (
    .WIDTH(3)
) fsm4 (
    .clk(fsm4_clk),
    .done(fsm4_done),
    .in(fsm4_in),
    .out(fsm4_out),
    .reset(fsm4_reset),
    .write_en(fsm4_write_en)
);
std_reg # (
    .WIDTH(3)
) fsm5 (
    .clk(fsm5_clk),
    .done(fsm5_done),
    .in(fsm5_in),
    .out(fsm5_out),
    .reset(fsm5_reset),
    .write_en(fsm5_write_en)
);
std_add # (
    .WIDTH(2)
) adder (
    .left(adder_left),
    .out(adder_out),
    .right(adder_right)
);
std_add # (
    .WIDTH(2)
) adder0 (
    .left(adder0_left),
    .out(adder0_out),
    .right(adder0_right)
);
std_add # (
    .WIDTH(3)
) adder1 (
    .left(adder1_left),
    .out(adder1_out),
    .right(adder1_right)
);
std_add # (
    .WIDTH(3)
) adder2 (
    .left(adder2_left),
    .out(adder2_out),
    .right(adder2_right)
);
std_add # (
    .WIDTH(3)
) adder3 (
    .left(adder3_left),
    .out(adder3_out),
    .right(adder3_right)
);
std_add # (
    .WIDTH(3)
) adder4 (
    .left(adder4_left),
    .out(adder4_out),
    .right(adder4_right)
);
std_add # (
    .WIDTH(3)
) adder5 (
    .left(adder5_left),
    .out(adder5_out),
    .right(adder5_right)
);
undef # (
    .WIDTH(1)
) ud (
    .out(ud_out)
);
undef # (
    .WIDTH(1)
) ud0 (
    .out(ud0_out)
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
) early_reset_static_seq0_go (
    .in(early_reset_static_seq0_go_in),
    .out(early_reset_static_seq0_go_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_static_seq0_done (
    .in(early_reset_static_seq0_done_in),
    .out(early_reset_static_seq0_done_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_static_par_thread0_go (
    .in(early_reset_static_par_thread0_go_in),
    .out(early_reset_static_par_thread0_go_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_static_par_thread0_done (
    .in(early_reset_static_par_thread0_done_in),
    .out(early_reset_static_par_thread0_done_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_static_seq2_go (
    .in(early_reset_static_seq2_go_in),
    .out(early_reset_static_seq2_go_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_static_seq2_done (
    .in(early_reset_static_seq2_done_in),
    .out(early_reset_static_seq2_done_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_static_seq_go (
    .in(wrapper_early_reset_static_seq_go_in),
    .out(wrapper_early_reset_static_seq_go_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_static_seq_done (
    .in(wrapper_early_reset_static_seq_done_in),
    .out(wrapper_early_reset_static_seq_done_out)
);
wire _guard0 = 1;
wire _guard1 = fsm4_out == 3'd0;
wire _guard2 = early_reset_static_seq2_go_out;
wire _guard3 = _guard1 & _guard2;
wire _guard4 = fsm4_out == 3'd0;
wire _guard5 = early_reset_static_seq2_go_out;
wire _guard6 = _guard4 & _guard5;
wire _guard7 = early_reset_static_par_thread0_go_out;
wire _guard8 = early_reset_static_par_thread0_go_out;
wire _guard9 = fsm0_out == 2'd0;
wire _guard10 = early_reset_static_seq0_go_out;
wire _guard11 = _guard9 & _guard10;
wire _guard12 = fsm2_out == 3'd3;
wire _guard13 = early_reset_static_par_thread0_go_out;
wire _guard14 = _guard12 & _guard13;
wire _guard15 = _guard11 | _guard14;
wire _guard16 = fsm2_out == 3'd3;
wire _guard17 = early_reset_static_par_thread0_go_out;
wire _guard18 = _guard16 & _guard17;
wire _guard19 = fsm0_out == 2'd0;
wire _guard20 = early_reset_static_seq0_go_out;
wire _guard21 = _guard19 & _guard20;
wire _guard22 = fsm2_out == 3'd3;
wire _guard23 = early_reset_static_par_thread0_go_out;
wire _guard24 = _guard22 & _guard23;
wire _guard25 = fsm0_out == 2'd2;
wire _guard26 = early_reset_static_seq0_go_out;
wire _guard27 = _guard25 & _guard26;
wire _guard28 = fsm4_out == 3'd4;
wire _guard29 = early_reset_static_seq2_go_out;
wire _guard30 = _guard28 & _guard29;
wire _guard31 = fsm0_out == 2'd2;
wire _guard32 = early_reset_static_seq0_go_out;
wire _guard33 = _guard31 & _guard32;
wire _guard34 = fsm2_out == 3'd3;
wire _guard35 = early_reset_static_par_thread0_go_out;
wire _guard36 = _guard34 & _guard35;
wire _guard37 = _guard33 | _guard36;
wire _guard38 = fsm4_out == 3'd4;
wire _guard39 = early_reset_static_seq2_go_out;
wire _guard40 = _guard38 & _guard39;
wire _guard41 = wrapper_early_reset_static_seq_done_out;
wire _guard42 = fsm_out != 2'd1;
wire _guard43 = early_reset_static_seq_go_out;
wire _guard44 = _guard42 & _guard43;
wire _guard45 = fsm_out == 2'd1;
wire _guard46 = fsm0_out == 2'd2;
wire _guard47 = fsm1_out == 3'd5;
wire _guard48 = _guard46 & _guard47;
wire _guard49 = _guard45 & _guard48;
wire _guard50 = early_reset_static_seq_go_out;
wire _guard51 = _guard49 & _guard50;
wire _guard52 = _guard44 | _guard51;
wire _guard53 = fsm_out != 2'd1;
wire _guard54 = early_reset_static_seq_go_out;
wire _guard55 = _guard53 & _guard54;
wire _guard56 = fsm_out == 2'd1;
wire _guard57 = fsm0_out == 2'd2;
wire _guard58 = fsm1_out == 3'd5;
wire _guard59 = _guard57 & _guard58;
wire _guard60 = _guard56 & _guard59;
wire _guard61 = early_reset_static_seq_go_out;
wire _guard62 = _guard60 & _guard61;
wire _guard63 = early_reset_static_seq_go_out;
wire _guard64 = early_reset_static_seq_go_out;
wire _guard65 = fsm2_out == 3'd3;
wire _guard66 = fsm3_out != 3'd6;
wire _guard67 = _guard65 & _guard66;
wire _guard68 = early_reset_static_par_thread0_go_out;
wire _guard69 = _guard67 & _guard68;
wire _guard70 = fsm2_out == 3'd3;
wire _guard71 = fsm3_out == 3'd6;
wire _guard72 = _guard70 & _guard71;
wire _guard73 = early_reset_static_par_thread0_go_out;
wire _guard74 = _guard72 & _guard73;
wire _guard75 = _guard69 | _guard74;
wire _guard76 = fsm2_out == 3'd3;
wire _guard77 = fsm3_out != 3'd6;
wire _guard78 = _guard76 & _guard77;
wire _guard79 = early_reset_static_par_thread0_go_out;
wire _guard80 = _guard78 & _guard79;
wire _guard81 = fsm2_out == 3'd3;
wire _guard82 = fsm3_out == 3'd6;
wire _guard83 = _guard81 & _guard82;
wire _guard84 = early_reset_static_par_thread0_go_out;
wire _guard85 = _guard83 & _guard84;
wire _guard86 = fsm4_out == 3'd4;
wire _guard87 = fsm5_out != 3'd4;
wire _guard88 = _guard86 & _guard87;
wire _guard89 = early_reset_static_seq2_go_out;
wire _guard90 = _guard88 & _guard89;
wire _guard91 = fsm4_out == 3'd4;
wire _guard92 = fsm5_out == 3'd4;
wire _guard93 = _guard91 & _guard92;
wire _guard94 = early_reset_static_seq2_go_out;
wire _guard95 = _guard93 & _guard94;
wire _guard96 = _guard90 | _guard95;
wire _guard97 = fsm4_out == 3'd4;
wire _guard98 = fsm5_out != 3'd4;
wire _guard99 = _guard97 & _guard98;
wire _guard100 = early_reset_static_seq2_go_out;
wire _guard101 = _guard99 & _guard100;
wire _guard102 = fsm4_out == 3'd4;
wire _guard103 = fsm5_out == 3'd4;
wire _guard104 = _guard102 & _guard103;
wire _guard105 = early_reset_static_seq2_go_out;
wire _guard106 = _guard104 & _guard105;
wire _guard107 = early_reset_static_par_thread0_go_out;
wire _guard108 = early_reset_static_par_thread0_go_out;
wire _guard109 = fsm_out == 2'd1;
wire _guard110 = early_reset_static_seq_go_out;
wire _guard111 = _guard109 & _guard110;
wire _guard112 = fsm0_out == 2'd2;
wire _guard113 = fsm1_out != 3'd5;
wire _guard114 = _guard112 & _guard113;
wire _guard115 = early_reset_static_seq0_go_out;
wire _guard116 = _guard114 & _guard115;
wire _guard117 = fsm0_out == 2'd2;
wire _guard118 = fsm1_out == 3'd5;
wire _guard119 = _guard117 & _guard118;
wire _guard120 = early_reset_static_seq0_go_out;
wire _guard121 = _guard119 & _guard120;
wire _guard122 = _guard116 | _guard121;
wire _guard123 = fsm0_out == 2'd2;
wire _guard124 = fsm1_out != 3'd5;
wire _guard125 = _guard123 & _guard124;
wire _guard126 = early_reset_static_seq0_go_out;
wire _guard127 = _guard125 & _guard126;
wire _guard128 = fsm0_out == 2'd2;
wire _guard129 = fsm1_out == 3'd5;
wire _guard130 = _guard128 & _guard129;
wire _guard131 = early_reset_static_seq0_go_out;
wire _guard132 = _guard130 & _guard131;
wire _guard133 = fsm4_out != 3'd4;
wire _guard134 = early_reset_static_seq2_go_out;
wire _guard135 = _guard133 & _guard134;
wire _guard136 = fsm4_out == 3'd4;
wire _guard137 = early_reset_static_seq2_go_out;
wire _guard138 = _guard136 & _guard137;
wire _guard139 = _guard135 | _guard138;
wire _guard140 = fsm4_out != 3'd4;
wire _guard141 = early_reset_static_seq2_go_out;
wire _guard142 = _guard140 & _guard141;
wire _guard143 = fsm4_out == 3'd4;
wire _guard144 = early_reset_static_seq2_go_out;
wire _guard145 = _guard143 & _guard144;
wire _guard146 = fsm2_out == 3'd1;
wire _guard147 = early_reset_static_par_thread0_go_out;
wire _guard148 = _guard146 & _guard147;
wire _guard149 = fsm4_out == 3'd0;
wire _guard150 = early_reset_static_seq2_go_out;
wire _guard151 = _guard149 & _guard150;
wire _guard152 = fsm4_out == 3'd0;
wire _guard153 = early_reset_static_seq2_go_out;
wire _guard154 = _guard152 & _guard153;
wire _guard155 = fsm4_out == 3'd0;
wire _guard156 = early_reset_static_seq2_go_out;
wire _guard157 = _guard155 & _guard156;
wire _guard158 = fsm4_out == 3'd0;
wire _guard159 = early_reset_static_seq2_go_out;
wire _guard160 = _guard158 & _guard159;
wire _guard161 = fsm0_out != 2'd1;
wire _guard162 = fsm0_out != 2'd2;
wire _guard163 = _guard161 & _guard162;
wire _guard164 = early_reset_static_seq0_go_out;
wire _guard165 = _guard163 & _guard164;
wire _guard166 = fsm0_out == 2'd1;
wire _guard167 = fsm2_out == 3'd3;
wire _guard168 = fsm3_out == 3'd6;
wire _guard169 = _guard167 & _guard168;
wire _guard170 = _guard166 & _guard169;
wire _guard171 = early_reset_static_seq0_go_out;
wire _guard172 = _guard170 & _guard171;
wire _guard173 = _guard165 | _guard172;
wire _guard174 = fsm0_out == 2'd2;
wire _guard175 = early_reset_static_seq0_go_out;
wire _guard176 = _guard174 & _guard175;
wire _guard177 = _guard173 | _guard176;
wire _guard178 = fsm0_out == 2'd2;
wire _guard179 = early_reset_static_seq0_go_out;
wire _guard180 = _guard178 & _guard179;
wire _guard181 = fsm0_out != 2'd1;
wire _guard182 = fsm0_out != 2'd2;
wire _guard183 = _guard181 & _guard182;
wire _guard184 = early_reset_static_seq0_go_out;
wire _guard185 = _guard183 & _guard184;
wire _guard186 = fsm0_out == 2'd1;
wire _guard187 = fsm2_out == 3'd3;
wire _guard188 = fsm3_out == 3'd6;
wire _guard189 = _guard187 & _guard188;
wire _guard190 = _guard186 & _guard189;
wire _guard191 = early_reset_static_seq0_go_out;
wire _guard192 = _guard190 & _guard191;
wire _guard193 = _guard185 | _guard192;
wire _guard194 = fsm2_out != 3'd1;
wire _guard195 = fsm2_out != 3'd3;
wire _guard196 = _guard194 & _guard195;
wire _guard197 = early_reset_static_par_thread0_go_out;
wire _guard198 = _guard196 & _guard197;
wire _guard199 = fsm2_out == 3'd1;
wire _guard200 = fsm4_out == 3'd4;
wire _guard201 = fsm5_out == 3'd4;
wire _guard202 = _guard200 & _guard201;
wire _guard203 = _guard199 & _guard202;
wire _guard204 = early_reset_static_par_thread0_go_out;
wire _guard205 = _guard203 & _guard204;
wire _guard206 = _guard198 | _guard205;
wire _guard207 = fsm2_out == 3'd3;
wire _guard208 = early_reset_static_par_thread0_go_out;
wire _guard209 = _guard207 & _guard208;
wire _guard210 = _guard206 | _guard209;
wire _guard211 = fsm2_out != 3'd1;
wire _guard212 = fsm2_out != 3'd3;
wire _guard213 = _guard211 & _guard212;
wire _guard214 = early_reset_static_par_thread0_go_out;
wire _guard215 = _guard213 & _guard214;
wire _guard216 = fsm2_out == 3'd1;
wire _guard217 = fsm4_out == 3'd4;
wire _guard218 = fsm5_out == 3'd4;
wire _guard219 = _guard217 & _guard218;
wire _guard220 = _guard216 & _guard219;
wire _guard221 = early_reset_static_par_thread0_go_out;
wire _guard222 = _guard220 & _guard221;
wire _guard223 = _guard215 | _guard222;
wire _guard224 = fsm2_out == 3'd3;
wire _guard225 = early_reset_static_par_thread0_go_out;
wire _guard226 = _guard224 & _guard225;
wire _guard227 = early_reset_static_seq2_go_out;
wire _guard228 = early_reset_static_seq2_go_out;
wire _guard229 = fsm2_out == 3'd0;
wire _guard230 = early_reset_static_par_thread0_go_out;
wire _guard231 = _guard229 & _guard230;
wire _guard232 = fsm2_out == 3'd0;
wire _guard233 = early_reset_static_par_thread0_go_out;
wire _guard234 = _guard232 & _guard233;
wire _guard235 = early_reset_static_seq2_go_out;
wire _guard236 = early_reset_static_seq2_go_out;
wire _guard237 = early_reset_static_seq0_go_out;
wire _guard238 = early_reset_static_seq0_go_out;
wire _guard239 = signal_reg_out;
wire _guard240 = early_reset_static_seq0_go_out;
wire _guard241 = early_reset_static_seq0_go_out;
wire _guard242 = wrapper_early_reset_static_seq_go_out;
wire _guard243 = fsm_out == 2'd0;
wire _guard244 = early_reset_static_seq_go_out;
wire _guard245 = _guard243 & _guard244;
wire _guard246 = fsm0_out == 2'd2;
wire _guard247 = early_reset_static_seq0_go_out;
wire _guard248 = _guard246 & _guard247;
wire _guard249 = _guard245 | _guard248;
wire _guard250 = fsm0_out == 2'd2;
wire _guard251 = early_reset_static_seq0_go_out;
wire _guard252 = _guard250 & _guard251;
wire _guard253 = fsm_out == 2'd0;
wire _guard254 = early_reset_static_seq_go_out;
wire _guard255 = _guard253 & _guard254;
wire _guard256 = fsm4_out >= 3'd1;
wire _guard257 = fsm4_out < 3'd4;
wire _guard258 = _guard256 & _guard257;
wire _guard259 = early_reset_static_seq2_go_out;
wire _guard260 = _guard258 & _guard259;
wire _guard261 = fsm4_out >= 3'd1;
wire _guard262 = fsm4_out < 3'd4;
wire _guard263 = _guard261 & _guard262;
wire _guard264 = early_reset_static_seq2_go_out;
wire _guard265 = _guard263 & _guard264;
wire _guard266 = fsm4_out >= 3'd1;
wire _guard267 = fsm4_out < 3'd4;
wire _guard268 = _guard266 & _guard267;
wire _guard269 = early_reset_static_seq2_go_out;
wire _guard270 = _guard268 & _guard269;
wire _guard271 = signal_reg_out;
wire _guard272 = fsm_out == 2'd1;
wire _guard273 = fsm0_out == 2'd2;
wire _guard274 = fsm1_out == 3'd5;
wire _guard275 = _guard273 & _guard274;
wire _guard276 = _guard272 & _guard275;
wire _guard277 = _guard276 & _guard0;
wire _guard278 = signal_reg_out;
wire _guard279 = ~_guard278;
wire _guard280 = _guard277 & _guard279;
wire _guard281 = wrapper_early_reset_static_seq_go_out;
wire _guard282 = _guard280 & _guard281;
wire _guard283 = _guard271 | _guard282;
wire _guard284 = fsm_out == 2'd1;
wire _guard285 = fsm0_out == 2'd2;
wire _guard286 = fsm1_out == 3'd5;
wire _guard287 = _guard285 & _guard286;
wire _guard288 = _guard284 & _guard287;
wire _guard289 = _guard288 & _guard0;
wire _guard290 = signal_reg_out;
wire _guard291 = ~_guard290;
wire _guard292 = _guard289 & _guard291;
wire _guard293 = wrapper_early_reset_static_seq_go_out;
wire _guard294 = _guard292 & _guard293;
wire _guard295 = signal_reg_out;
wire _guard296 = fsm2_out == 3'd0;
wire _guard297 = early_reset_static_par_thread0_go_out;
wire _guard298 = _guard296 & _guard297;
wire _guard299 = fsm4_out == 3'd4;
wire _guard300 = early_reset_static_seq2_go_out;
wire _guard301 = _guard299 & _guard300;
wire _guard302 = _guard298 | _guard301;
wire _guard303 = fsm4_out == 3'd4;
wire _guard304 = early_reset_static_seq2_go_out;
wire _guard305 = _guard303 & _guard304;
wire _guard306 = fsm2_out == 3'd0;
wire _guard307 = early_reset_static_par_thread0_go_out;
wire _guard308 = _guard306 & _guard307;
wire _guard309 = fsm0_out == 2'd1;
wire _guard310 = early_reset_static_seq0_go_out;
wire _guard311 = _guard309 & _guard310;
wire _guard312 = fsm2_out == 3'd2;
wire _guard313 = early_reset_static_par_thread0_go_out;
wire _guard314 = _guard312 & _guard313;
wire _guard315 = fsm2_out == 3'd2;
wire _guard316 = early_reset_static_par_thread0_go_out;
wire _guard317 = _guard315 & _guard316;
wire _guard318 = fsm2_out == 3'd2;
wire _guard319 = early_reset_static_par_thread0_go_out;
wire _guard320 = _guard318 & _guard319;
wire _guard321 = fsm2_out == 3'd2;
wire _guard322 = early_reset_static_par_thread0_go_out;
wire _guard323 = _guard321 & _guard322;
wire _guard324 = fsm4_out == 3'd0;
wire _guard325 = early_reset_static_seq2_go_out;
wire _guard326 = _guard324 & _guard325;
wire _guard327 = fsm4_out == 3'd0;
wire _guard328 = early_reset_static_seq2_go_out;
wire _guard329 = _guard327 & _guard328;
assign element1_write_en = _guard3;
assign element1_clk = clk;
assign element1_reset = reset;
assign element1_in = arr1_read_data;
assign adder1_left =
  _guard7 ? fsm2_out :
  3'd0;
assign adder1_right =
  _guard8 ? 3'd1 :
  3'd0;
assign j_write_en = _guard15;
assign j_clk = clk;
assign j_reset = reset;
assign j_in =
  _guard18 ? add1_out :
  _guard21 ? 32'd0 :
  'x;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard21, _guard18})) begin
    $fatal(2, "Multiple assignment to port `j.in'.");
end
end
assign add1_left =
  _guard24 ? j_out :
  _guard27 ? i_out :
  _guard30 ? multE_out :
  'x;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard30, _guard27, _guard24})) begin
    $fatal(2, "Multiple assignment to port `add1.left'.");
end
end
assign add1_right =
  _guard37 ? 32'd1 :
  _guard40 ? outE_out :
  'x;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard40, _guard37})) begin
    $fatal(2, "Multiple assignment to port `add1.right'.");
end
end
assign done = _guard41;
assign fsm_write_en = _guard52;
assign fsm_clk = clk;
assign fsm_reset = reset;
assign fsm_in =
  _guard55 ? adder_out :
  _guard62 ? 2'd0 :
  2'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard62, _guard55})) begin
    $fatal(2, "Multiple assignment to port `fsm.in'.");
end
end
assign adder_left =
  _guard63 ? fsm_out :
  2'd0;
assign adder_right =
  _guard64 ? 2'd1 :
  2'd0;
assign fsm3_write_en = _guard75;
assign fsm3_clk = clk;
assign fsm3_reset = reset;
assign fsm3_in =
  _guard80 ? adder4_out :
  _guard85 ? 3'd0 :
  3'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard85, _guard80})) begin
    $fatal(2, "Multiple assignment to port `fsm3.in'.");
end
end
assign fsm5_write_en = _guard96;
assign fsm5_clk = clk;
assign fsm5_reset = reset;
assign fsm5_in =
  _guard101 ? adder3_out :
  _guard106 ? 3'd0 :
  3'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard106, _guard101})) begin
    $fatal(2, "Multiple assignment to port `fsm5.in'.");
end
end
assign adder4_left =
  _guard107 ? fsm3_out :
  3'd0;
assign adder4_right =
  _guard108 ? 3'd1 :
  3'd0;
assign early_reset_static_par_thread0_done_in = ud1_out;
assign early_reset_static_seq2_done_in = ud2_out;
assign early_reset_static_seq0_go_in = _guard111;
assign fsm1_write_en = _guard122;
assign fsm1_clk = clk;
assign fsm1_reset = reset;
assign fsm1_in =
  _guard127 ? adder5_out :
  _guard132 ? 3'd0 :
  3'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard132, _guard127})) begin
    $fatal(2, "Multiple assignment to port `fsm1.in'.");
end
end
assign fsm4_write_en = _guard139;
assign fsm4_clk = clk;
assign fsm4_reset = reset;
assign fsm4_in =
  _guard142 ? adder2_out :
  _guard145 ? 3'd0 :
  3'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard145, _guard142})) begin
    $fatal(2, "Multiple assignment to port `fsm4.in'.");
end
end
assign early_reset_static_seq2_go_in = _guard148;
assign arr2_write_en = 1'd0;
assign arr2_clk = clk;
assign arr2_addr0 =
  _guard151 ? k_out :
  32'd0;
assign arr2_reset = reset;
assign arr2_addr1 =
  _guard154 ? j_out :
  32'd0;
assign element2_write_en = _guard157;
assign element2_clk = clk;
assign element2_reset = reset;
assign element2_in = arr2_read_data;
assign fsm0_write_en = _guard177;
assign fsm0_clk = clk;
assign fsm0_reset = reset;
assign fsm0_in =
  _guard180 ? 2'd0 :
  _guard193 ? adder0_out :
  2'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard193, _guard180})) begin
    $fatal(2, "Multiple assignment to port `fsm0.in'.");
end
end
assign fsm2_write_en = _guard210;
assign fsm2_clk = clk;
assign fsm2_reset = reset;
assign fsm2_in =
  _guard223 ? adder1_out :
  _guard226 ? 3'd0 :
  3'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard226, _guard223})) begin
    $fatal(2, "Multiple assignment to port `fsm2.in'.");
end
end
assign adder2_left =
  _guard227 ? fsm4_out :
  3'd0;
assign adder2_right =
  _guard228 ? 3'd1 :
  3'd0;
assign k_write_en = _guard231;
assign k_clk = clk;
assign k_reset = reset;
assign k_in = 32'd0;
assign adder3_left =
  _guard235 ? fsm5_out :
  3'd0;
assign adder3_right =
  _guard236 ? 3'd1 :
  3'd0;
assign adder5_left =
  _guard237 ? fsm1_out :
  3'd0;
assign adder5_right =
  _guard238 ? 3'd1 :
  3'd0;
assign wrapper_early_reset_static_seq_done_in = _guard239;
assign adder0_left =
  _guard240 ? fsm0_out :
  2'd0;
assign adder0_right =
  _guard241 ? 2'd1 :
  2'd0;
assign early_reset_static_seq_go_in = _guard242;
assign i_write_en = _guard249;
assign i_clk = clk;
assign i_reset = reset;
assign i_in =
  _guard252 ? add1_out :
  _guard255 ? 32'd0 :
  'x;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard255, _guard252})) begin
    $fatal(2, "Multiple assignment to port `i.in'.");
end
end
assign multE_clk = clk;
assign multE_left = element1_out;
assign multE_go = _guard265;
assign multE_reset = reset;
assign multE_right = element2_out;
assign signal_reg_write_en = _guard283;
assign signal_reg_clk = clk;
assign signal_reg_reset = reset;
assign signal_reg_in =
  _guard294 ? 1'd1 :
  _guard295 ? 1'd0 :
  1'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard295, _guard294})) begin
    $fatal(2, "Multiple assignment to port `signal_reg.in'.");
end
end
assign outE_write_en = _guard302;
assign outE_clk = clk;
assign outE_reset = reset;
assign outE_in =
  _guard305 ? add1_out :
  _guard308 ? 32'd0 :
  'x;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard308, _guard305})) begin
    $fatal(2, "Multiple assignment to port `outE.in'.");
end
end
assign early_reset_static_par_thread0_go_in = _guard311;
assign arrOut_write_en = _guard314;
assign arrOut_clk = clk;
assign arrOut_addr0 =
  _guard317 ? i_out :
  32'd0;
assign arrOut_reset = reset;
assign arrOut_write_data = outE_out;
assign arrOut_addr1 =
  _guard323 ? j_out :
  32'd0;
assign early_reset_static_seq_done_in = ud_out;
assign arr1_write_en = 1'd0;
assign arr1_clk = clk;
assign arr1_addr0 =
  _guard326 ? i_out :
  32'd0;
assign arr1_reset = reset;
assign arr1_addr1 =
  _guard329 ? k_out :
  32'd0;
assign early_reset_static_seq0_done_in = ud0_out;
assign wrapper_early_reset_static_seq_go_in = go;
// COMPONENT END: main
endmodule
