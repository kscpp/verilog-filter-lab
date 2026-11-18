`timescale 1ns/1ps
module tb_filter;
  reg clk = 0;
  always #5 clk = ~clk;
  reg rst = 0;
  reg in_valid = 0;
  reg signed [15:0] x_in = 0;
  wire out_valid;
  wire signed [15:0] y_out;
  integer hist [0:7];
  integer expected, total, count, fd, i, j;
  integer value, noise, phase, slow;
  reg [31:0] rng;

  moving_average_8 dut (
    .clk(clk), .rst(rst), .in_valid(in_valid),
    .x_in(x_in), .out_valid(out_valid), .y_out(y_out)
  );

  task tick;
    input integer rr;
    input integer vv;
    input integer xx;
    begin
      @(negedge clk);
      rst = (rr != 0);
      in_valid = (vv != 0);
      x_in = xx;
      @(posedge clk);
      if (rr != 0) begin
        for (j=0; j<8; j=j+1) hist[j] = 0;
        expected = 0;
        count = 0;
      end else if (vv != 0) begin
        for (j=7; j>0; j=j-1) hist[j] = hist[j-1];
        hist[0] = xx;
        total = 0;
        for (j=0; j<8; j=j+1) total = total + hist[j];
        if (total >= 0) expected = total / 8;
        else expected = -((-total + 7) / 8);
      end
      #1;
      if (out_valid !== ((rr == 0) && (vv != 0))) begin
        $display("FAIL valid rr=%0d vv=%0d", rr, vv);
        $fatal(1, "out_valid mismatch");
      end
      if (y_out !== expected[15:0]) begin
        $display("FAIL sample=%0d x=%0d expected=%0d actual=%0d",
                 count, xx, expected, y_out);
        $fatal(1, "y_out mismatch or X/Z");
      end
      if ((rr == 0) && (vv != 0)) begin
        $fdisplay(fd, "%0d,%0d,%0d,%0d",
                  count, xx, y_out, expected);
        count = count + 1;
      end
    end
  endtask

  initial begin
    fd = $fopen("samples.csv", "w");
    if (!fd) $fatal(1, "Cannot open CSV");
    $fdisplay(fd, "sample_index,x_in,y_rtl,y_reference");
    $dumpfile("waveforms.vcd");
    $dumpvars(0, tb_filter);
    expected = 0;
    count = 0;
    rng = 32'h12345678;
    for (i=0; i<8; i=i+1) hist[i] = 0;
    tick(1, 1, 800);
    tick(1, 0, 0);
    for (i=0; i<16; i=i+1) tick(0, 1, 800);
    tick(0, 0, 1234);
    tick(0, 0, -1234);
    tick(1, 1, 32767);
    tick(0, 1, 800);
    for (i=0; i<12; i=i+1) tick(0, 1, 0);
    tick(1, 0, 0);
    tick(0, 1, -1);
    for (i=0; i<12; i=i+1) tick(0, 1, 0);
    for (i=0; i<16; i=i+1) tick(0, 1, -32768);
    for (i=0; i<16; i=i+1) tick(0, 1, 32767);
    for (i=0; i<32; i=i+1)
      if (i % 2 == 0) tick(0, 1, 800);
      else tick(0, 1, -800);
    for (i=0; i<2000; i=i+1) begin
      rng = 32'd1664525 * rng + 32'd1013904223;
      value = rng[15:0];
      if (value >= 32768) value = value - 65536;
      if (i % 97 == 0) tick(1, 1, value);
      else tick(0, (i % 5 != 0), value);
    end
    tick(1, 0, 0);
    for (i=0; i<512; i=i+1) begin
      rng = 32'd1664525 * rng + 32'd1013904223;
      noise = rng[15:0];
      noise = (noise % 2001) - 1000;
      phase = i % 128;
      if (phase < 64) slow = -4000 + 125 * phase;
      else slow = 4000 - 125 * (phase - 64);
      tick(0, 1, slow + noise);
    end
    $fclose(fd);
    $display("TESTS_PASSED");
    $finish;
  end
  initial begin
    #1000000;
    $fatal(1, "Simulation watchdog");
  end
endmodule