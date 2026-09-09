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
logic [2:0] idx_in;
logic idx_write_en;
logic idx_clk;
logic idx_reset;
logic [2:0] idx_out;
logic idx_done;
logic cond_reg_in;
logic cond_reg_write_en;
logic cond_reg_clk;
logic cond_reg_reset;
logic cond_reg_out;
logic cond_reg_done;
logic [2:0] adder_left;
logic [2:0] adder_right;
logic [2:0] adder_out;
logic [2:0] lt_left;
logic [2:0] lt_right;
logic lt_out;
logic [2:0] idx0_in;
logic idx0_write_en;
logic idx0_clk;
logic idx0_reset;
logic [2:0] idx0_out;
logic idx0_done;
logic cond_reg0_in;
logic cond_reg0_write_en;
logic cond_reg0_clk;
logic cond_reg0_reset;
logic cond_reg0_out;
logic cond_reg0_done;
logic [2:0] adder0_left;
logic [2:0] adder0_right;
logic [2:0] adder0_out;
logic [2:0] lt0_left;
logic [2:0] lt0_right;
logic lt0_out;
logic [2:0] idx1_in;
logic idx1_write_en;
logic idx1_clk;
logic idx1_reset;
logic [2:0] idx1_out;
logic idx1_done;
logic cond_reg1_in;
logic cond_reg1_write_en;
logic cond_reg1_clk;
logic cond_reg1_reset;
logic cond_reg1_out;
logic cond_reg1_done;
logic [2:0] adder1_left;
logic [2:0] adder1_right;
logic [2:0] adder1_out;
logic [2:0] lt1_left;
logic [2:0] lt1_right;
logic lt1_out;
logic ud_out;
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
logic pd0_in;
logic pd0_write_en;
logic pd0_clk;
logic pd0_reset;
logic pd0_out;
logic pd0_done;
logic [4:0] fsm_in;
logic fsm_write_en;
logic fsm_clk;
logic fsm_reset;
logic [4:0] fsm_out;
logic fsm_done;
logic loadElement1_go_in;
logic loadElement1_go_out;
logic loadElement1_done_in;
logic loadElement1_done_out;
logic loadElement2_go_in;
logic loadElement2_go_out;
logic loadElement2_done_in;
logic loadElement2_done_out;
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
logic invoke2_go_in;
logic invoke2_go_out;
logic invoke2_done_in;
logic invoke2_done_out;
logic invoke3_go_in;
logic invoke3_go_out;
logic invoke3_done_in;
logic invoke3_done_out;
logic invoke4_go_in;
logic invoke4_go_out;
logic invoke4_done_in;
logic invoke4_done_out;
logic invoke5_go_in;
logic invoke5_go_out;
logic invoke5_done_in;
logic invoke5_done_out;
logic invoke6_go_in;
logic invoke6_go_out;
logic invoke6_done_in;
logic invoke6_done_out;
logic init_repeat_go_in;
logic init_repeat_go_out;
logic init_repeat_done_in;
logic init_repeat_done_out;
logic incr_repeat_go_in;
logic incr_repeat_go_out;
logic incr_repeat_done_in;
logic incr_repeat_done_out;
logic init_repeat0_go_in;
logic init_repeat0_go_out;
logic init_repeat0_done_in;
logic init_repeat0_done_out;
logic incr_repeat0_go_in;
logic incr_repeat0_go_out;
logic incr_repeat0_done_in;
logic incr_repeat0_done_out;
logic init_repeat1_go_in;
logic init_repeat1_go_out;
logic init_repeat1_done_in;
logic init_repeat1_done_out;
logic incr_repeat1_go_in;
logic incr_repeat1_go_out;
logic incr_repeat1_done_in;
logic incr_repeat1_done_out;
logic early_reset_initI_go_in;
logic early_reset_initI_go_out;
logic early_reset_initI_done_in;
logic early_reset_initI_done_out;
logic wrapper_early_reset_initI_go_in;
logic wrapper_early_reset_initI_go_out;
logic wrapper_early_reset_initI_done_in;
logic wrapper_early_reset_initI_done_out;
logic par0_go_in;
logic par0_go_out;
logic par0_done_in;
logic par0_done_out;
logic tdcc_go_in;
logic tdcc_go_out;
logic tdcc_done_in;
logic tdcc_done_out;
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
    .WIDTH(3)
) idx (
    .clk(idx_clk),
    .done(idx_done),
    .in(idx_in),
    .out(idx_out),
    .reset(idx_reset),
    .write_en(idx_write_en)
);
std_reg # (
    .WIDTH(1)
) cond_reg (
    .clk(cond_reg_clk),
    .done(cond_reg_done),
    .in(cond_reg_in),
    .out(cond_reg_out),
    .reset(cond_reg_reset),
    .write_en(cond_reg_write_en)
);
std_add # (
    .WIDTH(3)
) adder (
    .left(adder_left),
    .out(adder_out),
    .right(adder_right)
);
std_lt # (
    .WIDTH(3)
) lt (
    .left(lt_left),
    .out(lt_out),
    .right(lt_right)
);
std_reg # (
    .WIDTH(3)
) idx0 (
    .clk(idx0_clk),
    .done(idx0_done),
    .in(idx0_in),
    .out(idx0_out),
    .reset(idx0_reset),
    .write_en(idx0_write_en)
);
std_reg # (
    .WIDTH(1)
) cond_reg0 (
    .clk(cond_reg0_clk),
    .done(cond_reg0_done),
    .in(cond_reg0_in),
    .out(cond_reg0_out),
    .reset(cond_reg0_reset),
    .write_en(cond_reg0_write_en)
);
std_add # (
    .WIDTH(3)
) adder0 (
    .left(adder0_left),
    .out(adder0_out),
    .right(adder0_right)
);
std_lt # (
    .WIDTH(3)
) lt0 (
    .left(lt0_left),
    .out(lt0_out),
    .right(lt0_right)
);
std_reg # (
    .WIDTH(3)
) idx1 (
    .clk(idx1_clk),
    .done(idx1_done),
    .in(idx1_in),
    .out(idx1_out),
    .reset(idx1_reset),
    .write_en(idx1_write_en)
);
std_reg # (
    .WIDTH(1)
) cond_reg1 (
    .clk(cond_reg1_clk),
    .done(cond_reg1_done),
    .in(cond_reg1_in),
    .out(cond_reg1_out),
    .reset(cond_reg1_reset),
    .write_en(cond_reg1_write_en)
);
std_add # (
    .WIDTH(3)
) adder1 (
    .left(adder1_left),
    .out(adder1_out),
    .right(adder1_right)
);
std_lt # (
    .WIDTH(3)
) lt1 (
    .left(lt1_left),
    .out(lt1_out),
    .right(lt1_right)
);
undef # (
    .WIDTH(1)
) ud (
    .out(ud_out)
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
    .WIDTH(5)
) fsm (
    .clk(fsm_clk),
    .done(fsm_done),
    .in(fsm_in),
    .out(fsm_out),
    .reset(fsm_reset),
    .write_en(fsm_write_en)
);
std_wire # (
    .WIDTH(1)
) loadElement1_go (
    .in(loadElement1_go_in),
    .out(loadElement1_go_out)
);
std_wire # (
    .WIDTH(1)
) loadElement1_done (
    .in(loadElement1_done_in),
    .out(loadElement1_done_out)
);
std_wire # (
    .WIDTH(1)
) loadElement2_go (
    .in(loadElement2_go_in),
    .out(loadElement2_go_out)
);
std_wire # (
    .WIDTH(1)
) loadElement2_done (
    .in(loadElement2_done_in),
    .out(loadElement2_done_out)
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
) invoke2_go (
    .in(invoke2_go_in),
    .out(invoke2_go_out)
);
std_wire # (
    .WIDTH(1)
) invoke2_done (
    .in(invoke2_done_in),
    .out(invoke2_done_out)
);
std_wire # (
    .WIDTH(1)
) invoke3_go (
    .in(invoke3_go_in),
    .out(invoke3_go_out)
);
std_wire # (
    .WIDTH(1)
) invoke3_done (
    .in(invoke3_done_in),
    .out(invoke3_done_out)
);
std_wire # (
    .WIDTH(1)
) invoke4_go (
    .in(invoke4_go_in),
    .out(invoke4_go_out)
);
std_wire # (
    .WIDTH(1)
) invoke4_done (
    .in(invoke4_done_in),
    .out(invoke4_done_out)
);
std_wire # (
    .WIDTH(1)
) invoke5_go (
    .in(invoke5_go_in),
    .out(invoke5_go_out)
);
std_wire # (
    .WIDTH(1)
) invoke5_done (
    .in(invoke5_done_in),
    .out(invoke5_done_out)
);
std_wire # (
    .WIDTH(1)
) invoke6_go (
    .in(invoke6_go_in),
    .out(invoke6_go_out)
);
std_wire # (
    .WIDTH(1)
) invoke6_done (
    .in(invoke6_done_in),
    .out(invoke6_done_out)
);
std_wire # (
    .WIDTH(1)
) init_repeat_go (
    .in(init_repeat_go_in),
    .out(init_repeat_go_out)
);
std_wire # (
    .WIDTH(1)
) init_repeat_done (
    .in(init_repeat_done_in),
    .out(init_repeat_done_out)
);
std_wire # (
    .WIDTH(1)
) incr_repeat_go (
    .in(incr_repeat_go_in),
    .out(incr_repeat_go_out)
);
std_wire # (
    .WIDTH(1)
) incr_repeat_done (
    .in(incr_repeat_done_in),
    .out(incr_repeat_done_out)
);
std_wire # (
    .WIDTH(1)
) init_repeat0_go (
    .in(init_repeat0_go_in),
    .out(init_repeat0_go_out)
);
std_wire # (
    .WIDTH(1)
) init_repeat0_done (
    .in(init_repeat0_done_in),
    .out(init_repeat0_done_out)
);
std_wire # (
    .WIDTH(1)
) incr_repeat0_go (
    .in(incr_repeat0_go_in),
    .out(incr_repeat0_go_out)
);
std_wire # (
    .WIDTH(1)
) incr_repeat0_done (
    .in(incr_repeat0_done_in),
    .out(incr_repeat0_done_out)
);
std_wire # (
    .WIDTH(1)
) init_repeat1_go (
    .in(init_repeat1_go_in),
    .out(init_repeat1_go_out)
);
std_wire # (
    .WIDTH(1)
) init_repeat1_done (
    .in(init_repeat1_done_in),
    .out(init_repeat1_done_out)
);
std_wire # (
    .WIDTH(1)
) incr_repeat1_go (
    .in(incr_repeat1_go_in),
    .out(incr_repeat1_go_out)
);
std_wire # (
    .WIDTH(1)
) incr_repeat1_done (
    .in(incr_repeat1_done_in),
    .out(incr_repeat1_done_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_initI_go (
    .in(early_reset_initI_go_in),
    .out(early_reset_initI_go_out)
);
std_wire # (
    .WIDTH(1)
) early_reset_initI_done (
    .in(early_reset_initI_done_in),
    .out(early_reset_initI_done_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_initI_go (
    .in(wrapper_early_reset_initI_go_in),
    .out(wrapper_early_reset_initI_go_out)
);
std_wire # (
    .WIDTH(1)
) wrapper_early_reset_initI_done (
    .in(wrapper_early_reset_initI_done_in),
    .out(wrapper_early_reset_initI_done_out)
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
wire _guard0 = 1;
wire _guard1 = loadElement1_go_out;
wire _guard2 = loadElement1_go_out;
wire _guard3 = init_repeat1_go_out;
wire _guard4 = incr_repeat1_go_out;
wire _guard5 = _guard3 | _guard4;
wire _guard6 = init_repeat1_go_out;
wire _guard7 = incr_repeat1_go_out;
wire _guard8 = incr_repeat1_go_out;
wire _guard9 = incr_repeat1_go_out;
wire _guard10 = init_repeat_done_out;
wire _guard11 = ~_guard10;
wire _guard12 = fsm_out == 5'd6;
wire _guard13 = _guard11 & _guard12;
wire _guard14 = tdcc_go_out;
wire _guard15 = _guard13 & _guard14;
wire _guard16 = invoke0_go_out;
wire _guard17 = invoke5_go_out;
wire _guard18 = _guard16 | _guard17;
wire _guard19 = invoke5_go_out;
wire _guard20 = invoke0_go_out;
wire _guard21 = invoke5_go_out;
wire _guard22 = invoke6_go_out;
wire _guard23 = invoke4_go_out;
wire _guard24 = invoke5_go_out;
wire _guard25 = invoke6_go_out;
wire _guard26 = _guard24 | _guard25;
wire _guard27 = invoke4_go_out;
wire _guard28 = tdcc_done_out;
wire _guard29 = incr_repeat_go_out;
wire _guard30 = incr_repeat_go_out;
wire _guard31 = fsm_out == 5'd16;
wire _guard32 = fsm_out == 5'd0;
wire _guard33 = wrapper_early_reset_initI_done_out;
wire _guard34 = _guard32 & _guard33;
wire _guard35 = tdcc_go_out;
wire _guard36 = _guard34 & _guard35;
wire _guard37 = _guard31 | _guard36;
wire _guard38 = fsm_out == 5'd1;
wire _guard39 = init_repeat1_done_out;
wire _guard40 = cond_reg1_out;
wire _guard41 = _guard39 & _guard40;
wire _guard42 = _guard38 & _guard41;
wire _guard43 = tdcc_go_out;
wire _guard44 = _guard42 & _guard43;
wire _guard45 = _guard37 | _guard44;
wire _guard46 = fsm_out == 5'd15;
wire _guard47 = incr_repeat1_done_out;
wire _guard48 = cond_reg1_out;
wire _guard49 = _guard47 & _guard48;
wire _guard50 = _guard46 & _guard49;
wire _guard51 = tdcc_go_out;
wire _guard52 = _guard50 & _guard51;
wire _guard53 = _guard45 | _guard52;
wire _guard54 = fsm_out == 5'd2;
wire _guard55 = invoke0_done_out;
wire _guard56 = _guard54 & _guard55;
wire _guard57 = tdcc_go_out;
wire _guard58 = _guard56 & _guard57;
wire _guard59 = _guard53 | _guard58;
wire _guard60 = fsm_out == 5'd3;
wire _guard61 = init_repeat0_done_out;
wire _guard62 = cond_reg0_out;
wire _guard63 = _guard61 & _guard62;
wire _guard64 = _guard60 & _guard63;
wire _guard65 = tdcc_go_out;
wire _guard66 = _guard64 & _guard65;
wire _guard67 = _guard59 | _guard66;
wire _guard68 = fsm_out == 5'd13;
wire _guard69 = incr_repeat0_done_out;
wire _guard70 = cond_reg0_out;
wire _guard71 = _guard69 & _guard70;
wire _guard72 = _guard68 & _guard71;
wire _guard73 = tdcc_go_out;
wire _guard74 = _guard72 & _guard73;
wire _guard75 = _guard67 | _guard74;
wire _guard76 = fsm_out == 5'd4;
wire _guard77 = invoke1_done_out;
wire _guard78 = _guard76 & _guard77;
wire _guard79 = tdcc_go_out;
wire _guard80 = _guard78 & _guard79;
wire _guard81 = _guard75 | _guard80;
wire _guard82 = fsm_out == 5'd5;
wire _guard83 = invoke2_done_out;
wire _guard84 = _guard82 & _guard83;
wire _guard85 = tdcc_go_out;
wire _guard86 = _guard84 & _guard85;
wire _guard87 = _guard81 | _guard86;
wire _guard88 = fsm_out == 5'd6;
wire _guard89 = init_repeat_done_out;
wire _guard90 = cond_reg_out;
wire _guard91 = _guard89 & _guard90;
wire _guard92 = _guard88 & _guard91;
wire _guard93 = tdcc_go_out;
wire _guard94 = _guard92 & _guard93;
wire _guard95 = _guard87 | _guard94;
wire _guard96 = fsm_out == 5'd10;
wire _guard97 = incr_repeat_done_out;
wire _guard98 = cond_reg_out;
wire _guard99 = _guard97 & _guard98;
wire _guard100 = _guard96 & _guard99;
wire _guard101 = tdcc_go_out;
wire _guard102 = _guard100 & _guard101;
wire _guard103 = _guard95 | _guard102;
wire _guard104 = fsm_out == 5'd7;
wire _guard105 = par0_done_out;
wire _guard106 = _guard104 & _guard105;
wire _guard107 = tdcc_go_out;
wire _guard108 = _guard106 & _guard107;
wire _guard109 = _guard103 | _guard108;
wire _guard110 = fsm_out == 5'd8;
wire _guard111 = invoke3_done_out;
wire _guard112 = _guard110 & _guard111;
wire _guard113 = tdcc_go_out;
wire _guard114 = _guard112 & _guard113;
wire _guard115 = _guard109 | _guard114;
wire _guard116 = fsm_out == 5'd9;
wire _guard117 = invoke4_done_out;
wire _guard118 = _guard116 & _guard117;
wire _guard119 = tdcc_go_out;
wire _guard120 = _guard118 & _guard119;
wire _guard121 = _guard115 | _guard120;
wire _guard122 = fsm_out == 5'd6;
wire _guard123 = init_repeat_done_out;
wire _guard124 = cond_reg_out;
wire _guard125 = ~_guard124;
wire _guard126 = _guard123 & _guard125;
wire _guard127 = _guard122 & _guard126;
wire _guard128 = tdcc_go_out;
wire _guard129 = _guard127 & _guard128;
wire _guard130 = _guard121 | _guard129;
wire _guard131 = fsm_out == 5'd10;
wire _guard132 = incr_repeat_done_out;
wire _guard133 = cond_reg_out;
wire _guard134 = ~_guard133;
wire _guard135 = _guard132 & _guard134;
wire _guard136 = _guard131 & _guard135;
wire _guard137 = tdcc_go_out;
wire _guard138 = _guard136 & _guard137;
wire _guard139 = _guard130 | _guard138;
wire _guard140 = fsm_out == 5'd11;
wire _guard141 = writeArrOut_done_out;
wire _guard142 = _guard140 & _guard141;
wire _guard143 = tdcc_go_out;
wire _guard144 = _guard142 & _guard143;
wire _guard145 = _guard139 | _guard144;
wire _guard146 = fsm_out == 5'd12;
wire _guard147 = invoke5_done_out;
wire _guard148 = _guard146 & _guard147;
wire _guard149 = tdcc_go_out;
wire _guard150 = _guard148 & _guard149;
wire _guard151 = _guard145 | _guard150;
wire _guard152 = fsm_out == 5'd3;
wire _guard153 = init_repeat0_done_out;
wire _guard154 = cond_reg0_out;
wire _guard155 = ~_guard154;
wire _guard156 = _guard153 & _guard155;
wire _guard157 = _guard152 & _guard156;
wire _guard158 = tdcc_go_out;
wire _guard159 = _guard157 & _guard158;
wire _guard160 = _guard151 | _guard159;
wire _guard161 = fsm_out == 5'd13;
wire _guard162 = incr_repeat0_done_out;
wire _guard163 = cond_reg0_out;
wire _guard164 = ~_guard163;
wire _guard165 = _guard162 & _guard164;
wire _guard166 = _guard161 & _guard165;
wire _guard167 = tdcc_go_out;
wire _guard168 = _guard166 & _guard167;
wire _guard169 = _guard160 | _guard168;
wire _guard170 = fsm_out == 5'd14;
wire _guard171 = invoke6_done_out;
wire _guard172 = _guard170 & _guard171;
wire _guard173 = tdcc_go_out;
wire _guard174 = _guard172 & _guard173;
wire _guard175 = _guard169 | _guard174;
wire _guard176 = fsm_out == 5'd1;
wire _guard177 = init_repeat1_done_out;
wire _guard178 = cond_reg1_out;
wire _guard179 = ~_guard178;
wire _guard180 = _guard177 & _guard179;
wire _guard181 = _guard176 & _guard180;
wire _guard182 = tdcc_go_out;
wire _guard183 = _guard181 & _guard182;
wire _guard184 = _guard175 | _guard183;
wire _guard185 = fsm_out == 5'd15;
wire _guard186 = incr_repeat1_done_out;
wire _guard187 = cond_reg1_out;
wire _guard188 = ~_guard187;
wire _guard189 = _guard186 & _guard188;
wire _guard190 = _guard185 & _guard189;
wire _guard191 = tdcc_go_out;
wire _guard192 = _guard190 & _guard191;
wire _guard193 = _guard184 | _guard192;
wire _guard194 = fsm_out == 5'd0;
wire _guard195 = wrapper_early_reset_initI_done_out;
wire _guard196 = _guard194 & _guard195;
wire _guard197 = tdcc_go_out;
wire _guard198 = _guard196 & _guard197;
wire _guard199 = fsm_out == 5'd14;
wire _guard200 = invoke6_done_out;
wire _guard201 = _guard199 & _guard200;
wire _guard202 = tdcc_go_out;
wire _guard203 = _guard201 & _guard202;
wire _guard204 = fsm_out == 5'd1;
wire _guard205 = init_repeat1_done_out;
wire _guard206 = cond_reg1_out;
wire _guard207 = ~_guard206;
wire _guard208 = _guard205 & _guard207;
wire _guard209 = _guard204 & _guard208;
wire _guard210 = tdcc_go_out;
wire _guard211 = _guard209 & _guard210;
wire _guard212 = fsm_out == 5'd15;
wire _guard213 = incr_repeat1_done_out;
wire _guard214 = cond_reg1_out;
wire _guard215 = ~_guard214;
wire _guard216 = _guard213 & _guard215;
wire _guard217 = _guard212 & _guard216;
wire _guard218 = tdcc_go_out;
wire _guard219 = _guard217 & _guard218;
wire _guard220 = _guard211 | _guard219;
wire _guard221 = fsm_out == 5'd16;
wire _guard222 = fsm_out == 5'd2;
wire _guard223 = invoke0_done_out;
wire _guard224 = _guard222 & _guard223;
wire _guard225 = tdcc_go_out;
wire _guard226 = _guard224 & _guard225;
wire _guard227 = fsm_out == 5'd12;
wire _guard228 = invoke5_done_out;
wire _guard229 = _guard227 & _guard228;
wire _guard230 = tdcc_go_out;
wire _guard231 = _guard229 & _guard230;
wire _guard232 = fsm_out == 5'd3;
wire _guard233 = init_repeat0_done_out;
wire _guard234 = cond_reg0_out;
wire _guard235 = ~_guard234;
wire _guard236 = _guard233 & _guard235;
wire _guard237 = _guard232 & _guard236;
wire _guard238 = tdcc_go_out;
wire _guard239 = _guard237 & _guard238;
wire _guard240 = fsm_out == 5'd13;
wire _guard241 = incr_repeat0_done_out;
wire _guard242 = cond_reg0_out;
wire _guard243 = ~_guard242;
wire _guard244 = _guard241 & _guard243;
wire _guard245 = _guard240 & _guard244;
wire _guard246 = tdcc_go_out;
wire _guard247 = _guard245 & _guard246;
wire _guard248 = _guard239 | _guard247;
wire _guard249 = fsm_out == 5'd4;
wire _guard250 = invoke1_done_out;
wire _guard251 = _guard249 & _guard250;
wire _guard252 = tdcc_go_out;
wire _guard253 = _guard251 & _guard252;
wire _guard254 = fsm_out == 5'd11;
wire _guard255 = writeArrOut_done_out;
wire _guard256 = _guard254 & _guard255;
wire _guard257 = tdcc_go_out;
wire _guard258 = _guard256 & _guard257;
wire _guard259 = fsm_out == 5'd1;
wire _guard260 = init_repeat1_done_out;
wire _guard261 = cond_reg1_out;
wire _guard262 = _guard260 & _guard261;
wire _guard263 = _guard259 & _guard262;
wire _guard264 = tdcc_go_out;
wire _guard265 = _guard263 & _guard264;
wire _guard266 = fsm_out == 5'd15;
wire _guard267 = incr_repeat1_done_out;
wire _guard268 = cond_reg1_out;
wire _guard269 = _guard267 & _guard268;
wire _guard270 = _guard266 & _guard269;
wire _guard271 = tdcc_go_out;
wire _guard272 = _guard270 & _guard271;
wire _guard273 = _guard265 | _guard272;
wire _guard274 = fsm_out == 5'd7;
wire _guard275 = par0_done_out;
wire _guard276 = _guard274 & _guard275;
wire _guard277 = tdcc_go_out;
wire _guard278 = _guard276 & _guard277;
wire _guard279 = fsm_out == 5'd9;
wire _guard280 = invoke4_done_out;
wire _guard281 = _guard279 & _guard280;
wire _guard282 = tdcc_go_out;
wire _guard283 = _guard281 & _guard282;
wire _guard284 = fsm_out == 5'd6;
wire _guard285 = init_repeat_done_out;
wire _guard286 = cond_reg_out;
wire _guard287 = _guard285 & _guard286;
wire _guard288 = _guard284 & _guard287;
wire _guard289 = tdcc_go_out;
wire _guard290 = _guard288 & _guard289;
wire _guard291 = fsm_out == 5'd10;
wire _guard292 = incr_repeat_done_out;
wire _guard293 = cond_reg_out;
wire _guard294 = _guard292 & _guard293;
wire _guard295 = _guard291 & _guard294;
wire _guard296 = tdcc_go_out;
wire _guard297 = _guard295 & _guard296;
wire _guard298 = _guard290 | _guard297;
wire _guard299 = fsm_out == 5'd6;
wire _guard300 = init_repeat_done_out;
wire _guard301 = cond_reg_out;
wire _guard302 = ~_guard301;
wire _guard303 = _guard300 & _guard302;
wire _guard304 = _guard299 & _guard303;
wire _guard305 = tdcc_go_out;
wire _guard306 = _guard304 & _guard305;
wire _guard307 = fsm_out == 5'd10;
wire _guard308 = incr_repeat_done_out;
wire _guard309 = cond_reg_out;
wire _guard310 = ~_guard309;
wire _guard311 = _guard308 & _guard310;
wire _guard312 = _guard307 & _guard311;
wire _guard313 = tdcc_go_out;
wire _guard314 = _guard312 & _guard313;
wire _guard315 = _guard306 | _guard314;
wire _guard316 = fsm_out == 5'd3;
wire _guard317 = init_repeat0_done_out;
wire _guard318 = cond_reg0_out;
wire _guard319 = _guard317 & _guard318;
wire _guard320 = _guard316 & _guard319;
wire _guard321 = tdcc_go_out;
wire _guard322 = _guard320 & _guard321;
wire _guard323 = fsm_out == 5'd13;
wire _guard324 = incr_repeat0_done_out;
wire _guard325 = cond_reg0_out;
wire _guard326 = _guard324 & _guard325;
wire _guard327 = _guard323 & _guard326;
wire _guard328 = tdcc_go_out;
wire _guard329 = _guard327 & _guard328;
wire _guard330 = _guard322 | _guard329;
wire _guard331 = fsm_out == 5'd5;
wire _guard332 = invoke2_done_out;
wire _guard333 = _guard331 & _guard332;
wire _guard334 = tdcc_go_out;
wire _guard335 = _guard333 & _guard334;
wire _guard336 = fsm_out == 5'd8;
wire _guard337 = invoke3_done_out;
wire _guard338 = _guard336 & _guard337;
wire _guard339 = tdcc_go_out;
wire _guard340 = _guard338 & _guard339;
wire _guard341 = invoke4_done_out;
wire _guard342 = ~_guard341;
wire _guard343 = fsm_out == 5'd9;
wire _guard344 = _guard342 & _guard343;
wire _guard345 = tdcc_go_out;
wire _guard346 = _guard344 & _guard345;
wire _guard347 = incr_repeat1_done_out;
wire _guard348 = ~_guard347;
wire _guard349 = fsm_out == 5'd15;
wire _guard350 = _guard348 & _guard349;
wire _guard351 = tdcc_go_out;
wire _guard352 = _guard350 & _guard351;
wire _guard353 = init_repeat1_go_out;
wire _guard354 = incr_repeat1_go_out;
wire _guard355 = _guard353 | _guard354;
wire _guard356 = incr_repeat1_go_out;
wire _guard357 = init_repeat1_go_out;
wire _guard358 = incr_repeat1_go_out;
wire _guard359 = incr_repeat1_go_out;
wire _guard360 = invoke2_done_out;
wire _guard361 = ~_guard360;
wire _guard362 = fsm_out == 5'd5;
wire _guard363 = _guard361 & _guard362;
wire _guard364 = tdcc_go_out;
wire _guard365 = _guard363 & _guard364;
wire _guard366 = init_repeat0_go_out;
wire _guard367 = incr_repeat0_go_out;
wire _guard368 = _guard366 | _guard367;
wire _guard369 = init_repeat0_go_out;
wire _guard370 = incr_repeat0_go_out;
wire _guard371 = wrapper_early_reset_initI_done_out;
wire _guard372 = ~_guard371;
wire _guard373 = fsm_out == 5'd0;
wire _guard374 = _guard372 & _guard373;
wire _guard375 = tdcc_go_out;
wire _guard376 = _guard374 & _guard375;
wire _guard377 = init_repeat1_done_out;
wire _guard378 = ~_guard377;
wire _guard379 = fsm_out == 5'd1;
wire _guard380 = _guard378 & _guard379;
wire _guard381 = tdcc_go_out;
wire _guard382 = _guard380 & _guard381;
wire _guard383 = init_repeat0_go_out;
wire _guard384 = incr_repeat0_go_out;
wire _guard385 = _guard383 | _guard384;
wire _guard386 = incr_repeat0_go_out;
wire _guard387 = init_repeat0_go_out;
wire _guard388 = invoke5_done_out;
wire _guard389 = ~_guard388;
wire _guard390 = fsm_out == 5'd12;
wire _guard391 = _guard389 & _guard390;
wire _guard392 = tdcc_go_out;
wire _guard393 = _guard391 & _guard392;
wire _guard394 = wrapper_early_reset_initI_go_out;
wire _guard395 = loadElement2_go_out;
wire _guard396 = loadElement2_go_out;
wire _guard397 = pd0_out;
wire _guard398 = loadElement2_done_out;
wire _guard399 = _guard397 | _guard398;
wire _guard400 = ~_guard399;
wire _guard401 = par0_go_out;
wire _guard402 = _guard400 & _guard401;
wire _guard403 = invoke0_done_out;
wire _guard404 = ~_guard403;
wire _guard405 = fsm_out == 5'd2;
wire _guard406 = _guard404 & _guard405;
wire _guard407 = tdcc_go_out;
wire _guard408 = _guard406 & _guard407;
wire _guard409 = incr_repeat_done_out;
wire _guard410 = ~_guard409;
wire _guard411 = fsm_out == 5'd10;
wire _guard412 = _guard410 & _guard411;
wire _guard413 = tdcc_go_out;
wire _guard414 = _guard412 & _guard413;
wire _guard415 = cond_reg1_done;
wire _guard416 = idx1_done;
wire _guard417 = _guard415 & _guard416;
wire _guard418 = loadElement2_go_out;
wire _guard419 = loadElement2_go_out;
wire _guard420 = cond_reg0_done;
wire _guard421 = idx0_done;
wire _guard422 = _guard420 & _guard421;
wire _guard423 = invoke1_go_out;
wire _guard424 = invoke1_go_out;
wire _guard425 = init_repeat_go_out;
wire _guard426 = incr_repeat_go_out;
wire _guard427 = _guard425 | _guard426;
wire _guard428 = incr_repeat_go_out;
wire _guard429 = init_repeat_go_out;
wire _guard430 = pd_out;
wire _guard431 = loadElement1_done_out;
wire _guard432 = _guard430 | _guard431;
wire _guard433 = ~_guard432;
wire _guard434 = par0_go_out;
wire _guard435 = _guard433 & _guard434;
wire _guard436 = cond_reg_done;
wire _guard437 = idx_done;
wire _guard438 = _guard436 & _guard437;
wire _guard439 = cond_reg_done;
wire _guard440 = idx_done;
wire _guard441 = _guard439 & _guard440;
wire _guard442 = cond_reg0_done;
wire _guard443 = idx0_done;
wire _guard444 = _guard442 & _guard443;
wire _guard445 = signal_reg_out;
wire _guard446 = pd_out;
wire _guard447 = pd0_out;
wire _guard448 = _guard446 & _guard447;
wire _guard449 = incr_repeat0_go_out;
wire _guard450 = incr_repeat0_go_out;
wire _guard451 = invoke1_done_out;
wire _guard452 = ~_guard451;
wire _guard453 = fsm_out == 5'd4;
wire _guard454 = _guard452 & _guard453;
wire _guard455 = tdcc_go_out;
wire _guard456 = _guard454 & _guard455;
wire _guard457 = init_repeat0_done_out;
wire _guard458 = ~_guard457;
wire _guard459 = fsm_out == 5'd3;
wire _guard460 = _guard458 & _guard459;
wire _guard461 = tdcc_go_out;
wire _guard462 = _guard460 & _guard461;
wire _guard463 = incr_repeat0_done_out;
wire _guard464 = ~_guard463;
wire _guard465 = fsm_out == 5'd13;
wire _guard466 = _guard464 & _guard465;
wire _guard467 = tdcc_go_out;
wire _guard468 = _guard466 & _guard467;
wire _guard469 = invoke6_go_out;
wire _guard470 = early_reset_initI_go_out;
wire _guard471 = _guard469 | _guard470;
wire _guard472 = invoke6_go_out;
wire _guard473 = early_reset_initI_go_out;
wire _guard474 = invoke3_go_out;
wire _guard475 = invoke3_go_out;
wire _guard476 = invoke3_go_out;
wire _guard477 = signal_reg_out;
wire _guard478 = _guard0 & _guard0;
wire _guard479 = signal_reg_out;
wire _guard480 = ~_guard479;
wire _guard481 = _guard478 & _guard480;
wire _guard482 = wrapper_early_reset_initI_go_out;
wire _guard483 = _guard481 & _guard482;
wire _guard484 = _guard477 | _guard483;
wire _guard485 = _guard0 & _guard0;
wire _guard486 = signal_reg_out;
wire _guard487 = ~_guard486;
wire _guard488 = _guard485 & _guard487;
wire _guard489 = wrapper_early_reset_initI_go_out;
wire _guard490 = _guard488 & _guard489;
wire _guard491 = signal_reg_out;
wire _guard492 = cond_reg1_done;
wire _guard493 = idx1_done;
wire _guard494 = _guard492 & _guard493;
wire _guard495 = invoke2_go_out;
wire _guard496 = invoke4_go_out;
wire _guard497 = _guard495 | _guard496;
wire _guard498 = invoke4_go_out;
wire _guard499 = invoke2_go_out;
wire _guard500 = pd_out;
wire _guard501 = pd0_out;
wire _guard502 = _guard500 & _guard501;
wire _guard503 = loadElement1_done_out;
wire _guard504 = par0_go_out;
wire _guard505 = _guard503 & _guard504;
wire _guard506 = _guard502 | _guard505;
wire _guard507 = loadElement1_done_out;
wire _guard508 = par0_go_out;
wire _guard509 = _guard507 & _guard508;
wire _guard510 = pd_out;
wire _guard511 = pd0_out;
wire _guard512 = _guard510 & _guard511;
wire _guard513 = pd_out;
wire _guard514 = pd0_out;
wire _guard515 = _guard513 & _guard514;
wire _guard516 = loadElement2_done_out;
wire _guard517 = par0_go_out;
wire _guard518 = _guard516 & _guard517;
wire _guard519 = _guard515 | _guard518;
wire _guard520 = loadElement2_done_out;
wire _guard521 = par0_go_out;
wire _guard522 = _guard520 & _guard521;
wire _guard523 = pd_out;
wire _guard524 = pd0_out;
wire _guard525 = _guard523 & _guard524;
wire _guard526 = writeArrOut_go_out;
wire _guard527 = writeArrOut_go_out;
wire _guard528 = writeArrOut_go_out;
wire _guard529 = writeArrOut_go_out;
wire _guard530 = fsm_out == 5'd16;
wire _guard531 = incr_repeat_go_out;
wire _guard532 = incr_repeat_go_out;
wire _guard533 = invoke3_done_out;
wire _guard534 = ~_guard533;
wire _guard535 = fsm_out == 5'd8;
wire _guard536 = _guard534 & _guard535;
wire _guard537 = tdcc_go_out;
wire _guard538 = _guard536 & _guard537;
wire _guard539 = loadElement1_go_out;
wire _guard540 = loadElement1_go_out;
wire _guard541 = writeArrOut_done_out;
wire _guard542 = ~_guard541;
wire _guard543 = fsm_out == 5'd11;
wire _guard544 = _guard542 & _guard543;
wire _guard545 = tdcc_go_out;
wire _guard546 = _guard544 & _guard545;
wire _guard547 = invoke6_done_out;
wire _guard548 = ~_guard547;
wire _guard549 = fsm_out == 5'd14;
wire _guard550 = _guard548 & _guard549;
wire _guard551 = tdcc_go_out;
wire _guard552 = _guard550 & _guard551;
wire _guard553 = init_repeat_go_out;
wire _guard554 = incr_repeat_go_out;
wire _guard555 = _guard553 | _guard554;
wire _guard556 = init_repeat_go_out;
wire _guard557 = incr_repeat_go_out;
wire _guard558 = incr_repeat0_go_out;
wire _guard559 = incr_repeat0_go_out;
wire _guard560 = par0_done_out;
wire _guard561 = ~_guard560;
wire _guard562 = fsm_out == 5'd7;
wire _guard563 = _guard561 & _guard562;
wire _guard564 = tdcc_go_out;
wire _guard565 = _guard563 & _guard564;
assign element1_write_en = _guard1;
assign element1_clk = clk;
assign element1_reset = reset;
assign element1_in = arr1_read_data;
assign cond_reg1_write_en = _guard5;
assign cond_reg1_clk = clk;
assign cond_reg1_reset = reset;
assign cond_reg1_in =
  _guard6 ? 1'd1 :
  _guard7 ? lt1_out :
  1'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard7, _guard6})) begin
    $fatal(2, "Multiple assignment to port `cond_reg1.in'.");
end
end
assign adder1_left =
  _guard8 ? idx1_out :
  3'd0;
assign adder1_right =
  _guard9 ? 3'd1 :
  3'd0;
assign init_repeat_go_in = _guard15;
assign j_write_en = _guard18;
assign j_clk = clk;
assign j_reset = reset;
assign j_in =
  _guard19 ? add1_out :
  _guard20 ? 32'd0 :
  'x;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard20, _guard19})) begin
    $fatal(2, "Multiple assignment to port `j.in'.");
end
end
assign add1_left =
  _guard21 ? j_out :
  _guard22 ? i_out :
  _guard23 ? multE_out :
  'x;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard23, _guard22, _guard21})) begin
    $fatal(2, "Multiple assignment to port `add1.left'.");
end
end
assign add1_right =
  _guard26 ? 32'd1 :
  _guard27 ? outE_out :
  'x;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard27, _guard26})) begin
    $fatal(2, "Multiple assignment to port `add1.right'.");
end
end
assign done = _guard28;
assign adder_left =
  _guard29 ? idx_out :
  3'd0;
assign adder_right =
  _guard30 ? 3'd1 :
  3'd0;
assign fsm_write_en = _guard193;
assign fsm_clk = clk;
assign fsm_reset = reset;
assign fsm_in =
  _guard198 ? 5'd1 :
  _guard203 ? 5'd15 :
  _guard220 ? 5'd16 :
  _guard221 ? 5'd0 :
  _guard226 ? 5'd3 :
  _guard231 ? 5'd13 :
  _guard248 ? 5'd14 :
  _guard253 ? 5'd5 :
  _guard258 ? 5'd12 :
  _guard273 ? 5'd2 :
  _guard278 ? 5'd8 :
  _guard283 ? 5'd10 :
  _guard298 ? 5'd7 :
  _guard315 ? 5'd11 :
  _guard330 ? 5'd4 :
  _guard335 ? 5'd6 :
  _guard340 ? 5'd9 :
  5'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard340, _guard335, _guard330, _guard315, _guard298, _guard283, _guard278, _guard273, _guard258, _guard253, _guard248, _guard231, _guard226, _guard221, _guard220, _guard203, _guard198})) begin
    $fatal(2, "Multiple assignment to port `fsm.in'.");
end
end
assign loadElement1_done_in = element1_done;
assign invoke4_go_in = _guard346;
assign incr_repeat1_go_in = _guard352;
assign early_reset_initI_done_in = ud_out;
assign idx1_write_en = _guard355;
assign idx1_clk = clk;
assign idx1_reset = reset;
assign idx1_in =
  _guard356 ? adder1_out :
  _guard357 ? 3'd0 :
  3'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard357, _guard356})) begin
    $fatal(2, "Multiple assignment to port `idx1.in'.");
end
end
assign lt1_left =
  _guard358 ? adder1_out :
  3'd0;
assign lt1_right =
  _guard359 ? 3'd6 :
  3'd0;
assign invoke2_go_in = _guard365;
assign cond_reg0_write_en = _guard368;
assign cond_reg0_clk = clk;
assign cond_reg0_reset = reset;
assign cond_reg0_in =
  _guard369 ? 1'd1 :
  _guard370 ? lt0_out :
  1'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard370, _guard369})) begin
    $fatal(2, "Multiple assignment to port `cond_reg0.in'.");
end
end
assign loadElement2_done_in = element2_done;
assign writeArrOut_done_in = arrOut_done;
assign wrapper_early_reset_initI_go_in = _guard376;
assign init_repeat1_go_in = _guard382;
assign idx0_write_en = _guard385;
assign idx0_clk = clk;
assign idx0_reset = reset;
assign idx0_in =
  _guard386 ? adder0_out :
  _guard387 ? 3'd0 :
  3'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard387, _guard386})) begin
    $fatal(2, "Multiple assignment to port `idx0.in'.");
end
end
assign invoke5_go_in = _guard393;
assign invoke5_done_in = j_done;
assign early_reset_initI_go_in = _guard394;
assign arr2_write_en = 1'd0;
assign arr2_clk = clk;
assign arr2_addr0 =
  _guard395 ? k_out :
  32'd0;
assign arr2_reset = reset;
assign arr2_addr1 =
  _guard396 ? j_out :
  32'd0;
assign loadElement2_go_in = _guard402;
assign invoke0_go_in = _guard408;
assign incr_repeat_go_in = _guard414;
assign init_repeat1_done_in = _guard417;
assign tdcc_go_in = go;
assign element2_write_en = _guard418;
assign element2_clk = clk;
assign element2_reset = reset;
assign element2_in = arr2_read_data;
assign invoke3_done_in = multE_done;
assign incr_repeat0_done_in = _guard422;
assign k_write_en = _guard423;
assign k_clk = clk;
assign k_reset = reset;
assign k_in = 32'd0;
assign idx_write_en = _guard427;
assign idx_clk = clk;
assign idx_reset = reset;
assign idx_in =
  _guard428 ? adder_out :
  _guard429 ? 3'd0 :
  3'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard429, _guard428})) begin
    $fatal(2, "Multiple assignment to port `idx.in'.");
end
end
assign loadElement1_go_in = _guard435;
assign init_repeat_done_in = _guard438;
assign incr_repeat_done_in = _guard441;
assign init_repeat0_done_in = _guard444;
assign wrapper_early_reset_initI_done_in = _guard445;
assign par0_done_in = _guard448;
assign adder0_left =
  _guard449 ? idx0_out :
  3'd0;
assign adder0_right =
  _guard450 ? 3'd1 :
  3'd0;
assign invoke0_done_in = j_done;
assign invoke1_go_in = _guard456;
assign invoke6_done_in = i_done;
assign init_repeat0_go_in = _guard462;
assign incr_repeat0_go_in = _guard468;
assign i_write_en = _guard471;
assign i_clk = clk;
assign i_reset = reset;
assign i_in =
  _guard472 ? add1_out :
  _guard473 ? 32'd0 :
  'x;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard473, _guard472})) begin
    $fatal(2, "Multiple assignment to port `i.in'.");
end
end
assign multE_clk = clk;
assign multE_left = element1_out;
assign multE_go = _guard475;
assign multE_reset = reset;
assign multE_right = element2_out;
assign signal_reg_write_en = _guard484;
assign signal_reg_clk = clk;
assign signal_reg_reset = reset;
assign signal_reg_in =
  _guard490 ? 1'd1 :
  _guard491 ? 1'd0 :
  1'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard491, _guard490})) begin
    $fatal(2, "Multiple assignment to port `signal_reg.in'.");
end
end
assign invoke2_done_in = outE_done;
assign incr_repeat1_done_in = _guard494;
assign outE_write_en = _guard497;
assign outE_clk = clk;
assign outE_reset = reset;
assign outE_in =
  _guard498 ? add1_out :
  _guard499 ? 32'd0 :
  'x;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard499, _guard498})) begin
    $fatal(2, "Multiple assignment to port `outE.in'.");
end
end
assign pd_write_en = _guard506;
assign pd_clk = clk;
assign pd_reset = reset;
assign pd_in =
  _guard509 ? 1'd1 :
  _guard512 ? 1'd0 :
  1'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard512, _guard509})) begin
    $fatal(2, "Multiple assignment to port `pd.in'.");
end
end
assign pd0_write_en = _guard519;
assign pd0_clk = clk;
assign pd0_reset = reset;
assign pd0_in =
  _guard522 ? 1'd1 :
  _guard525 ? 1'd0 :
  1'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard525, _guard522})) begin
    $fatal(2, "Multiple assignment to port `pd0.in'.");
end
end
assign arrOut_write_en = _guard526;
assign arrOut_clk = clk;
assign arrOut_addr0 =
  _guard527 ? i_out :
  32'd0;
assign arrOut_reset = reset;
assign arrOut_write_data = outE_out;
assign arrOut_addr1 =
  _guard529 ? j_out :
  32'd0;
assign tdcc_done_in = _guard530;
assign lt_left =
  _guard531 ? adder_out :
  3'd0;
assign lt_right =
  _guard532 ? 3'd5 :
  3'd0;
assign invoke3_go_in = _guard538;
assign invoke4_done_in = outE_done;
assign arr1_write_en = 1'd0;
assign arr1_clk = clk;
assign arr1_addr0 =
  _guard539 ? i_out :
  32'd0;
assign arr1_reset = reset;
assign arr1_addr1 =
  _guard540 ? k_out :
  32'd0;
assign writeArrOut_go_in = _guard546;
assign invoke1_done_in = k_done;
assign invoke6_go_in = _guard552;
assign cond_reg_write_en = _guard555;
assign cond_reg_clk = clk;
assign cond_reg_reset = reset;
assign cond_reg_in =
  _guard556 ? 1'd1 :
  _guard557 ? lt_out :
  1'd0;
always_ff @(posedge clk) begin
  if(~$onehot0({_guard557, _guard556})) begin
    $fatal(2, "Multiple assignment to port `cond_reg.in'.");
end
end
assign lt0_left =
  _guard558 ? adder0_out :
  3'd0;
assign lt0_right =
  _guard559 ? 3'd7 :
  3'd0;
assign par0_go_in = _guard565;
// COMPONENT END: main
endmodule
