# Placeholder SDC for the descriptor-based AXI4 DMA engine.
# Refine these constraints once the top-level interface, CDC strategy, IO
# environment, and physical timing assumptions are finalized.

create_clock -name cfg_clk -period 20.000 [get_ports cfg_clk]
create_clock -name dma_clk -period 5.000 [get_ports dma_clk]

set_clock_uncertainty 0.500 [get_clocks cfg_clk]
set_clock_uncertainty 0.200 [get_clocks dma_clk]

set_clock_groups -asynchronous \
  -group [get_clocks cfg_clk] \
  -group [get_clocks dma_clk]

set_input_delay 2.000 -clock [get_clocks cfg_clk] \
  [get_ports {s_axil_awvalid s_axil_awaddr[*] s_axil_awprot[*] \
              s_axil_wvalid s_axil_wdata[*] s_axil_wstrb[*] \
              s_axil_bready s_axil_arvalid s_axil_araddr[*] \
              s_axil_arprot[*] s_axil_rready}]
set_output_delay 2.000 -clock [get_clocks cfg_clk] \
  [get_ports {s_axil_awready s_axil_wready s_axil_bvalid s_axil_bresp[*] \
              s_axil_arready s_axil_rvalid s_axil_rdata[*] s_axil_rresp[*]}]

set_input_delay 1.000 -clock [get_clocks dma_clk] \
  [get_ports {m_axi_awready m_axi_wready m_axi_bid[*] m_axi_bresp[*] \
              m_axi_bvalid m_axi_arready m_axi_rid[*] m_axi_rdata[*] \
              m_axi_rresp[*] m_axi_rlast m_axi_rvalid}]
set_output_delay 1.000 -clock [get_clocks dma_clk] \
  [get_ports {m_axi_awid[*] m_axi_awaddr[*] m_axi_awlen[*] m_axi_awsize[*] \
              m_axi_awburst[*] m_axi_awvalid m_axi_wdata[*] m_axi_wstrb[*] \
              m_axi_wlast m_axi_wvalid m_axi_bready m_axi_arid[*] \
              m_axi_araddr[*] m_axi_arlen[*] m_axi_arsize[*] \
              m_axi_arburst[*] m_axi_arvalid m_axi_rready}]

set_false_path -from [get_ports {cfg_rst_n dma_rst_n}]
set_false_path -to [get_ports {cfg_rst_n dma_rst_n}]
