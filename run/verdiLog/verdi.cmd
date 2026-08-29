verdiSetActWin -dock widgetDock_<Message>
simSetSimulator "-vcssv" -exec \
           "/home/student/1602-23-735-154/project_dir/run/simv" -args
debImport "-dbdir" "/home/student/1602-23-735-154/project_dir/run/simv.daidir"
debLoadSimResult /home/student/1602-23-735-154/project_dir/run/dump.fsdb
wvCreateWindow
verdiWindowResize -win $_Verdi_1 "330" "84" "900" "700"
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
srcHBSelect "tb_axi_interconnect" -win $_nTrace1
verdiSetActWin -dock widgetDock_<Inst._Tree>
srcHBSelect "tb_axi_interconnect" -win $_nTrace1
srcSetScope "tb_axi_interconnect" -delim "." -win $_nTrace1
srcHBSelect "tb_axi_interconnect" -win $_nTrace1
srcSignalView -on
verdiSetActWin -dock widgetDock_<Signal_List>
srcSignalViewSelect "tb_axi_interconnect.DATA_WIDTH"
srcSignalViewSelect "tb_axi_interconnect.DATA_WIDTH" \
           "tb_axi_interconnect.ADDR_WIDTH"
srcSignalViewSelect "tb_axi_interconnect.DATA_WIDTH" \
           "tb_axi_interconnect.ADDR_WIDTH" "tb_axi_interconnect.STRB_WIDTH"
srcSignalViewSelect "tb_axi_interconnect.DATA_WIDTH" \
           "tb_axi_interconnect.ADDR_WIDTH" "tb_axi_interconnect.STRB_WIDTH" \
           "tb_axi_interconnect.ID_WIDTH"
srcSignalViewSelect "tb_axi_interconnect.DATA_WIDTH" \
           "tb_axi_interconnect.ADDR_WIDTH" "tb_axi_interconnect.STRB_WIDTH" \
           "tb_axi_interconnect.ID_WIDTH" "tb_axi_interconnect.AWUSER_WIDTH" \
           "tb_axi_interconnect.WUSER_WIDTH"
srcSignalViewSelect "tb_axi_interconnect.DATA_WIDTH" \
           "tb_axi_interconnect.ADDR_WIDTH" "tb_axi_interconnect.STRB_WIDTH" \
           "tb_axi_interconnect.ID_WIDTH" "tb_axi_interconnect.AWUSER_WIDTH" \
           "tb_axi_interconnect.WUSER_WIDTH" "tb_axi_interconnect.BUSER_WIDTH" \
           "tb_axi_interconnect.ARUSER_WIDTH"
srcSignalViewSelect "tb_axi_interconnect.AWUSER_WIDTH"
srcSignalViewSelect "tb_axi_interconnect.STRB_WIDTH"
srcSignalViewSelect "tb_axi_interconnect.clk"
srcSignalViewSelect "tb_axi_interconnect.clk" "tb_axi_interconnect.rst"
wvAddSignal -win $_nWave2 "/tb_axi_interconnect/clk" "/tb_axi_interconnect/rst"
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSetPosition -win $_nWave2 {("G1" 2)}
srcSignalViewSelect "tb_axi_interconnect.AWUSER_WIDTH"
verdiSetActWin -win $_nWave2
srcSignalViewSelect "tb_axi_interconnect.m0_awaddr\[31:0\]"
verdiSetActWin -dock widgetDock_<Signal_List>
srcSignalViewSelect "tb_axi_interconnect.m0_awaddr\[31:0\]" \
           "tb_axi_interconnect.m0_awvalid"
srcSignalViewSelect "tb_axi_interconnect.m0_awaddr\[31:0\]" \
           "tb_axi_interconnect.m0_awvalid" "tb_axi_interconnect.m0_awready"
srcSignalViewSelect "tb_axi_interconnect.m0_awaddr\[31:0\]" \
           "tb_axi_interconnect.m0_awvalid" "tb_axi_interconnect.m0_awready" \
           "tb_axi_interconnect.m0_wdata\[63:0\]"
srcSignalViewSelect "tb_axi_interconnect.m0_awaddr\[31:0\]" \
           "tb_axi_interconnect.m0_awvalid" "tb_axi_interconnect.m0_awready" \
           "tb_axi_interconnect.m0_wdata\[63:0\]" \
           "tb_axi_interconnect.m0_wstrb\[7:0\]"
