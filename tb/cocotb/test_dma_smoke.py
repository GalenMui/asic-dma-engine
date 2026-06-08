import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


CTRL = 0x00
STATUS = 0x04
SRC_ADDR_LO = 0x08
SRC_ADDR_HI = 0x0C
DST_ADDR_LO = 0x10
DST_ADDR_HI = 0x14
LEN_BYTES = 0x18
IRQ_ENABLE = 0x1C
IRQ_STATUS = 0x20


def _set_axil_idle(dut):
    dut.s_axil_awaddr.value = 0
    dut.s_axil_awprot.value = 0
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wdata.value = 0
    dut.s_axil_wstrb.value = 0
    dut.s_axil_wvalid.value = 0
    dut.s_axil_bready.value = 0
    dut.s_axil_araddr.value = 0
    dut.s_axil_arprot.value = 0
    dut.s_axil_arvalid.value = 0
    dut.s_axil_rready.value = 0


def _set_axi_memory_idle(dut):
    dut.m_axi_awready.value = 0
    dut.m_axi_wready.value = 0
    dut.m_axi_bid.value = 0
    dut.m_axi_bresp.value = 0
    dut.m_axi_bvalid.value = 0
    dut.m_axi_arready.value = 0
    dut.m_axi_rid.value = 0
    dut.m_axi_rdata.value = 0
    dut.m_axi_rresp.value = 0
    dut.m_axi_rlast.value = 0
    dut.m_axi_rvalid.value = 0


async def reset_dut(dut):
    _set_axil_idle(dut)
    _set_axi_memory_idle(dut)
    dut.rst_n.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)


async def axil_write(dut, addr, data, strb=0xF):
    dut.s_axil_awaddr.value = addr
    dut.s_axil_awprot.value = 0
    dut.s_axil_awvalid.value = 1
    dut.s_axil_wdata.value = data
    dut.s_axil_wstrb.value = strb
    dut.s_axil_wvalid.value = 1
    dut.s_axil_bready.value = 1

    aw_done = False
    w_done = False
    while not (aw_done and w_done):
        await RisingEdge(dut.clk)
        if not aw_done and int(dut.s_axil_awready.value):
            aw_done = True
            dut.s_axil_awvalid.value = 0
        if not w_done and int(dut.s_axil_wready.value):
            w_done = True
            dut.s_axil_wvalid.value = 0

    while True:
        await RisingEdge(dut.clk)
        if int(dut.s_axil_bvalid.value):
            resp = int(dut.s_axil_bresp.value)
            break

    dut.s_axil_bready.value = 0
    await RisingEdge(dut.clk)
    return resp


async def axil_read(dut, addr):
    dut.s_axil_araddr.value = addr
    dut.s_axil_arprot.value = 0
    dut.s_axil_arvalid.value = 1
    dut.s_axil_rready.value = 1

    while True:
        await RisingEdge(dut.clk)
        if int(dut.s_axil_arready.value):
            dut.s_axil_arvalid.value = 0
            break

    while True:
        await RisingEdge(dut.clk)
        if int(dut.s_axil_rvalid.value):
            data = int(dut.s_axil_rdata.value)
            resp = int(dut.s_axil_rresp.value)
            break

    dut.s_axil_rready.value = 0
    await RisingEdge(dut.clk)
    return data, resp


async def wait_for_status_bit(dut, mask, expected=True, timeout_cycles=200):
    for _ in range(timeout_cycles):
        data, resp = await axil_read(dut, STATUS)
        assert resp == 0
        if bool(data & mask) == expected:
            return data
        await RisingEdge(dut.clk)
    raise AssertionError(f"Timed out waiting for STATUS mask 0x{mask:x}")


def _apply_wstrb(old_value, new_value, strb):
    value = old_value
    for byte_idx in range(4):
        if strb & (1 << byte_idx):
            mask = 0xFF << (8 * byte_idx)
            value = (value & ~mask) | (new_value & mask)
    return value & 0xFFFFFFFF


