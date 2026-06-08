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
VERSION = 0x24
VERSION_VALUE = 0x00010000


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


async def reset_dut(dut):
    _set_axil_idle(dut)
    dut.busy_i.value = 0
    dut.done_set_i.value = 0
    dut.error_set_i.value = 0
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


@cocotb.test()
async def register_read_write_and_status_clear(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    assert await axil_write(dut, SRC_ADDR_LO, 0x11223344) == 0
    assert await axil_write(dut, SRC_ADDR_HI, 0x00000001) == 0
    assert await axil_write(dut, DST_ADDR_LO, 0x55667788) == 0
    assert await axil_write(dut, DST_ADDR_HI, 0x00000002) == 0
    assert await axil_write(dut, LEN_BYTES, 0x40) == 0
    assert await axil_write(dut, IRQ_ENABLE, 0x3) == 0

    for addr, expected in (
        (SRC_ADDR_LO, 0x11223344),
        (SRC_ADDR_HI, 0x00000001),
        (DST_ADDR_LO, 0x55667788),
        (DST_ADDR_HI, 0x00000002),
        (LEN_BYTES, 0x40),
        (IRQ_ENABLE, 0x3),
    ):
        data, resp = await axil_read(dut, addr)
        assert resp == 0
        assert data == expected

    assert await axil_write(dut, VERSION, 0xDEADBEEF) == 0
    data, resp = await axil_read(dut, VERSION)
    assert resp == 0
    assert data == VERSION_VALUE

    dut.busy_i.value = 1
    data, _ = await axil_read(dut, STATUS)
    assert data & 0x1
    dut.busy_i.value = 0

    dut.done_set_i.value = 1
    dut.error_set_i.value = 1
    await RisingEdge(dut.clk)
    dut.done_set_i.value = 0
    dut.error_set_i.value = 0
    await RisingEdge(dut.clk)

    data, resp = await axil_read(dut, STATUS)
    assert resp == 0
    assert (data & 0x6) == 0x6
    data, resp = await axil_read(dut, IRQ_STATUS)
    assert resp == 0
    assert (data & 0x3) == 0x3
    assert int(dut.irq_o.value) == 1

    assert await axil_write(dut, STATUS, 0x6) == 0
    assert await axil_write(dut, IRQ_STATUS, 0x3) == 0
    data, _ = await axil_read(dut, STATUS)
    assert (data & 0x6) == 0
    data, _ = await axil_read(dut, IRQ_STATUS)
    assert (data & 0x3) == 0
    assert int(dut.irq_o.value) == 0


@cocotb.test()
async def ctrl_write_generates_pulses(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    assert int(dut.start_pulse_o.value) == 0
    assert int(dut.soft_reset_pulse_o.value) == 0
    assert await axil_write(dut, CTRL, 0x3) == 0

    saw_start = False
    saw_reset = False
    for _ in range(4):
        await RisingEdge(dut.clk)
        saw_start |= bool(int(dut.start_pulse_o.value))
        saw_reset |= bool(int(dut.soft_reset_pulse_o.value))

    assert saw_start
    assert saw_reset
