import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


# register offsets stay local to the test so each bus access reads like software
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
DESC_BASE_LO = 0x28
DESC_BASE_HI = 0x2C
DESC_COUNT = 0x30
MODE = 0x34
DESC_INDEX = 0x38
ERROR_CAUSE = 0x3C
BYTES_REMAINING = 0x40
ACTIVE_SRC_LO = 0x44
ACTIVE_DST_LO = 0x48
COMPLETED_DESC_COUNT = 0x4C
COMPLETED_BYTE_COUNT_LO = 0x50
VERSION_VALUE = 0x00080005


def _set_axil_idle(dut):
    # put every master-driven channel in a quiet known state before reset
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
    # clear both the bus and the core-facing status inputs before releasing reset
    _set_axil_idle(dut)
    dut.busy_i.value = 0
    dut.done_set_i.value = 0
    dut.single_done_set_i.value = 0
    dut.desc_done_set_i.value = 0
    dut.desc_list_done_set_i.value = 0
    dut.error_set_i.value = 0
    dut.desc_active_i.value = 0
    dut.desc_index_i.value = 0
    dut.error_cause_i.value = 0
    dut.bytes_remaining_i.value = 0
    dut.active_src_addr_i.value = 0
    dut.active_dst_addr_i.value = 0
    dut.completed_desc_count_i.value = 0
    dut.completed_byte_count_lo_i.value = 0
    dut.rst_n.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)


async def axil_write(dut, addr, data, strb=0xF):
    # launch address and data together but retire them independently like axi-lite allows
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
        # keep bready up until the slave returns the one write response
        await RisingEdge(dut.clk)
        if int(dut.s_axil_bvalid.value):
            resp = int(dut.s_axil_bresp.value)
            break

    dut.s_axil_bready.value = 0
    await RisingEdge(dut.clk)
    return resp


async def axil_read(dut, addr):
    # hold the read address until accepted, then wait for the matching response
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
    # cover normal storage, live status, read-only values, w1c bits, and bad offsets
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    assert await axil_write(dut, SRC_ADDR_LO, 0x11223344) == 0
    assert await axil_write(dut, SRC_ADDR_HI, 0x00000001) == 0
    assert await axil_write(dut, DST_ADDR_LO, 0x55667788) == 0
    assert await axil_write(dut, DST_ADDR_HI, 0x00000002) == 0
    assert await axil_write(dut, LEN_BYTES, 0x40) == 0
    assert await axil_write(dut, IRQ_ENABLE, 0xF) == 0
    assert await axil_write(dut, DESC_BASE_LO, 0x00004000) == 0
    assert await axil_write(dut, DESC_BASE_HI, 0x00000003) == 0
    assert await axil_write(dut, DESC_COUNT, 0x5) == 0
    assert await axil_write(dut, MODE, 0x1) == 0

    for addr, expected in (
        (SRC_ADDR_LO, 0x11223344),
        (SRC_ADDR_HI, 0x00000001),
        (DST_ADDR_LO, 0x55667788),
        (DST_ADDR_HI, 0x00000002),
        (LEN_BYTES, 0x40),
        (IRQ_ENABLE, 0xF),
        (DESC_BASE_LO, 0x00004000),
        (DESC_BASE_HI, 0x00000003),
        (DESC_COUNT, 0x5),
        (MODE, 0x1),
    ):
        # read every programmed value back instead of trusting the write response alone
        data, resp = await axil_read(dut, addr)
        assert resp == 0
        assert data == expected

    dut.desc_index_i.value = 0x2
    dut.error_cause_i.value = 0x6
    dut.bytes_remaining_i.value = 0x24
    dut.active_src_addr_i.value = 0x123456789
    dut.active_dst_addr_i.value = 0xABCDEF012
    dut.completed_desc_count_i.value = 0x3
    dut.completed_byte_count_lo_i.value = 0x80
    # these registers are direct windows into the core-facing observability inputs
    data, resp = await axil_read(dut, DESC_INDEX)
    assert resp == 0
    assert data == 0x2
    data, resp = await axil_read(dut, ERROR_CAUSE)
    assert resp == 0
    assert data == 0x6
    for addr, expected in (
        (BYTES_REMAINING, 0x24),
        (ACTIVE_SRC_LO, 0x23456789),
        (ACTIVE_DST_LO, 0xBCDEF012),
        (COMPLETED_DESC_COUNT, 0x3),
        (COMPLETED_BYTE_COUNT_LO, 0x80),
    ):
        data, resp = await axil_read(dut, addr)
        assert resp == 0
        assert data == expected

    assert await axil_write(dut, VERSION, 0xDEADBEEF) == 0
    # writes are accepted but the constant version value must not move
    data, resp = await axil_read(dut, VERSION)
    assert resp == 0
    assert data == VERSION_VALUE

    dut.busy_i.value = 1
    dut.desc_active_i.value = 1
    data, _ = await axil_read(dut, STATUS)
    assert (data & 0x9) == 0x9
    dut.busy_i.value = 0
    dut.desc_active_i.value = 0

    dut.done_set_i.value = 1
    dut.single_done_set_i.value = 1
    dut.desc_done_set_i.value = 1
    dut.desc_list_done_set_i.value = 1
    dut.error_set_i.value = 1
    await RisingEdge(dut.clk)
    dut.done_set_i.value = 0
    dut.single_done_set_i.value = 0
    dut.desc_done_set_i.value = 0
    dut.desc_list_done_set_i.value = 0
    dut.error_set_i.value = 0
    await RisingEdge(dut.clk)

    # event inputs should stick in status and irq state after their pulses disappear
    data, resp = await axil_read(dut, STATUS)
    assert resp == 0
    assert (data & 0x6) == 0x6
    data, resp = await axil_read(dut, IRQ_STATUS)
    assert resp == 0
    assert (data & 0xF) == 0xF
    assert int(dut.irq_o.value) == 1

    assert await axil_write(dut, STATUS, 0x0) == 0
    assert await axil_write(dut, IRQ_STATUS, 0x0) == 0
    data, _ = await axil_read(dut, STATUS)
    assert (data & 0x6) == 0x6
    data, _ = await axil_read(dut, IRQ_STATUS)
    assert (data & 0xF) == 0xF

    # write-one-to-clear means zeros do nothing and ones clear only their matching bits
    assert await axil_write(dut, STATUS, 0x6) == 0
    assert await axil_write(dut, IRQ_STATUS, 0xF) == 0
    data, _ = await axil_read(dut, STATUS)
    assert (data & 0x6) == 0
    data, _ = await axil_read(dut, IRQ_STATUS)
    assert (data & 0xF) == 0
    assert int(dut.irq_o.value) == 0

    _, resp = await axil_read(dut, 0x100)
    assert resp == 2
    assert await axil_write(dut, 0x100, 0x1) == 2


@cocotb.test()
async def ctrl_write_generates_pulses(dut):
    # ctrl bits should become short output pulses, never stored register state
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
