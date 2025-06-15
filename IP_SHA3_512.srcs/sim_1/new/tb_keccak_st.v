`timescale 1ns/1ps
`define P 20

module tb_keccak_st;
  // DUT I/O
  reg           clk, reset;
  reg  [63:0]   in;
  reg           in_ready, is_last;
  reg   [2:0]   byte_num;
  wire          buffer_full, out_ready;
  wire [511:0]  out;

  // file I/O helpers
  integer fd, status, n_words, w, test_i;
  reg [8*256:1] line;            // ?? dài ?? ch?a 1 dòng text
  reg [63:0]    word64;
  reg [2:0]     lastb;
  reg [511:0]   expect_hash;

  // instantiate DUT
  keccak uut (
    .clk(clk), .reset(reset),
    .in(in), .in_ready(in_ready),
    .is_last(is_last), .byte_num(byte_num),
    .buffer_full(buffer_full),
    .out(out), .out_ready(out_ready)
  );

  // clock gen
  initial clk = 0;
  always #(`P/2) clk = ~clk;

  initial begin
    // 1) m? file
    fd = $fopen("vectors.mem", "r");
    if (fd == 0) begin
      $display("ERROR: vectors.mem not found"); 
      $finish;
    end

    test_i = 0;
    // 2) loop ??n EOF
    while (!$feof(fd)) begin
      // ??c 1 dòng
      status = $fgets(line, fd);
      // n?u là comment ho?c blank thì skip (không làm gì)
      if (line[1] == "/" || line[1] == "#" || line == "\n") begin
        // skip
      end else begin
        // parse s? words
        status = $sscanf(line, "%d", n_words);

        // reset DUT
        reset = 1; #(`P); reset = 0;
        @(negedge clk);

        // feed data
        if (n_words > 0) begin
          in_ready = 1; is_last = 0; byte_num = 0;
          // feed n_words-1 block
          for (w = 0; w < n_words-1; w = w + 1) begin
            status = $fgets(line, fd);
            status = $sscanf(line, "%h", word64);
            in = word64; 
            #(`P);
          end
          // feed block cu?i
          status = $fgets(line, fd);
          status = $sscanf(line, "%h", word64);
          status = $fgets(line, fd);
          status = $sscanf(line, "%d", lastb);
          status = $fgets(line, fd);
          status = $sscanf(line, "%h", expect_hash);

          in       = word64;
          is_last  = 1;
          byte_num = lastb;
          #(`P);
        end else begin
          // test empty string
          in_ready = 1; is_last = 1; byte_num = 0;
          // v?n ph?i ??c lastb + hash
          status = $fgets(line, fd);
          status = $sscanf(line, "%d", lastb);
          status = $fgets(line, fd);
          status = $sscanf(line, "%h", expect_hash);
          #(`P);
        end

        // stop feeding
        in_ready = 0; is_last = 0;

        // ch? out_ready và so sánh
        while (!out_ready) #(`P);
        if (out !== expect_hash) begin
          $display("TEST %0d FAILED: got %h, expect %h", test_i, out, expect_hash);
          $finish;
        end else begin
          $display("TEST %0d PASSED", test_i);
        end

        // ??i cho pipeline s?ch
        #(`P*2);
        test_i = test_i + 1;
      end
    end

    $display("ALL %0d TESTS PASSED!", test_i);
    $fclose(fd);
    $finish;
  end
endmodule

`undef P
