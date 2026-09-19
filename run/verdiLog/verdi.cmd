simSetSimulator "-vcssv" -exec \
           "/home/student/1602-23-735-154/project_dir/run/simv" -args
debImport "-dbdir" "/home/student/1602-23-735-154/project_dir/run/simv.daidir"
debLoadSimResult /home/student/1602-23-735-154/project_dir/run/dump.fsdb
wvCreateWindow
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
srcSignalViewSelect "tb_soc_top.uart_clk"
verdiSetActWin -dock widgetDock_<Signal_List>
srcSignalViewSelectAll -curPage
wvAddSignal -win $_nWave2 "tb_soc_top/CLK_PERIOD"
wvAddSignal -win $_nWave2 "tb_soc_top/BAUD_DIV"
wvAddSignal -win $_nWave2 "tb_soc_top/UART_BASE\[31:0\]"
wvAddSignal -win $_nWave2 "tb_soc_top/UART_THR\[31:0\]"
wvAddSignal -win $_nWave2 "tb_soc_top/UART_IER\[31:0\]"
wvAddSignal -win $_nWave2 "tb_soc_top/UART_BAUD_DIV\[31:0\]"
wvAddSignal -win $_nWave2 "tb_soc_top/UART_LCR\[31:0\]"
wvAddSignal -win $_nWave2 "tb_soc_top/UART_LSR\[31:0\]"
wvAddSignal -win $_nWave2 "tb_soc_top/RX_SETTLE_CLKS"
wvAddSignal -win $_nWave2 "/tb_soc_top/clk" "/tb_soc_top/uart_clk" \
           "/tb_soc_top/aresetn" "/tb_soc_top/m_awid\[7:0\]" \
           "/tb_soc_top/m_awaddr\[31:0\]" "/tb_soc_top/m_awlen\[7:0\]" \
           "/tb_soc_top/m_awsize\[2:0\]" "/tb_soc_top/m_awburst\[1:0\]" \
           "/tb_soc_top/m_awlock" "/tb_soc_top/m_awcache\[3:0\]" \
           "/tb_soc_top/m_awprot\[2:0\]" "/tb_soc_top/m_awqos\[3:0\]" \
           "/tb_soc_top/m_awvalid" "/tb_soc_top/m_awready" \
           "/tb_soc_top/m_wdata\[31:0\]" "/tb_soc_top/m_wstrb\[3:0\]" \
           "/tb_soc_top/m_wlast" "/tb_soc_top/m_wvalid" "/tb_soc_top/m_wready" \
           "/tb_soc_top/m_bid\[7:0\]" "/tb_soc_top/m_bresp\[1:0\]" \
           "/tb_soc_top/m_bvalid" "/tb_soc_top/m_bready" \
           "/tb_soc_top/m_arid\[7:0\]" "/tb_soc_top/m_araddr\[31:0\]" \
           "/tb_soc_top/m_arlen\[7:0\]" "/tb_soc_top/m_arsize\[2:0\]" \
           "/tb_soc_top/m_arburst\[1:0\]" "/tb_soc_top/m_arlock" \
           "/tb_soc_top/m_arcache\[3:0\]" "/tb_soc_top/m_arprot\[2:0\]" \
           "/tb_soc_top/m_arqos\[3:0\]" "/tb_soc_top/m_arvalid" \
           "/tb_soc_top/m_arready" "/tb_soc_top/m_rid\[7:0\]" \
           "/tb_soc_top/m_rdata\[31:0\]" "/tb_soc_top/m_rresp\[1:0\]" \
           "/tb_soc_top/m_rlast" "/tb_soc_top/m_rvalid" "/tb_soc_top/m_rready" \
           "/tb_soc_top/uart_tx" "/tb_soc_top/uart_rx" "/tb_soc_top/uart_irq" \
           "/tb_soc_top/pass_cnt\[31:0\]" "/tb_soc_top/fail_cnt\[31:0\]" \
           "/tb_soc_top/rd_data\[31:0\]" "/tb_soc_top/rx_cap\[7:0\]"
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 47)}
wvSetPosition -win $_nWave2 {("G1" 47)}
srcSignalView -off
verdiDockWidgetMaximize -dock windowDock_nWave_2
verdiSetActWin -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvSelectSignal -win $_nWave2 {( "G1" 25 )} 
wvScrollUp -win $_nWave2 1
wvSelectSignal -win $_nWave2 {( "G1" 34 )} 
wvSelectSignal -win $_nWave2 {( "G1" 33 )} 
debExit
