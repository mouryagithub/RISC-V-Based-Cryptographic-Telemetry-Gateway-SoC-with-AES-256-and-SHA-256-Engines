# Simulation Log

*Verdi* FSDB WARNING: The FSDB file already exists. Overwriting the FSDB file may crash the programs that are using this file.
*Verdi* : Create FSDB file 'dump.fsdb'
*Verdi* : Begin traversing the scope (tb_axi_uart_top), layer (0).
*Verdi* : End of traversing.
*Verdi* : Begin traversing the SVA assertions, layer (0).
*Verdi* : End of traversing the SVA assertions.
*Verdi* : Begin traversing the MDAs, layer (0).
*Verdi* : Enable +mda and +packedmda dumping.
*Verdi* : End of traversing the MDAs.
=============================================================
 AXI-UART Top Combined Testbench
=============================================================

--- TEST 1: LCR write (DLAB=1 to access baud divisor) ---
--- TEST 2: Baud divisor write ---
--- TEST 3: LCR write (DLAB=0, 8N1) ---
--- TEST 4: IER write (enable RX data available interrupt) ---
--- TEST 5: Read LSR (THRE & TEMT reflect RTL threshold bug) ---
[PASS] ld always fails) : got 0x0
[PASS] ld always fails) : got 0x0
    LSR raw = 0x00000000 (expected 0x00000000)
--- TEST 6: TX byte 0x55 via AXI THR write ---
    AXI write to THR done
    Captured UART TX byte: 0x55
[PASS] TX byte loopback : got 0x55
--- TEST 7: TX byte 0xAA via AXI THR write ---
    Captured UART TX byte: 0x55
[FAIL]     TX byte 0xAA : got 0x55, expected 0xaa
--- TEST 8: RX byte 0x37 injected on uart_rx ---
    AXI RBR read: 0x37
[PASS]     RX byte 0x37 : got 0x37
--- TEST 9: RX byte 0xC3 injected on uart_rx ---
    AXI RBR read: 0xc3
[PASS]     RX byte 0xC3 : got 0xc3
--- TEST 10: RX interrupt assertion check ---
[PASS] terrupt asserted : got 0x1
--- TEST 11: Back-to-back TX bytes 0x01, 0x02, 0x03 ---
    captured[0] = 0x1
    captured[1] = 0x40
    captured[2] = 0x20
[PASS]        B2B TX[0] : got 0x1
[FAIL]        B2B TX[1] : got 0x40, expected 0x2
[FAIL]        B2B TX[2] : got 0x20, expected 0x3
--- TEST 12: LSR DATA_READY cleared after drain ---
    LSR after drain = 0x0

=============================================================
 RESULTS: PASS=7  FAIL=3
=============================================================
 SOME TESTS FAILED
$finish called from file "../tb/tb_axi_uart_top.sv", line 658.
$finish at simulation time             78601000
           V C S   S i m u l a t i o n   R e p o r t 
Time: 786010000 ps





[student@vlsi64 run]$ vcs -full64 -debug_access+all -sverilog -kdb -f run_integrated_soc.f

Warning-[LNX_OS_VERUN] Unsupported Linux version
  Linux version 'Rocky Linux release 8.10 (Green Obsidian)' is not supported 
  on 'x86_64' officially, assuming linux compatibility by default. Set 
  VCS_ARCH_OVERRIDE to linux or suse32 to override.
  Please refer to release notes for information on supported platforms.

Info: [VCS_SAVE_RESTORE_INFO] ASLR (Address Space Layout Randomization) is detected on the machine. To enable $save functionality, ASLR will be switched off and simv re-executed.
Please use '-no_save' simv switch to avoid this.
                         Chronologic VCS (TM)
         Version U-2023.03_Full64 -- Sat Sep 19 15:33:19 2026

                    Copyright (c) 1991 - 2023 Synopsys, Inc.
   This software and the associated documentation are proprietary to Synopsys,
 Inc. This software may only be used in accordance with the terms and conditions
 of a written license agreement with Synopsys, Inc. All other use, reproduction,
   or distribution of this software is strictly prohibited.  Licensed Products
     communicate with Synopsys servers for the purpose of providing software
    updates, detecting software piracy and verifying that customers are using
    Licensed Products in conformity with the applicable License Key for such
  Licensed Products. Synopsys will use information gathered in connection with
    this process to deliver software updates and pursue software pirates and
                                   infringers.

 Inclusivity & Diversity - Visit SolvNetPlus to read the "Synopsys Statement on
            Inclusivity and Diversity" (Refer to article 000036315 at
                        https://solvnetplus.synopsys.com)