srcSignalViewSelect "tb_axi_interconnect.m0_awaddr\[31:0\]" \
           "tb_axi_interconnect.m0_awvalid" "tb_axi_interconnect.m0_awready" \
           "tb_axi_interconnect.m0_wdata\[63:0\]" \
           "tb_axi_interconnect.m0_wstrb\[7:0\]" \
           "tb_axi_interconnect.m0_wlast"
srcSignalViewSelect "tb_axi_interconnect.m0_awaddr\[31:0\]" \
           "tb_axi_interconnect.m0_awvalid" "tb_axi_interconnect.m0_awready" \
           "tb_axi_interconnect.m0_wdata\[63:0\]" \
           "tb_axi_interconnect.m0_wstrb\[7:0\]" \
           "tb_axi_interconnect.m0_wlast" "tb_axi_interconnect.m0_wvalid"
srcSignalViewSelect "tb_axi_interconnect.m0_awaddr\[31:0\]" \
           "tb_axi_interconnect.m0_awvalid" "tb_axi_interconnect.m0_awready" \
           "tb_axi_interconnect.m0_wdata\[63:0\]" \
           "tb_axi_interconnect.m0_wstrb\[7:0\]" \
           "tb_axi_interconnect.m0_wlast" "tb_axi_interconnect.m0_wvalid" \
           "tb_axi_interconnect.m0_wready"
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSetPosition -win $_nWave2 {("G2" 0)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSetPosition -win $_nWave2 {("G2" 0)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvAddSignal -win $_nWave2 "/tb_axi_interconnect/m0_awaddr\[31:0\]" \
           "/tb_axi_interconnect/m0_awvalid" "/tb_axi_interconnect/m0_awready" \
           "/tb_axi_interconnect/m0_wdata\[63:0\]" \
           "/tb_axi_interconnect/m0_wstrb\[7:0\]" \
           "/tb_axi_interconnect/m0_wlast" "/tb_axi_interconnect/m0_wvalid" \
           "/tb_axi_interconnect/m0_wready"
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSetPosition -win $_nWave2 {("G1" 10)}
verdiSetActWin -win $_nWave2
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
srcSignalViewSelect "tb_axi_interconnect.m0_bresp\[1:0\]"
verdiSetActWin -dock widgetDock_<Signal_List>
srcSignalViewSelect "tb_axi_interconnect.m0_bresp\[1:0\]" \
           "tb_axi_interconnect.m0_bvalid"
srcSignalViewSelect "tb_axi_interconnect.m0_bresp\[1:0\]" \
           "tb_axi_interconnect.m0_bvalid" "tb_axi_interconnect.m0_bready"
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSetPosition -win $_nWave2 {("G1" 3)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 9)}
wvAddSignal -win $_nWave2 "/tb_axi_interconnect/m0_bresp\[1:0\]" \
           "/tb_axi_interconnect/m0_bvalid" "/tb_axi_interconnect/m0_bready"
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSetPosition -win $_nWave2 {("G1" 12)}
verdiSetActWin -win $_nWave2
wvScrollDown -win $_nWave2 2
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSetPosition -win $_nWave2 {("G1" 11)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 13)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 13)}
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvSelectSignal -win $_nWave2 {( "G1" 11 12 13 )} 
wvSelectGroup -win $_nWave2 {G2}
wvSelectSignal -win $_nWave2 {( "G1" 13 )} 
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]"
verdiSetActWin -dock widgetDock_<Signal_List>
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready"
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 3)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 7)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSetPosition -win $_nWave2 {("G1" 11)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 13)}
wvSetPosition -win $_nWave2 {("G2" 0)}
wvSetPosition -win $_nWave2 {("G1" 13)}
wvAddSignal -win $_nWave2 "/tb_axi_interconnect/m0_araddr\[31:0\]" \
           "/tb_axi_interconnect/m0_arvalid" "/tb_axi_interconnect/m0_arready" \
           "/tb_axi_interconnect/m0_rdata\[63:0\]" \
           "/tb_axi_interconnect/m0_rresp\[1:0\]" \
           "/tb_axi_interconnect/m0_rlast" "/tb_axi_interconnect/m0_rvalid" \
           "/tb_axi_interconnect/m0_rready"
