`timescale 1ns/1ps
`default_nettype none

module tb_aes_axi_slave;

    parameter AXI_ADDR_WIDTH = 8;

    // ================================================================
    // CLOCK / RESET
    // ================================================================
    reg clk;
    reg aresetn;

    // IMPORTANT:
    // aes_axi_slave : aresetn active LOW
    // aes_cipher_top: rst active LOW
    //
    // Therefore both are reset low, then released high.
    // ================================================================


    // ================================================================
    // AXI4-LITE SIGNALS
    // ================================================================

    reg  [AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    reg  [2:0]                s_axi_awprot;
    reg                       s_axi_awvalid;
    wire                      s_axi_awready;

    reg  [31:0]               s_axi_wdata;
    reg  [3:0]                s_axi_wstrb;
    reg                       s_axi_wvalid;
    wire                      s_axi_wready;

    wire [1:0]                s_axi_bresp;
    wire                      s_axi_bvalid;
    reg                       s_axi_bready;

    reg  [AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    reg  [2:0]                s_axi_arprot;
    reg                       s_axi_arvalid;
    wire                      s_axi_arready;

    wire [31:0]               s_axi_rdata;
    wire [1:0]                s_axi_rresp;
    wire                      s_axi_rvalid;
    reg                       s_axi_rready;


    // ================================================================
    // AES CIPHER SIDE
    // ================================================================

    wire        cipher_ld;
    wire        cipher_done;

    wire [255:0] cipher_key;
    wire [127:0] cipher_text_in;
    wire [127:0] cipher_text_out;


    // ================================================================
    // AES INVERSE CIPHER SIDE
    // ================================================================

    wire        inv_kld;
    wire        inv_ld;
    wire        inv_kdone;
    wire        inv_done;

    wire [255:0] inv_key;
    wire [127:0] inv_text_in;
    wire [127:0] inv_text_out;


    // ================================================================
    // TEST VARIABLES
    // ================================================================

    integer errors;
    integer timeout;
    integer i;

    reg [31:0] rd_data;


    // ================================================================
    // DUT : AXI4-LITE AES SLAVE
    // ================================================================

    aes_axi_slave #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) dut (

        .aclk           (clk),
        .aresetn        (aresetn),

        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awprot   (s_axi_awprot),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),

        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),

        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),

        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arprot   (s_axi_arprot),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),

        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),

        .cipher_ld      (cipher_ld),
        .cipher_done    (cipher_done),
        .cipher_key     (cipher_key),
        .cipher_text_in (cipher_text_in),
        .cipher_text_out(cipher_text_out),

        .inv_kld        (inv_kld),
        .inv_kdone      (inv_kdone),
        .inv_ld         (inv_ld),
        .inv_done       (inv_done),
        .inv_key        (inv_key),
        .inv_text_in    (inv_text_in),
        .inv_text_out   (inv_text_out)
    );


    // ================================================================
    // REAL AES CIPHER CORE
    // ================================================================

    aes_cipher_top cipher_core (

        .clk      (clk),

        // AES core reset is ACTIVE LOW
        .rst      (aresetn),

        .ld       (cipher_ld),
        .done     (cipher_done),

        .key      (cipher_key),
        .text_in  (cipher_text_in),
        .text_out (cipher_text_out)
    );


    // ================================================================
    // REAL AES INVERSE CIPHER CORE
    // ================================================================

    aes_inv_cipher_top inverse_core (

        .clk      (clk),

        // AES core reset is ACTIVE LOW
        .rst      (aresetn),

        .kld      (inv_kld),
        .kdone    (inv_kdone),

        .ld       (inv_ld),
        .done     (inv_done),

        .key      (inv_key),
        .text_in  (inv_text_in),
        .text_out (inv_text_out)
    );


    // ================================================================
    // CLOCK
    // ================================================================

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end


    // ================================================================
    // AXI WRITE
    // ================================================================

    task automatic axi_write;

        input [AXI_ADDR_WIDTH-1:0] addr;
        input [31:0] data;

        begin

            // --------------------------------------------------------
            // Drive transaction
            // --------------------------------------------------------

            @(posedge clk);

            s_axi_awaddr  <= addr;
            s_axi_awprot  <= 3'b000;
            s_axi_awvalid <= 1'b1;

            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hF;
            s_axi_wvalid  <= 1'b1;


            // --------------------------------------------------------
            // Wait for AW handshake
            // --------------------------------------------------------

            while (!s_axi_awready)
                @(posedge clk);

            @(posedge clk);

            s_axi_awvalid <= 1'b0;


            // --------------------------------------------------------
            // Wait for W handshake
            // --------------------------------------------------------

            while (!s_axi_wready)
                @(posedge clk);

            @(posedge clk);

            s_axi_wvalid <= 1'b0;


            // --------------------------------------------------------
            // Wait for B response
            // --------------------------------------------------------

            s_axi_bready <= 1'b1;

            timeout = 0;

            while (!s_axi_bvalid) begin

                @(posedge clk);

                timeout = timeout + 1;

                if (timeout > 100) begin

                    $display(
                        "ERROR: AXI WRITE TIMEOUT addr=%h data=%h",
                        addr,
                        data
                    );

                    errors = errors + 1;

                    disable axi_write;
                end
            end


            // --------------------------------------------------------
            // Check response
            // --------------------------------------------------------

            if (s_axi_bresp !== 2'b00) begin

                $display(
                    "ERROR: AXI WRITE RESPONSE addr=%h BRESP=%b",
                    addr,
                    s_axi_bresp
                );

                errors = errors + 1;

            end


            @(posedge clk);

            s_axi_bready <= 1'b0;

        end

    endtask


    // ================================================================
    // AXI READ
    // ================================================================

    task automatic axi_read;

        input  [AXI_ADDR_WIDTH-1:0] addr;
        output [31:0] data;

        begin

            @(posedge clk);

            s_axi_araddr  <= addr;
            s_axi_arprot  <= 3'b000;
            s_axi_arvalid <= 1'b1;


            // --------------------------------------------------------
            // Wait for AR handshake
            // --------------------------------------------------------

            timeout = 0;

            while (!s_axi_arready) begin

                @(posedge clk);

                timeout = timeout + 1;

                if (timeout > 100) begin

                    $display(
                        "ERROR: AXI READ ADDRESS TIMEOUT addr=%h",
                        addr
                    );

                    errors = errors + 1;

                    data = 32'hxxxxxxxx;

                    disable axi_read;
                end
            end


            @(posedge clk);

            s_axi_arvalid <= 1'b0;


            // --------------------------------------------------------
            // Wait for R response
            // --------------------------------------------------------

            s_axi_rready <= 1'b1;

            timeout = 0;

            while (!s_axi_rvalid) begin

                @(posedge clk);

                timeout = timeout + 1;

                if (timeout > 100) begin

                    $display(
                        "ERROR: AXI READ DATA TIMEOUT addr=%h",
                        addr
                    );

                    errors = errors + 1;

                    data = 32'hxxxxxxxx;

                    disable axi_read;
                end
            end


            data = s_axi_rdata;


            if (s_axi_rresp !== 2'b00) begin

                $display(
                    "ERROR: AXI READ RESPONSE addr=%h RRESP=%b",
                    addr,
                    s_axi_rresp
                );

                errors = errors + 1;

            end


            @(posedge clk);

            s_axi_rready <= 1'b0;

        end

    endtask


    // ================================================================
    // WAIT FOR CIPHER DONE
    // ================================================================

    task automatic wait_cipher_done;

        begin

            timeout = 0;

            while (!cipher_done) begin

                @(posedge clk);

                timeout = timeout + 1;

                if (timeout > 1000) begin

                    $display("");
                    $display(
                        "ERROR: AES CIPHER TIMEOUT"
                    );
                    $display(
                        "cipher_ld  = %b",
                        cipher_ld
                    );
                    $display(
                        "cipher_done = %b",
                        cipher_done
                    );
                    $display(
                        "cipher_key  = %h",
                        cipher_key
                    );
                    $display(
                        "cipher_text_in = %h",
                        cipher_text_in
                    );
                    $display("");

                    errors = errors + 1;

                    disable wait_cipher_done;
                end

            end

        end

    endtask


    // ================================================================
    // WAIT FOR INVERSE KDONE
    // ================================================================

    task automatic wait_inverse_kdone;

        begin

            timeout = 0;

            while (!inv_kdone) begin

                @(posedge clk);

                timeout = timeout + 1;

                if (timeout > 1000) begin

                    $display("");
                    $display("ERROR: AES INVERSE KEY EXPANSION TIMEOUT");
                    $display("");

                    errors = errors + 1;

                    disable wait_inverse_kdone;
                end

            end

        end

    endtask


    // ================================================================
    // WAIT FOR INVERSE DONE
    // ================================================================

    task automatic wait_inverse_done;

        begin

            timeout = 0;

            while (!inv_done) begin

                @(posedge clk);

                timeout = timeout + 1;

                if (timeout > 1000) begin

                    $display("");
                    $display(
                        "ERROR: AES INVERSE CIPHER TIMEOUT"
                    );
                    $display(
                        "inv_kld  = %b",
                        inv_kld
                    );
                    $display(
                        "inv_kdone = %b",
                        inv_kdone
                    );
                    $display(
                        "inv_ld = %b",
                        inv_ld
                    );
                    $display(
                        "inv_done = %b",
                        inv_done
                    );
                    $display(
                        "inv_key = %h",
                        inv_key
                    );
                    $display(
                        "inv_text_in = %h",
                        inv_text_in
                    );
                    $display("");

                    errors = errors + 1;

                    disable wait_inverse_done;
                end

            end

        end

    endtask


    // ================================================================
    // INITIALIZATION + TEST
    // ================================================================

    initial begin

        errors = 0;


        // ------------------------------------------------------------
        // AXI initialization
        // ------------------------------------------------------------

        s_axi_awaddr  = 0;
        s_axi_awprot  = 0;
        s_axi_awvalid = 0;

        s_axi_wdata   = 0;
        s_axi_wstrb   = 0;
        s_axi_wvalid  = 0;

        s_axi_bready  = 0;

        s_axi_araddr  = 0;
        s_axi_arprot  = 0;
        s_axi_arvalid = 0;

        s_axi_rready  = 0;


        // ------------------------------------------------------------
        // RESET
        // ------------------------------------------------------------

        //
        // BOTH resets are active LOW.
        //
        aresetn = 1'b0;

        repeat (5)
            @(posedge clk);

        aresetn = 1'b1;

        repeat (5)
            @(posedge clk);


        $display("");
        $display("====================================================");
        $display(" AES AXI4-LITE TEST START");
        $display("====================================================");
        $display("");


        // ============================================================
        // TEST VECTOR 0 (NIST FIPS-197 AES-256 Appendix C.3)
        //
        // Key:
        // 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
        //
        // Plaintext:
        // 00112233445566778899aabbccddeeff
        //
        // Expected ciphertext:
        // 8ea2b7ca516745bfeafc49904b496089
        // ============================================================

        $display("----------------------------------------------------");
        $display("VECTOR 0 (AES-256 NIST FIPS-197 App C.3)");
        $display("----------------------------------------------------");


        // ------------------------------------------------------------
        // KEY (256-bit: KEY0-KEY7)
        // ------------------------------------------------------------

        axi_write(
            8'h04,
            32'h1c1d1e1f
        );

        axi_write(
            8'h08,
            32'h18191a1b
        );

        axi_write(
            8'h0C,
            32'h14151617
        );

        axi_write(
            8'h10,
            32'h10111213
        );

        axi_write(
            8'h14,
            32'h0c0d0e0f
        );

        axi_write(
            8'h18,
            32'h08090a0b
        );

        axi_write(
            8'h1C,
            32'h04050607
        );

        axi_write(
            8'h20,
            32'h00010203
        );


        // ------------------------------------------------------------
        // PLAINTEXT
        // ------------------------------------------------------------

        axi_write(
            8'h24,
            32'hccddeeff
        );

        axi_write(
            8'h28,
            32'h8899aabb
        );

        axi_write(
            8'h2C,
            32'h44556677
        );

        axi_write(
            8'h30,
            32'h00112233
        );


        // ------------------------------------------------------------
        // START CIPHER
        // CSR bit[16] = LD
        // ------------------------------------------------------------

        $display("Starting AES encryption...");

        axi_write(
            8'h00,
            32'h0001_0000
        );


        // ------------------------------------------------------------
        // WAIT FOR AES
        // ------------------------------------------------------------

        wait_cipher_done;


        $display(
            "AES DONE at time %0t",
            $time
        );


        // ------------------------------------------------------------
        // READ CIPHERTEXT
        // ------------------------------------------------------------

        axi_read(8'h34, rd_data);

        if (rd_data !== 32'h4b496089) begin

            $display(
                "ERROR: OUT0 expected 4b496089 got %h",
                rd_data
            );

            errors = errors + 1;

        end
        else
            $display("PASS: OUT0 = %h", rd_data);


        axi_read(8'h38, rd_data);

        if (rd_data !== 32'heafc4990) begin

            $display(
                "ERROR: OUT1 expected eafc4990 got %h",
                rd_data
            );

            errors = errors + 1;

        end
        else
            $display("PASS: OUT1 = %h", rd_data);


        axi_read(8'h3C, rd_data);

        if (rd_data !== 32'h516745bf) begin

            $display(
                "ERROR: OUT2 expected 516745bf got %h",
                rd_data
            );

            errors = errors + 1;

        end
        else
            $display("PASS: OUT2 = %h", rd_data);


        axi_read(8'h40, rd_data);

        if (rd_data !== 32'h8ea2b7ca) begin

            $display(
                "ERROR: OUT3 expected 8ea2b7ca got %h",
                rd_data
            );

            errors = errors + 1;

        end
        else
            $display("PASS: OUT3 = %h", rd_data);


        // ============================================================
        // INVERSE CIPHER
        // ============================================================

        $display("");
        $display("Starting AES inverse key expansion...");


        // ------------------------------------------------------------
        // INVERSE KEY (256-bit: INV_KEY0-INV_KEY7)
        // ------------------------------------------------------------

        axi_write(
            8'h48,
            32'h1c1d1e1f
        );

        axi_write(
            8'h4C,
            32'h18191a1b
        );

        axi_write(
            8'h50,
            32'h14151617
        );

        axi_write(
            8'h54,
            32'h10111213
        );

        axi_write(
            8'h58,
            32'h0c0d0e0f
        );

        axi_write(
            8'h5C,
            32'h08090a0b
        );

        axi_write(
            8'h60,
            32'h04050607
        );

        axi_write(
            8'h64,
            32'h00010203
        );


        // ------------------------------------------------------------
        // KLD (pulse bit[17])
        // ------------------------------------------------------------

        axi_write(
            8'h44,
            32'h0002_0000
        );


        // ------------------------------------------------------------
        // WAIT FOR INVERSE KEY EXPANSION
        // ------------------------------------------------------------

        wait_inverse_kdone;

        $display(
            "AES INVERSE KEY EXPANSION DONE at time %0t",
            $time
        );


        // ------------------------------------------------------------
        // CIPHERTEXT INPUT TO DECRYPT
        // ------------------------------------------------------------

        axi_write(
            8'h68,
            32'h4b496089
        );

        axi_write(
            8'h6C,
            32'heafc4990
        );

        axi_write(
            8'h70,
            32'h516745bf
        );

        axi_write(
            8'h74,
            32'h8ea2b7ca
        );


        // ------------------------------------------------------------
        // LD (pulse bit[16])
        // ------------------------------------------------------------

        $display("");
        $display("Starting AES decryption...");

        axi_write(
            8'h44,
            32'h0001_0000
        );


        // ------------------------------------------------------------
        // WAIT FOR DECRYPTION
        // ------------------------------------------------------------

        wait_inverse_done;


        $display(
            "AES DECRYPT DONE at time %0t",
            $time
        );


        // ------------------------------------------------------------
        // READ PLAINTEXT
        // ------------------------------------------------------------

        axi_read(8'h78, rd_data);

        if (rd_data !== 32'hccddeeff) begin

            $display(
                "ERROR: INV_OUT0 expected ccddeeff got %h",
                rd_data
            );

            errors = errors + 1;

        end
        else
            $display("PASS: INV_OUT0 = %h", rd_data);


        axi_read(8'h7C, rd_data);

        if (rd_data !== 32'h8899aabb) begin

            $display(
                "ERROR: INV_OUT1 expected 8899aabb got %h",
                rd_data
            );

            errors = errors + 1;

        end
        else
            $display("PASS: INV_OUT1 = %h", rd_data);


        axi_read(8'h80, rd_data);

        if (rd_data !== 32'h44556677) begin

            $display(
                "ERROR: INV_OUT2 expected 44556677 got %h",
                rd_data
            );

            errors = errors + 1;

        end
        else
            $display("PASS: INV_OUT2 = %h", rd_data);


        axi_read(8'h84, rd_data);

        if (rd_data !== 32'h00112233) begin

            $display(
                "ERROR: INV_OUT3 expected 00112233 got %h",
                rd_data
            );

            errors = errors + 1;

        end
        else
            $display("PASS: INV_OUT3 = %h", rd_data);


        // ============================================================
        // FINAL RESULT
        // ============================================================

        $display("");
        $display("====================================================");

        if (errors == 0) begin

            $display(
                "TEST PASSED - NO ERRORS"
            );

        end
        else begin

            $display(
                "TEST FAILED - %0d ERRORS",
                errors
            );

        end

        $display("====================================================");
        $display("");


        repeat (10)
            @(posedge clk);

        $finish;

    end


    // ================================================================
    // WAVEFORM
    // ================================================================

    initial begin

        $fsdbDumpfile("dump.fsdb");

        $fsdbDumpvars("+all");

        $fsdbDumpMDA();

        $fsdbDumpSVA();

    end


endmodule

`default_nettype wire
