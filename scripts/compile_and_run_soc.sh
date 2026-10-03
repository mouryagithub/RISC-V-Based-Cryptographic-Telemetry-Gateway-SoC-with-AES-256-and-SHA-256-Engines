#!/usr/bin/env bash
# ==============================================================================
# Script: compile_and_run_soc.sh
# Description: VCS compilation and simulation script for the integrated SoC top
#              with 2 Masters (VeeR2 CPU & AXI DMA) and 5 Slaves (UART, GPIO,
#              Timer, AES-256, SHA-256) through the 2x5 AXI Crossbar.
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOC_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_DIR="${SOC_ROOT}/project_dir"

export VCS_HOME="/home/student/snps_tools_target/vcs/U-2023.03"
export PATH="$VCS_HOME/bin:$PATH"
export SNPSLMD_LICENSE_FILE="27021@14.139.1.126"

cd "${SOC_ROOT}"

echo "================================================================="
echo " Compiling SoC with Synopsys VCS (U-2023.03_Full64)..."
echo "================================================================="

vcs -full64 -sverilog +v2k \
    +incdir+project_dir/rtl/dma/inc \
    +incdir+project_dir/rtl/dma \
    +incdir+project_dir/rtl/uart \
    +incdir+project_dir/rtl/aes \
    project_dir/rtl/interconnect/priority_encoder.v \
    project_dir/rtl/interconnect/arbiter.v \
    project_dir/rtl/interconnect/axi_interconnect.v \
    project_dir/rtl/interconnect/axi_interconnect_wrap_2x5.v \
    project_dir/rtl/interconnect/axi_to_axilite_bridge.v \
    project_dir/rtl/dma/inc/amba_axi_pkg.sv \
    project_dir/rtl/dma/inc/dma_utils_pkg.sv \
    project_dir/rtl/dma/rggen_mux.v \
    project_dir/rtl/dma/rggen_adapter_common.v \
    project_dir/rtl/dma/rggen_address_decoder.v \
    project_dir/rtl/dma/rggen_axi4lite_adapter.v \
    project_dir/rtl/dma/rggen_axi4lite_skid_buffer.v \
    project_dir/rtl/dma/rggen_bit_field.v \
    project_dir/rtl/dma/rggen_default_register.v \
    project_dir/rtl/dma/rggen_or_reducer.v \
    project_dir/rtl/dma/rggen_register_common.v \
    project_dir/rtl/dma/csr_dma.v \
    project_dir/rtl/dma/dma_fifo.sv \
    project_dir/rtl/dma/dma_fsm.sv \
    project_dir/rtl/dma/dma_streamer.sv \
    project_dir/rtl/dma/dma_axi_if.sv \
    project_dir/rtl/dma/dma_func_wrapper.sv \
    project_dir/rtl/dma/dma_axi_wrapper.sv \
    project_dir/rtl/dma/dma_axi_top.sv \
    project_dir/rtl/aes/aes_sbox.v \
    project_dir/rtl/aes/aes_inv_sbox.v \
    project_dir/rtl/aes/aes_rcon.v \
    project_dir/rtl/aes/aes_key_expand_128.v \
    project_dir/rtl/aes/aes_key_expand_256.v \
    project_dir/rtl/aes/aes_cipher_top.v \
    project_dir/rtl/aes/aes_inv_cipher_top.v \
    project_dir/rtl/aes/aes_regfile.v \
    project_dir/rtl/aes/aes_core_top.v \
    project_dir/rtl/uart/uart_parity_bit_compute.v \
    project_dir/rtl/uart/axi_internal_fifo.v \
    project_dir/rtl/uart/uart_receiver.v \
    project_dir/rtl/uart/uart_transmitter.v \
    project_dir/rtl/uart/uart_controller.v \
    project_dir/rtl/uart/axi_uart_top.v \
    project_dir/rtl/timer/timer_core.sv \
    project_dir/rtl/timer/axi_timer_top.v \
    project_dir/rtl/gpio/axi_gpio_top.v \
    project_dir/rtl/sha/sha256_k_constants.v \
    project_dir/rtl/sha/sha256_w_mem.v \
    project_dir/rtl/sha/sha256_core.v \
    project_dir/rtl/sha/sha256.v \
    project_dir/rtl/sha/axi_sha256_top.v \
    project_dir/rtl/interconnect/soc_top.v \
    project_dir/tb/tb_soc_top.sv \
    -o simv_soc

echo "================================================================="
echo " Running SoC Simulation..."
echo "================================================================="
./simv_soc