wvSetPosition -win $_nWave2 {("G1" 13)}
wvSetPosition -win $_nWave2 {("G1" 21)}
verdiSetActWin -win $_nWave2
wvScrollDown -win $_nWave2 1
wvZoomAll -win $_nWave2
srcHBSelect "tb_axi_interconnect" -win $_nTrace1
verdiSetActWin -dock widgetDock_<Inst._Tree>
srcHBSelect "tb_axi_interconnect.dut" -win $_nTrace1
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]"
verdiSetActWin -dock widgetDock_<Signal_List>
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid" "tb_axi_interconnect.s0_awready"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid" "tb_axi_interconnect.s0_awready" \
           "tb_axi_interconnect.s0_wdata\[63:0\]"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid" "tb_axi_interconnect.s0_awready" \
           "tb_axi_interconnect.s0_wdata\[63:0\]" \
           "tb_axi_interconnect.s0_wvalid"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid" "tb_axi_interconnect.s0_awready" \
           "tb_axi_interconnect.s0_wdata\[63:0\]" \
           "tb_axi_interconnect.s0_wvalid" "tb_axi_interconnect.s0_wready"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid" "tb_axi_interconnect.s0_awready" \
           "tb_axi_interconnect.s0_wdata\[63:0\]" \
           "tb_axi_interconnect.s0_wvalid" "tb_axi_interconnect.s0_wready" \
           "tb_axi_interconnect.s0_araddr\[31:0\]"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid" "tb_axi_interconnect.s0_awready" \
           "tb_axi_interconnect.s0_wdata\[63:0\]" \
           "tb_axi_interconnect.s0_wvalid" "tb_axi_interconnect.s0_wready" \
           "tb_axi_interconnect.s0_araddr\[31:0\]" \
           "tb_axi_interconnect.s0_arvalid"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid" "tb_axi_interconnect.s0_awready" \
           "tb_axi_interconnect.s0_wdata\[63:0\]" \
           "tb_axi_interconnect.s0_wvalid" "tb_axi_interconnect.s0_wready" \
           "tb_axi_interconnect.s0_araddr\[31:0\]" \
           "tb_axi_interconnect.s0_arvalid" "tb_axi_interconnect.s0_arready"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid" "tb_axi_interconnect.s0_awready" \
           "tb_axi_interconnect.s0_wdata\[63:0\]" \
           "tb_axi_interconnect.s0_wvalid" "tb_axi_interconnect.s0_wready" \
           "tb_axi_interconnect.s0_araddr\[31:0\]" \
           "tb_axi_interconnect.s0_arvalid" "tb_axi_interconnect.s0_arready" \
           "tb_axi_interconnect.s0_rdata\[63:0\]"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid" "tb_axi_interconnect.s0_awready" \
           "tb_axi_interconnect.s0_wdata\[63:0\]" \
           "tb_axi_interconnect.s0_wvalid" "tb_axi_interconnect.s0_wready" \
           "tb_axi_interconnect.s0_araddr\[31:0\]" \
           "tb_axi_interconnect.s0_arvalid" "tb_axi_interconnect.s0_arready" \
           "tb_axi_interconnect.s0_rdata\[63:0\]" \
           "tb_axi_interconnect.s0_rvalid"