Parsing design file '../rtl/uart/timescale.v'
Parsing design file '../rtl/uart/uart_parity_bit_compute.v'
Parsing design file '../rtl/uart/axi_internal_fifo.v'
Parsing design file '../rtl/uart/uart_receiver.v'
Parsing design file '../rtl/uart/uart_transmitter.v'
Parsing design file '../rtl/uart/uart_controller.v'
Parsing design file '../rtl/uart/axi_uart_top.v'
Parsing included file '../rtl/uart/axi_uart_defines.vh'.
Back to file '../rtl/uart/axi_uart_top.v'.
Parsing included file '../rtl/uart/axi_uart.vh'.
Back to file '../rtl/uart/axi_uart_top.v'.
Parsing design file '../rtl/interconnect/priority_encoder.v'
Parsing design file '../rtl/interconnect/arbiter.v'
Parsing design file '../rtl/interconnect/axi_interconnect.v'
Parsing design file '../rtl/interconnect/axi_interconnect_wrap_2x10.v'
Parsing design file '../rtl/interconnect/axi_to_axilite_bridge.v'
Parsing design file '../rtl/interconnect/soc_top.v'
Parsing design file '../tb/tb_soc_top.sv'
Top Level Modules:
       tb_soc_top
TimeScale is 1 ns / 1 ps

Warning-[TFIPC] Too few instance port connections
../tb/tb_soc_top.sv, 123
tb_soc_top, "soc_top u_dut( .clk (clk),  .uart_clk (uart_clk),  .aresetn (aresetn),  .s00_axi_awid (m_awid),  .s00_axi_awaddr (m_awaddr),  .s00_axi_awlen (m_awlen),  .s00_axi_awsize (m_awsize),  .s00_axi_awburst (m_awburst),  .s00_axi_awlock (m_awlock),  .s00_axi_awcache (m_awcache),  .s00_axi_awprot (m_awprot),  .s00_axi_awqos (m_awqos),  .s00_axi_awvalid (m_awvalid),  .s00_axi_awready (m_awready),  .s00_axi_wdata (m_wdata),  .s00_axi_wstrb (m_wstrb),  .s00_axi_wlast (m_wlast),  .s00_axi_wvalid (m_wvalid),  .s00_axi_wready (m_wready),  .s00_axi_bid (m_bid),  .s00_axi_bresp (m_bresp),  .s00_axi_bvalid (m_bvalid),  .s00_axi_bready (m_bready),  .s00_axi_arid (m_arid),  .s00_axi_araddr (m_araddr),  .s00_axi_arlen (m_arlen),  .s00_axi_arsize (m_arsize),  .s00_axi_arburs ... "
  The above instance has fewer port connections than the module definition.
  Please use '+lint=TFIPC-L' to print out detailed information of unconnected 
  ports.


Error-[URMI] Unresolved modules
../rtl/interconnect/soc_top.v, 701
"aes_core_top #(.AXI_ADDR_WIDTH(8)) u_aes( .aclk (clk),  .aresetn (aresetn),  .s_axi_awaddr (aes_awaddr),  .s_axi_awprot (aes_awprot),  .s_axi_awvalid (aes_awvalid),  .s_axi_awready (aes_awready),  .s_axi_wdata (aes_wdata),  .s_axi_wstrb (aes_wstrb),  .s_axi_wvalid (aes_wvalid),  .s_axi_wready (aes_wready),  .s_axi_bresp (aes_bresp),  .s_axi_bvalid (aes_bvalid),  .s_axi_bready (aes_bready),  .s_axi_araddr (aes_araddr),  .s_axi_arprot (aes_arprot),  .s_axi_arvalid (aes_arvalid),  .s_axi_arready (aes_arready),  .s_axi_rdata (aes_rdata),  .s_axi_rresp (aes_rresp),  .s_axi_rvalid (aes_rvalid),  .s_axi_rready (aes_rready),  .irq (aes_irq));"
  Module definition of above instance is not found in the design.

1 warning
1 error

Warning-[KDB-ELAB-E] Verdi KDB elaboration with error
  Verdi KDB elaboration finished with 1 error(s) and 0 warning(s).
  Please look at this Verdi elaboration log file for details. 
  /home/student/1602-23-735-154/project_dir/run/simv.daidir/elabcomLog/compiler.log

CPU time: .179 seconds to compile
Verdi KDB elaboration done and the database successfully generated: 1 error(s), 0 warning(s)
Please look at this Verdi elaboration log file for details: simv.daidir/elabcomLog/compiler.log
[student@vlsi64 run]$ 