async def axi_memory_model(dut, memory):
    pending_aw = None

    dut.m_axi_arready.value = 1
    dut.m_axi_awready.value = 1
    dut.m_axi_wready.value = 1
    dut.m_axi_rvalid.value = 0
    dut.m_axi_bvalid.value = 0
    dut.m_axi_rresp.value = 0
    dut.m_axi_bresp.value = 0
    dut.m_axi_rlast.value = 1
    dut.m_axi_rid.value = 0
    dut.m_axi_bid.value = 0

    while True:
        await RisingEdge(dut.clk)

        if not int(dut.rst_n.value):
            pending_aw = None
            dut.m_axi_arready.value = 1
            dut.m_axi_awready.value = 1
            dut.m_axi_wready.value = 1
            dut.m_axi_rvalid.value = 0
            dut.m_axi_bvalid.value = 0
            continue

        if int(dut.m_axi_rvalid.value) and int(dut.m_axi_rready.value):
            dut.m_axi_rvalid.value = 0

        if int(dut.m_axi_bvalid.value) and int(dut.m_axi_bready.value):
            dut.m_axi_bvalid.value = 0

        if (
            int(dut.m_axi_arvalid.value)
            and int(dut.m_axi_arready.value)
            and not int(dut.m_axi_rvalid.value)
        ):
            addr = int(dut.m_axi_araddr.value)
            dut.m_axi_rdata.value = memory.get(addr, 0)
            dut.m_axi_rresp.value = 0
            dut.m_axi_rlast.value = 1
            dut.m_axi_rvalid.value = 1

        if int(dut.m_axi_awvalid.value) and int(dut.m_axi_awready.value):
            pending_aw = int(dut.m_axi_awaddr.value)

        if (
            pending_aw is not None
            and int(dut.m_axi_wvalid.value)
            and int(dut.m_axi_wready.value)
            and not int(dut.m_axi_bvalid.value)
        ):
            old_value = memory.get(pending_aw, 0)
            new_value = int(dut.m_axi_wdata.value)
            strb = int(dut.m_axi_wstrb.value)
            memory[pending_aw] = _apply_wstrb(old_value, new_value, strb)
            pending_aw = None
            dut.m_axi_bresp.value = 0
            dut.m_axi_bvalid.value = 1


async def program_transfer(dut, src, dst, length):
    assert await axil_write(dut, SRC_ADDR_LO, src & 0xFFFFFFFF) == 0
    assert await axil_write(dut, SRC_ADDR_HI, src >> 32) == 0
    assert await axil_write(dut, DST_ADDR_LO, dst & 0xFFFFFFFF) == 0
    assert await axil_write(dut, DST_ADDR_HI, dst >> 32) == 0
    assert await axil_write(dut, LEN_BYTES, length) == 0


@cocotb.test()
async def dma_memory_to_memory_smoke(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    memory = {
        0x1000: 0x11223344,
        0x1004: 0x55667788,
        0x1008: 0xA5A55A5A,
        0x100C: 0xDEADBEEF,
    }
    cocotb.start_soon(axi_memory_model(dut, memory))
    await reset_dut(dut)

    await program_transfer(dut, 0x1000, 0x2000, 16)
    assert await axil_write(dut, IRQ_ENABLE, 0x1) == 0
    assert await axil_write(dut, CTRL, 0x1) == 0

    await wait_for_status_bit(dut, 0x1, expected=True)
    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0

    for offset in range(0, 16, 4):
        assert memory[0x2000 + offset] == memory[0x1000 + offset]

    irq_status, resp = await axil_read(dut, IRQ_STATUS)
    assert resp == 0
    assert (irq_status & 0x1) == 0x1
    assert int(dut.irq.value) == 1

    assert await axil_write(dut, STATUS, 0x2) == 0
    assert await axil_write(dut, IRQ_STATUS, 0x1) == 0
    status, _ = await axil_read(dut, STATUS)
    assert (status & 0x2) == 0
    assert int(dut.irq.value) == 0


@cocotb.test()
async def dma_unaligned_address_sets_error(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    memory = {}
    cocotb.start_soon(axi_memory_model(dut, memory))
    await reset_dut(dut)

    await program_transfer(dut, 0x1002, 0x2000, 16)
    assert await axil_write(dut, IRQ_ENABLE, 0x2) == 0
    assert await axil_write(dut, CTRL, 0x1) == 0

    data = await wait_for_status_bit(dut, 0x4, expected=True)
    assert (data & 0x2) == 0
    assert (data & 0x1) == 0

    irq_status, resp = await axil_read(dut, IRQ_STATUS)
    assert resp == 0
    assert (irq_status & 0x2) == 0x2
    assert int(dut.irq.value) == 1