srcSignalViewSelect "tb_axi_interconnect.m0_araddr\[31:0\]" \
           "tb_axi_interconnect.m0_arvalid" "tb_axi_interconnect.m0_arready" \
           "tb_axi_interconnect.m0_rdata\[63:0\]" \
           "tb_axi_interconnect.m0_rresp\[1:0\]" \
           "tb_axi_interconnect.m0_rlast" "tb_axi_interconnect.m0_rvalid" \
           "tb_axi_interconnect.m0_rready" \
           "tb_axi_interconnect.s0_awaddr\[31:0\]" \
           "tb_axi_interconnect.s0_awvalid" "tb_axi_interconnect.s0_awready" \
           "tb_axi_interconnect.s0_wdata\[63:0\]" \
           "tb_axi_interconnect.s0_wvalid" "tb_axi_interconnect.s0_wready" \
           "tb_axi_interconnect.s0_araddr\[31:0\]" \
           "tb_axi_interconnect.s0_arvalid" "tb_axi_interconnect.s0_arready" \
           "tb_axi_interconnect.s0_rdata\[63:0\]" \
           "tb_axi_interconnect.s0_rvalid" "tb_axi_interconnect.s0_rready"
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 11)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 14)}
wvSetPosition -win $_nWave2 {("G1" 15)}
wvSetPosition -win $_nWave2 {("G1" 16)}
wvSetPosition -win $_nWave2 {("G1" 17)}
wvSetPosition -win $_nWave2 {("G1" 18)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 21)}
wvSetPosition -win $_nWave2 {("G2" 0)}
wvSetPosition -win $_nWave2 {("G1" 21)}
wvAddSignal -win $_nWave2 "/tb_axi_interconnect/m0_araddr\[31:0\]" \
           "/tb_axi_interconnect/m0_arvalid" "/tb_axi_interconnect/m0_arready" \
           "/tb_axi_interconnect/m0_rdata\[63:0\]" \
           "/tb_axi_interconnect/m0_rresp\[1:0\]" \
           "/tb_axi_interconnect/m0_rlast" "/tb_axi_interconnect/m0_rvalid" \
           "/tb_axi_interconnect/m0_rready" \
           "/tb_axi_interconnect/s0_awaddr\[31:0\]" \
           "/tb_axi_interconnect/s0_awvalid" "/tb_axi_interconnect/s0_awready" \
           "/tb_axi_interconnect/s0_wdata\[63:0\]" \
           "/tb_axi_interconnect/s0_wvalid" "/tb_axi_interconnect/s0_wready" \
           "/tb_axi_interconnect/s0_araddr\[31:0\]" \
           "/tb_axi_interconnect/s0_arvalid" "/tb_axi_interconnect/s0_arready" \
           "/tb_axi_interconnect/s0_rdata\[63:0\]" \
           "/tb_axi_interconnect/s0_rvalid" "/tb_axi_interconnect/s0_rready"
wvSetPosition -win $_nWave2 {("G1" 21)}
wvSetPosition -win $_nWave2 {("G1" 41)}
srcSignalViewSetFilter "slave"
srcSignalView -off
verdiDockWidgetMaximize -dock windowDock_nWave_2
verdiSetActWin -win $_nWave2
wvZoomAll -win $_nWave2
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvSetCursor -win $_nWave2 243385.628105 -snap {("G1" 13)}
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvSelectSignal -win $_nWave2 {( "G1" 22 23 24 25 26 27 28 29 30 31 32 33 34 35 \
           36 37 38 39 40 41 )} 
wvSelectSignal -win $_nWave2 {( "G1" 22 23 24 25 26 27 28 29 30 31 32 33 34 35 \
           36 37 38 39 40 41 )} 
wvSelectSignal -win $_nWave2 {( "G1" 22 23 24 25 26 27 28 29 30 31 32 33 34 35 \
           36 37 38 39 40 41 )} 
wvSelectSignal -win $_nWave2 {( "G1" 41 )} 
wvSelectSignal -win $_nWave2 {( "G1" 41 )} 
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvZoomAll -win $_nWave2
wvScrollDown -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 3
wvScrollUp -win $_nWave2 4
wvScrollUp -win $_nWave2 2
wvScrollUp -win $_nWave2 4
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvSelectSignal -win $_nWave2 {( "G1" 29 )} 
wvSelectSignal -win $_nWave2 {( "G1" 22 23 24 25 26 27 28 29 )} 
wvCut -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 33)}
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvZoomAll -win $_nWave2
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
schCreateWindow -delim "." -win $_nSchema1 -scope "tb_axi_interconnect"
verdiDockWidgetSetCurTab -dock windowDock_nSchema_3
verdiSetActWin -win $_nSchema_3
schSelect -win $_nSchema3 -inst "dut"
schZoomOut -win $_nSchema3 -pos 153526 335395
schZoomOut -win $_nSchema3 -pos 153526 335394
schZoomIn -win $_nSchema3 -pos 150442 328106
schZoomIn -win $_nSchema3 -pos 150442 328106
schZoomIn -win $_nSchema3 -pos 150441 328107
schZoomIn -win $_nSchema3 -pos 150441 328106
schZoomIn -win $_nSchema3 -pos 150441 328106
schZoomIn -win $_nSchema3 -pos 150440 328106
schZoomIn -win $_nSchema3 -pos 150440 328105
schZoomOut -win $_nSchema3 -pos 100218 326021
schZoomOut -win $_nSchema3 -pos 100219 326021
schZoomOut -win $_nSchema3 -pos 100218 326020
schZoomOut -win $_nSchema3 -pos 100219 326019
schZoomOut -win $_nSchema3 -pos 101894 326697
schZoomOut -win $_nSchema3 -pos 101894 326697
schZoomOut -win $_nSchema3 -pos 101894 326697
schZoomOut -win $_nSchema3 -pos 101894 326697
schZoomOut -win $_nSchema3 -pos 101894 326698
schZoomOut -win $_nSchema3 -pos 101895 326698
schZoomIn -win $_nSchema3 -pos -335150 388822
schZoomIn -win $_nSchema3 -pos -335150 388822
schZoomOut -win $_nSchema3
schSelect -win $_nSchema3 -inst "dut"
schFit -win $_nSchema3
schFit -win $_nSchema3
schFit -win $_nSchema3
schFit -win $_nSchema3
schZoomIn -win $_nSchema3 -pos 21292 262101
schZoomIn -win $_nSchema3 -pos 21292 262601
schZoomIn -win $_nSchema3 -pos 21291 262600
schZoomIn -win $_nSchema3 -pos 54041 259789
schZoomIn -win $_nSchema3 -pos 54456 260000
schZoomIn -win $_nSchema3 -pos 54613 259999
schZoomIn -win $_nSchema3 -pos 54612 259999
schZoomIn -win $_nSchema3 -pos 54963 259198
schZoomIn -win $_nSchema3 -pos 55226 258798
schZoomIn -win $_nSchema3 -pos 56758 260999
schZoomIn -win $_nSchema3 -pos 56721 260999
schZoomIn -win $_nSchema3 -pos 56720 260999
schZoomOut -win $_nSchema3 -pos 56720 260999
schZoomOut -win $_nSchema3 -pos 56720 260999
schZoomOut -win $_nSchema3 -pos 56720 260998
schZoomOut -win $_nSchema3 -pos 56720 260997
schZoomOut -win $_nSchema3 -pos 56720 260997
schZoomOut -win $_nSchema3 -pos 56719 260996
schZoomOut -win $_nSchema3 -pos 56720 260995
schZoomOut -win $_nSchema3 -pos 56720 260995
schZoomOut -win $_nSchema3 -pos 56719 260994
schZoomOut -win $_nSchema3 -pos 56719 260994
schZoomOut -win $_nSchema3 -pos 56719 260995
schZoomOut -win $_nSchema3 -pos 56719 260995
schZoomOut -win $_nSchema3 -pos 56719 260995
schZoomOut -win $_nSchema3 -pos 56719 260995
schZoomOut -win $_nSchema3 -pos 47243 252356
schZoomOut -win $_nSchema3 -pos 47242 251756
schZoomOut -win $_nSchema3 -pos 47243 251756
schZoomOut -win $_nSchema3 -pos 47242 251755
schZoomIn -win $_nSchema3 -pos 273967 256441
schZoomIn -win $_nSchema3 -pos 274835 257320
verdiDockWidgetSetCurTab -dock windowDock_nWave_2
verdiSetActWin -win $_nWave2
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
srcSignalView -on
srcSignalView -off
srcSignalView -on
verdiDockWidgetRestore -dock windowDock_nWave_2
verdiSetActWin -win $_nSchema_3
srcSignalView -off
verdiDockWidgetMaximize -dock windowDock_nWave_2
verdiSetActWin -win $_nWave2
srcSignalView -on
srcSignalView -off
srcSignalView -on
verdiWindowBeWindow -win $_nWave2
wvResizeWindow -win $_nWave2 -10 19 1600 326
wvResizeWindow -win $_nWave2 -10 19 1600 836
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvResizeWindow -win $_nWave2 -10 17 1600 326
wvResizeWindow -win $_nWave2 -10 19 1600 836
