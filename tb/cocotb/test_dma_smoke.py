import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random


# csr offsets match the software view used to program and inspect the dma
CTRL = 0x00
STATUS = 0x04
SRC_ADDR_LO = 0x08
SRC_ADDR_HI = 0x0C
DST_ADDR_LO = 0x10
DST_ADDR_HI = 0x14
LEN_BYTES = 0x18
IRQ_ENABLE = 0x1C
IRQ_STATUS = 0x20
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
DATA_BYTES = 4
MAX_BURST_BEATS = 16

# error values are repeated here so failures can check the exact public cause
ERROR_CAUSE_ZERO_LEN = 0x1
ERROR_CAUSE_SRC_UNALIGNED = 0x2
ERROR_CAUSE_DST_UNALIGNED = 0x3
ERROR_CAUSE_LEN_UNALIGNED = 0x4
ERROR_CAUSE_DESC_BASE_UNALIGNED = 0x5
ERROR_CAUSE_DESC_COUNT_ZERO = 0x6
ERROR_CAUSE_DESC_INVALID = 0x7
ERROR_CAUSE_AXI_READ = 0x8
ERROR_CAUSE_AXI_WRITE = 0x9
ERROR_CAUSE_DESC_WRITEBACK = 0xB
ERROR_CAUSE_DESC_MODE_UNSUPPORTED = 0xD
ERROR_CAUSE_TILE_ROW_BYTES_ZERO = 0xE
ERROR_CAUSE_TILE_ROW_COUNT_ZERO = 0xF
ERROR_CAUSE_TILE_SRC_STRIDE = 0x10
ERROR_CAUSE_TILE_DST_STRIDE = 0x11

DESC_MODE_LINEAR = 0
DESC_MODE_2D = 1


def start_clocks(dut):
    # unrelated clock periods make the top-level cdc paths do real work in every test
    cocotb.start_soon(Clock(dut.cfg_clk, 10, units="ns").start())
    cocotb.start_soon(Clock(dut.dma_clk, 7, units="ns").start())


def _set_axil_idle(dut):
    # keep the configuration master quiet until a helper starts a transaction
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
    # memory-side inputs start inactive so reset cannot accidentally handshake
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
    # both domains reset together here, then the different clocks release them naturally
    _set_axil_idle(dut)
    _set_axi_memory_idle(dut)
    dut.cfg_rst_n.value = 0
    dut.dma_rst_n.value = 0
    for _ in range(5):
        await RisingEdge(dut.cfg_clk)
    dut.cfg_rst_n.value = 1
    dut.dma_rst_n.value = 1
    for _ in range(2):
        await RisingEdge(dut.cfg_clk)


async def axil_write(dut, addr, data, strb=0xF):
    # address and data are tracked separately since either channel may win first
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
        await RisingEdge(dut.cfg_clk)
        if not aw_done and int(dut.s_axil_awready.value):
            aw_done = True
            dut.s_axil_awvalid.value = 0
        if not w_done and int(dut.s_axil_wready.value):
            w_done = True
            dut.s_axil_wvalid.value = 0

    while True:
        # leave bready asserted until the slave closes out this write
        await RisingEdge(dut.cfg_clk)
        if int(dut.s_axil_bvalid.value):
            resp = int(dut.s_axil_bresp.value)
            break

    dut.s_axil_bready.value = 0
    await RisingEdge(dut.cfg_clk)
    return resp


async def axil_read(dut, addr):
    # one outstanding config read is enough for these directed tests
    dut.s_axil_araddr.value = addr
    dut.s_axil_arprot.value = 0
    dut.s_axil_arvalid.value = 1
    dut.s_axil_rready.value = 1

    while True:
        await RisingEdge(dut.cfg_clk)
        if int(dut.s_axil_arready.value):
            dut.s_axil_arvalid.value = 0
            break

    while True:
        await RisingEdge(dut.cfg_clk)
        if int(dut.s_axil_rvalid.value):
            data = int(dut.s_axil_rdata.value)
            resp = int(dut.s_axil_rresp.value)
            break

    dut.s_axil_rready.value = 0
    await RisingEdge(dut.cfg_clk)
    return data, resp


async def wait_for_status_bit(dut, mask, expected=True, timeout_cycles=2000):
    # poll through the real register interface so cdc latency is included
    for _ in range(timeout_cycles):
        data, resp = await axil_read(dut, STATUS)
        assert resp == 0
        if bool(data & mask) == expected:
            return data
        await RisingEdge(dut.cfg_clk)
    raise AssertionError(f"Timed out waiting for STATUS mask 0x{mask:x}")


def _apply_wstrb(old_value, new_value, strb):
    # memory is word based, this recreates byte-lane writes from axi wstrb
    value = old_value
    for byte_idx in range(4):
        if strb & (1 << byte_idx):
            mask = 0xFF << (8 * byte_idx)
            value = (value & ~mask) | (new_value & mask)
    return value & 0xFFFFFFFF


def _stall_active(config, name, cycle):
    # a zero interval means no stalls, otherwise pause on each matching cycle
    interval = config.get(name, 0)
    return interval > 0 and (cycle % interval) == 0


def _has_addr_error(config, name, txn_addr, beat_addr):
    # tests can inject an error for the whole burst address or one specific beat
    error_addrs = config.get(name, set())
    return txn_addr in error_addrs or beat_addr in error_addrs


def _drive_read_beat(dut, memory, read_txn, config):
    # drive the current word and make rlast agree with the modeled burst length
    beat = read_txn["beat"]
    addr = read_txn["addr"] + beat * DATA_BYTES
    dut.m_axi_rdata.value = memory.get(addr, 0)
    dut.m_axi_rresp.value = (
        2 if _has_addr_error(config, "read_error_addrs", read_txn["addr"], addr) else 0
    )
    dut.m_axi_rlast.value = 1 if beat == read_txn["beats"] - 1 else 0
    dut.m_axi_rvalid.value = 1


async def axi_memory_model(dut, memory, log=None, config=None):
    # small single-transaction axi memory, enough to test bursts, stalls, and errors
    config = config or {}
    read_txn = None
    write_txn = None
    write_resp = None
    cycle = 0

    dut.m_axi_arready.value = 1
    dut.m_axi_awready.value = 1
    dut.m_axi_wready.value = 0
    dut.m_axi_rvalid.value = 0
    dut.m_axi_bvalid.value = 0
    dut.m_axi_rresp.value = 0
    dut.m_axi_bresp.value = 0
    dut.m_axi_rlast.value = 0
    dut.m_axi_rid.value = 0
    dut.m_axi_bid.value = 0

    while True:
        await RisingEdge(dut.dma_clk)
        cycle += 1

        if not int(dut.dma_rst_n.value):
            # forget any half-finished transaction when the dma domain resets
            read_txn = None
            write_txn = None
            write_resp = None
            dut.m_axi_arready.value = 1
            dut.m_axi_awready.value = 1
            dut.m_axi_wready.value = 0
            dut.m_axi_rvalid.value = 0
            dut.m_axi_bvalid.value = 0
            dut.m_axi_rlast.value = 0
            continue

        if int(dut.m_axi_rvalid.value) and int(dut.m_axi_rready.value):
            # accepted read beat either advances the burst or releases the channel
            if read_txn is not None and read_txn["beat"] < read_txn["beats"] - 1:
                read_txn["beat"] += 1
                read_txn["delay"] = config.get("rvalid_delay", 0)
                dut.m_axi_rvalid.value = 0
                dut.m_axi_rlast.value = 0
            else:
                read_txn = None
                dut.m_axi_rvalid.value = 0
                dut.m_axi_rlast.value = 0

        if (
            read_txn is not None
            and not int(dut.m_axi_rvalid.value)
        ):
            # optional delay leaves visible gaps between accepted read beats
            if read_txn.get("delay", 0) > 0:
                read_txn["delay"] -= 1
            else:
                _drive_read_beat(dut, memory, read_txn, config)

        if int(dut.m_axi_bvalid.value) and int(dut.m_axi_bready.value):
            dut.m_axi_bvalid.value = 0

        if write_resp is not None and not int(dut.m_axi_bvalid.value):
            # response delay is counted only while bvalid is not already occupied
            if write_resp["delay"] > 0:
                write_resp["delay"] -= 1
            else:
                dut.m_axi_bresp.value = write_resp["resp"]
                dut.m_axi_bvalid.value = 1
                write_resp = None

        # ready signals model both resource availability and configured backpressure
        dut.m_axi_arready.value = (
            1 if read_txn is None and not _stall_active(config, "ar_stall_every", cycle)
            else 0
        )
        dut.m_axi_awready.value = (
            1 if (
                write_txn is None
                and write_resp is None
                and not int(dut.m_axi_bvalid.value)
                and not _stall_active(config, "aw_stall_every", cycle)
            )
            else 0
        )
        dut.m_axi_wready.value = (
            1 if (
                write_txn is not None
                and write_resp is None
                and not int(dut.m_axi_bvalid.value)
                and not _stall_active(config, "w_stall_every", cycle)
            )
            else 0
        )

        if (
            read_txn is None
            and int(dut.m_axi_arvalid.value)
            and int(dut.m_axi_arready.value)
        ):
            # capture one read address and derive the real beat count from arlen
            addr = int(dut.m_axi_araddr.value)
            beats = int(dut.m_axi_arlen.value) + 1
            read_txn = {"addr": addr, "beats": beats, "beat": 0}
            if log is not None:
                log.setdefault("reads", []).append(
                    {
                        "addr": addr,
                        "beats": beats,
                        "size": int(dut.m_axi_arsize.value),
                        "burst": int(dut.m_axi_arburst.value),
                    }
                )
            read_txn["delay"] = config.get("rvalid_delay", 0)
            if read_txn["delay"] == 0:
                _drive_read_beat(dut, memory, read_txn, config)
            dut.m_axi_arready.value = 0

        if (
            write_txn is None
            and int(dut.m_axi_awvalid.value)
            and int(dut.m_axi_awready.value)
        ):
            # data is accepted only after its write address has created a transaction
            addr = int(dut.m_axi_awaddr.value)
            beats = int(dut.m_axi_awlen.value) + 1
            write_txn = {"addr": addr, "beats": beats, "beat": 0}
            if log is not None:
                log.setdefault("writes", []).append(
                    {
                        "addr": addr,
                        "beats": beats,
                        "size": int(dut.m_axi_awsize.value),
                        "burst": int(dut.m_axi_awburst.value),
                    }
                )
            dut.m_axi_awready.value = 0
            dut.m_axi_wready.value = 1

        if (
            write_txn is not None
            and int(dut.m_axi_wvalid.value)
            and int(dut.m_axi_wready.value)
            and not int(dut.m_axi_bvalid.value)
        ):
            # merge each accepted beat into memory and answer after the final beat
            beat = write_txn["beat"]
            addr = write_txn["addr"] + beat * DATA_BYTES
            old_value = memory.get(addr, 0)
            new_value = int(dut.m_axi_wdata.value)
            strb = int(dut.m_axi_wstrb.value)
            memory[addr] = _apply_wstrb(old_value, new_value, strb)

            if beat == write_txn["beats"] - 1 or int(dut.m_axi_wlast.value):
                resp = (
                    2 if _has_addr_error(
                        config,
                        "write_error_addrs",
                        write_txn["addr"],
                        addr,
                    )
                    else 0
                )
                write_txn = None
                dut.m_axi_wready.value = 0
                write_resp = {
                    "resp": resp,
                    "delay": config.get("bvalid_delay", 0),
                }
            else:
                write_txn["beat"] += 1


async def program_transfer(dut, src, dst, length):
    # program the split 64-bit addresses exactly as software would
    assert await axil_write(dut, SRC_ADDR_LO, src & 0xFFFFFFFF) == 0
    assert await axil_write(dut, SRC_ADDR_HI, src >> 32) == 0
    assert await axil_write(dut, DST_ADDR_LO, dst & 0xFFFFFFFF) == 0
    assert await axil_write(dut, DST_ADDR_HI, dst >> 32) == 0
    assert await axil_write(dut, LEN_BYTES, length) == 0


async def program_descriptor_mode(dut, desc_base, desc_count):
    # descriptor mode only needs the list base, list length, and mode bit
    assert await axil_write(dut, DESC_BASE_LO, desc_base & 0xFFFFFFFF) == 0
    assert await axil_write(dut, DESC_BASE_HI, desc_base >> 32) == 0
    assert await axil_write(dut, DESC_COUNT, desc_count) == 0
    assert await axil_write(dut, MODE, 0x1) == 0


def write_words(memory, base, words):
    # the memory model stores one 32-bit value at each byte address
    for idx, word in enumerate(words):
        memory[base + idx * DATA_BYTES] = word & 0xFFFFFFFF


def write_descriptor(memory, base, src, dst, length, control=0x1):
    # lay out the eight base words in the same order the rtl fetches them
    write_words(
        memory,
        base,
        [
            src & 0xFFFFFFFF,
            (src >> 32) & 0xFFFFFFFF,
            dst & 0xFFFFFFFF,
            (dst >> 32) & 0xFFFFFFFF,
            length,
            control,
            0,
            0,
        ],
    )


def write_2d_descriptor(
    memory,
    base,
    src,
    dst,
    row_bytes,
    num_rows,
    src_stride,
    dst_stride,
    control=(0x1 | (DESC_MODE_2D << 4)),
):
    # tiled descriptors append another eight words for rows and strides
    write_words(
        memory,
        base,
        [
            src & 0xFFFFFFFF,
            (src >> 32) & 0xFFFFFFFF,
            dst & 0xFFFFFFFF,
            (dst >> 32) & 0xFFFFFFFF,
            row_bytes,
            control,
            0,
            0,
            num_rows,
            src_stride,
            dst_stride,
            0,
            0,
            0,
            0,
            0,
        ],
    )


def fill_memory(memory, base, words):
    # recognizable data makes copied words and offsets easy to spot in a waveform
    for idx in range(words):
        memory[base + idx * DATA_BYTES] = (0xA5000000 | idx) & 0xFFFFFFFF


def assert_copy(memory, src, dst, length):
    # compare each transferred bus word, no hidden bulk slicing
    for offset in range(0, length, DATA_BYTES):
        assert memory[dst + offset] == memory[src + offset]


def assert_no_4kb_crossing(transactions):
    # first and last byte of every logged burst must stay on the same axi page
    for txn in transactions:
        start_page = txn["addr"] >> 12
        last_addr = txn["addr"] + txn["beats"] * DATA_BYTES - 1
        assert start_page == (last_addr >> 12)


async def clear_status_and_irq(dut):
    # clear sticky completion state before reusing the same dut in a loop
    assert await axil_write(dut, STATUS, 0x6) == 0
    assert await axil_write(dut, IRQ_STATUS, 0xF) == 0


async def run_single_shot_and_check(dut, memory, src, dst, length):
    # common happy path for the seeded single-shot cases below
    await program_transfer(dut, src, dst, length)
    assert await axil_write(dut, MODE, 0x0) == 0
    assert await axil_write(dut, CTRL, 0x1) == 0
    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0
    assert_copy(memory, src, dst, length)


async def expect_error_cause(dut, expected_cause):
    # errors must set error without also pretending the transfer completed
    data = await wait_for_status_bit(dut, 0x4, expected=True)
    assert (data & 0x2) == 0
    error_cause, resp = await axil_read(dut, ERROR_CAUSE)
    assert resp == 0
    assert error_cause == expected_cause


@cocotb.test()
async def dma_memory_to_memory_smoke(dut):
    # basic four-word copy checks data, burst shape, completion, and irq clearing
    start_clocks(dut)
    memory = {
        0x1000: 0x11223344,
        0x1004: 0x55667788,
        0x1008: 0xA5A55A5A,
        0x100C: 0xDEADBEEF,
    }
    log = {"reads": [], "writes": []}
    cocotb.start_soon(axi_memory_model(dut, memory, log))
    await reset_dut(dut)

    await program_transfer(dut, 0x1000, 0x2000, 16)
    assert await axil_write(dut, IRQ_ENABLE, 0x1) == 0
    assert await axil_write(dut, CTRL, 0x1) == 0

    await wait_for_status_bit(dut, 0x1, expected=True)
    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0

    for offset in range(0, 16, 4):
        assert memory[0x2000 + offset] == memory[0x1000 + offset]

    assert [txn["beats"] for txn in log["reads"]] == [4]
    assert [txn["beats"] for txn in log["writes"]] == [4]
    assert all(txn["burst"] == 1 and txn["size"] == 2 for txn in log["reads"])
    assert all(txn["burst"] == 1 and txn["size"] == 2 for txn in log["writes"])

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
    # reject a bad source before the memory side gets a chance to move anything
    start_clocks(dut)
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


@cocotb.test()
async def dma_multi_burst_transfer(dut):
    # a transfer longer than the cap should become one full burst and one short burst
    start_clocks(dut)
    memory = {}
    log = {"reads": [], "writes": []}
    fill_memory(memory, 0x3000, 20)
    cocotb.start_soon(axi_memory_model(dut, memory, log))
    await reset_dut(dut)

    await program_transfer(dut, 0x3000, 0x5000, 20 * DATA_BYTES)
    assert await axil_write(dut, CTRL, 0x1) == 0

    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0
    assert_copy(memory, 0x3000, 0x5000, 20 * DATA_BYTES)
    assert [txn["beats"] for txn in log["reads"]] == [MAX_BURST_BEATS, 4]
    assert [txn["beats"] for txn in log["writes"]] == [MAX_BURST_BEATS, 4]


@cocotb.test()
async def dma_final_short_burst_transfer(dut):
    # final burst length should match the exact words left, not round up to the cap
    start_clocks(dut)
    memory = {}
    log = {"reads": [], "writes": []}
    fill_memory(memory, 0x6000, 19)
    cocotb.start_soon(axi_memory_model(dut, memory, log))
    await reset_dut(dut)

    await program_transfer(dut, 0x6000, 0x7000, 19 * DATA_BYTES)
    assert await axil_write(dut, CTRL, 0x1) == 0

    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0
    assert_copy(memory, 0x6000, 0x7000, 19 * DATA_BYTES)
    assert [txn["beats"] for txn in log["reads"]] == [MAX_BURST_BEATS, 3]
    assert [txn["beats"] for txn in log["writes"]] == [MAX_BURST_BEATS, 3]


@cocotb.test()
async def dma_splits_bursts_at_4kb_boundaries(dut):
    # source and destination boundaries both trim bursts even when length allows more
    start_clocks(dut)
    memory = {}
    log = {"reads": [], "writes": []}
    src = 0x0FF0
    dst = 0x1FE0
    length = 16 * DATA_BYTES
    fill_memory(memory, src, 16)
    cocotb.start_soon(axi_memory_model(dut, memory, log))
    await reset_dut(dut)

    await program_transfer(dut, src, dst, length)
    assert await axil_write(dut, CTRL, 0x1) == 0

    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0
    assert_copy(memory, src, dst, length)
    assert [txn["beats"] for txn in log["reads"]] == [4, 4, 8]
    assert [txn["beats"] for txn in log["writes"]] == [4, 4, 8]
    assert_no_4kb_crossing(log["reads"])
    assert_no_4kb_crossing(log["writes"])


@cocotb.test()
async def descriptor_mode_single_descriptor(dut):
    # one linear descriptor should fetch, copy, write status, and finish the list
    start_clocks(dut)
    memory = {}
    log = {"reads": [], "writes": []}
    desc_base = 0x8000
    src = 0x9000
    dst = 0xA000
    length = 8 * DATA_BYTES
    fill_memory(memory, src, 8)
    write_descriptor(memory, desc_base, src, dst, length)
    cocotb.start_soon(axi_memory_model(dut, memory, log))
    await reset_dut(dut)

    await program_descriptor_mode(dut, desc_base, 1)
    assert await axil_write(dut, CTRL, 0x1) == 0

    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0
    assert_copy(memory, src, dst, length)
    assert memory[desc_base + 0x18] & 0x1
    assert [txn["beats"] for txn in log["reads"]] == [8, 8]
    assert [txn["beats"] for txn in log["writes"]] == [8, 1]


@cocotb.test()
async def descriptor_mode_2d_padded_to_compact(dut):
    # source rows include padding while destination rows are packed back to back
    start_clocks(dut)
    memory = {}
    log = {"reads": [], "writes": []}
    desc_base = 0xA800
    src = 0xB800
    dst = 0xC800
    row_bytes = 2 * DATA_BYTES
    num_rows = 3
    src_stride = 4 * DATA_BYTES
    dst_stride = row_bytes

    for row in range(num_rows):
        write_words(
            memory,
            src + row * src_stride,
            [
                0x55000000 | (row << 8) | 0,
                0x55000000 | (row << 8) | 1,
            ],
        )

    write_2d_descriptor(
        memory,
        desc_base,
        src,
        dst,
        row_bytes,
        num_rows,
        src_stride,
        dst_stride,
    )
    cocotb.start_soon(axi_memory_model(dut, memory, log))
    await reset_dut(dut)

    await program_descriptor_mode(dut, desc_base, 1)
    assert await axil_write(dut, CTRL, 0x1) == 0

    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0
    for row in range(num_rows):
        assert_copy(
            memory,
            src + row * src_stride,
            dst + row * dst_stride,
            row_bytes,
        )
    assert memory[desc_base + 0x18] & 0x1
    assert [txn["beats"] for txn in log["reads"]] == [8, 8, 2, 2, 2]
    assert [txn["beats"] for txn in log["writes"]] == [2, 2, 2, 1]
    completed_desc, resp = await axil_read(dut, COMPLETED_DESC_COUNT)
    assert resp == 0
    assert completed_desc == 1
    completed_bytes, resp = await axil_read(dut, COMPLETED_BYTE_COUNT_LO)
    assert resp == 0
    assert completed_bytes == row_bytes * num_rows


@cocotb.test()
async def descriptor_mode_multiple_descriptors(dut):
    # list processing should advance descriptor address and preserve each copy length
    start_clocks(dut)
    memory = {}
    log = {"reads": [], "writes": []}
    desc_base = 0xB000
    desc0 = desc_base
    desc1 = desc_base + 0x20
    src0 = 0xC000
    dst0 = 0xD000
    src1 = 0xE000
    dst1 = 0xF000
    len0 = 6 * DATA_BYTES
    len1 = 18 * DATA_BYTES
    fill_memory(memory, src0, 6)
    fill_memory(memory, src1, 18)
    write_descriptor(memory, desc0, src0, dst0, len0)
    write_descriptor(memory, desc1, src1, dst1, len1)
    cocotb.start_soon(axi_memory_model(dut, memory, log))
    await reset_dut(dut)

    await program_descriptor_mode(dut, desc_base, 2)
    assert await axil_write(dut, CTRL, 0x1) == 0

    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0
    assert_copy(memory, src0, dst0, len0)
    assert_copy(memory, src1, dst1, len1)
    assert memory[desc0 + 0x18] & 0x1
    assert memory[desc1 + 0x18] & 0x1
    desc_index, resp = await axil_read(dut, DESC_INDEX)
    assert resp == 0
    assert desc_index == 1
    assert [txn["beats"] for txn in log["reads"]] == [8, 6, 8, 16, 2]
    assert [txn["beats"] for txn in log["writes"]] == [6, 1, 16, 2, 1]


@cocotb.test()
async def descriptor_mode_invalid_descriptor_sets_error(dut):
    # invalid control gets an error status writeback instead of starting payload traffic
    start_clocks(dut)
    memory = {}
    desc_base = 0x11000
    write_descriptor(memory, desc_base, 0x12000, 0x13000, 4 * DATA_BYTES, control=0)
    cocotb.start_soon(axi_memory_model(dut, memory))
    await reset_dut(dut)

    await program_descriptor_mode(dut, desc_base, 1)
    assert await axil_write(dut, IRQ_ENABLE, 0x2) == 0
    assert await axil_write(dut, CTRL, 0x1) == 0

    data = await wait_for_status_bit(dut, 0x4, expected=True)
    assert (data & 0x2) == 0
    assert memory[desc_base + 0x18] & 0x2
    error_cause, resp = await axil_read(dut, ERROR_CAUSE)
    assert resp == 0
    assert error_cause == ERROR_CAUSE_DESC_INVALID
    irq_status, resp = await axil_read(dut, IRQ_STATUS)
    assert resp == 0
    assert (irq_status & 0x2) == 0x2


@cocotb.test()
async def irq_error_clear_and_error_cause(dut):
    # status, irq, and saved cause have related but separately clearable behavior
    start_clocks(dut)
    memory = {}
    cocotb.start_soon(axi_memory_model(dut, memory))
    await reset_dut(dut)

    await program_transfer(dut, 0x14000, 0x15000, 0)
    assert await axil_write(dut, IRQ_ENABLE, 0x2) == 0
    assert await axil_write(dut, CTRL, 0x1) == 0

    await expect_error_cause(dut, ERROR_CAUSE_ZERO_LEN)
    irq_status, resp = await axil_read(dut, IRQ_STATUS)
    assert resp == 0
    assert (irq_status & 0x2) == 0x2
    assert int(dut.irq.value) == 1

    assert await axil_write(dut, IRQ_STATUS, 0x2) == 0
    irq_status, _ = await axil_read(dut, IRQ_STATUS)
    assert (irq_status & 0x2) == 0
    assert int(dut.irq.value) == 0

    assert await axil_write(dut, STATUS, 0x4) == 0
    status, _ = await axil_read(dut, STATUS)
    assert (status & 0x4) == 0
    error_cause, _ = await axil_read(dut, ERROR_CAUSE)
    assert error_cause == 0


@cocotb.test()
async def axi_read_error_response_sets_error(dut):
    # an rresp error should stop before any destination write is treated as successful
    start_clocks(dut)
    memory = {}
    src = 0x16000
    dst = 0x17000
    fill_memory(memory, src, 8)
    cocotb.start_soon(
        axi_memory_model(dut, memory, config={"read_error_addrs": {src}})
    )
    await reset_dut(dut)

    await program_transfer(dut, src, dst, 8 * DATA_BYTES)
    assert await axil_write(dut, IRQ_ENABLE, 0x2) == 0
    assert await axil_write(dut, CTRL, 0x1) == 0

    await expect_error_cause(dut, ERROR_CAUSE_AXI_READ)
    irq_status, _ = await axil_read(dut, IRQ_STATUS)
    assert (irq_status & 0x2) == 0x2
    assert int(dut.irq.value) == 1


@cocotb.test()
async def axi_write_error_response_sets_error(dut):
    # a bad bresp reports a write failure even though data beats already reached memory
    start_clocks(dut)
    memory = {}
    src = 0x18000
    dst = 0x19000
    fill_memory(memory, src, 8)
    cocotb.start_soon(
        axi_memory_model(dut, memory, config={"write_error_addrs": {dst}})
    )
    await reset_dut(dut)

    await program_transfer(dut, src, dst, 8 * DATA_BYTES)
    assert await axil_write(dut, IRQ_ENABLE, 0x2) == 0
    assert await axil_write(dut, CTRL, 0x1) == 0

    await expect_error_cause(dut, ERROR_CAUSE_AXI_WRITE)
    irq_status, _ = await axil_read(dut, IRQ_STATUS)
    assert (irq_status & 0x2) == 0x2
    assert int(dut.irq.value) == 1


@cocotb.test()
async def dma_backpressure_transfer_and_observability(dut):
    # stagger every axi channel and sample the live cursor while the job is still busy
    start_clocks(dut)
    memory = {}
    src = 0x1A000
    dst = 0x1B000
    length = 40 * DATA_BYTES
    fill_memory(memory, src, 40)
    cocotb.start_soon(
        axi_memory_model(
            dut,
            memory,
            config={
                "ar_stall_every": 3,
                "aw_stall_every": 4,
                "w_stall_every": 5,
                "rvalid_delay": 1,
                "bvalid_delay": 1,
            },
        )
    )
    await reset_dut(dut)

    await program_transfer(dut, src, dst, length)
    assert await axil_write(dut, CTRL, 0x1) == 0
    await wait_for_status_bit(dut, 0x1, expected=True)

    active_src, resp = await axil_read(dut, ACTIVE_SRC_LO)
    assert resp == 0
    assert src <= active_src < src + length
    assert (active_src - src) % DATA_BYTES == 0
    active_dst, resp = await axil_read(dut, ACTIVE_DST_LO)
    assert resp == 0
    assert dst <= active_dst < dst + length
    assert (active_dst - dst) % DATA_BYTES == 0
    remaining, resp = await axil_read(dut, BYTES_REMAINING)
    assert resp == 0
    assert 0 < remaining <= length

    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0
    assert_copy(memory, src, dst, length)
    completed_bytes, resp = await axil_read(dut, COMPLETED_BYTE_COUNT_LO)
    assert resp == 0
    assert completed_bytes == length


@cocotb.test()
async def randomized_aligned_single_shot_transfers(dut):
    # fixed seed gives varied legal sizes and offsets without making failures slippery
    seed = 0xD06
    rng = random.Random(seed)
    dut._log.info("randomized_aligned_single_shot_transfers seed=0x%x", seed)
    start_clocks(dut)
    memory = {}
    cocotb.start_soon(axi_memory_model(dut, memory))
    await reset_dut(dut)

    for idx in range(5):
        words = rng.randint(1, 24)
        src = 0x20000 + idx * 0x1000 + rng.randint(0, 8) * DATA_BYTES
        dst = 0x30000 + idx * 0x1000 + rng.randint(0, 8) * DATA_BYTES
        fill_memory(memory, src, words)

        await run_single_shot_and_check(dut, memory, src, dst, words * DATA_BYTES)
        completed_bytes, resp = await axil_read(dut, COMPLETED_BYTE_COUNT_LO)
        assert resp == 0
        assert completed_bytes == words * DATA_BYTES
        await clear_status_and_irq(dut)


@cocotb.test()
async def randomized_descriptor_list(dut):
    # build a small seeded list and check aggregate counters as well as every copy
    seed = 0xD354
    rng = random.Random(seed)
    dut._log.info("randomized_descriptor_list seed=0x%x", seed)
    start_clocks(dut)
    memory = {}
    desc_base = 0x40000
    expected_bytes = 0
    descriptors = []
    for idx in range(3):
        words = rng.randint(2, 12)
        src = 0x41000 + idx * 0x2000
        dst = 0x50000 + idx * 0x2000
        fill_memory(memory, src, words)
        write_descriptor(memory, desc_base + idx * 0x20, src, dst, words * DATA_BYTES)
        descriptors.append((src, dst, words * DATA_BYTES))
        expected_bytes += words * DATA_BYTES

    cocotb.start_soon(axi_memory_model(dut, memory))
    await reset_dut(dut)

    await program_descriptor_mode(dut, desc_base, len(descriptors))
    assert await axil_write(dut, IRQ_ENABLE, 0xC) == 0
    assert await axil_write(dut, CTRL, 0x1) == 0

    data = await wait_for_status_bit(dut, 0x2, expected=True)
    assert (data & 0x4) == 0
    for idx, (src, dst, length) in enumerate(descriptors):
        assert_copy(memory, src, dst, length)
        assert memory[desc_base + idx * 0x20 + 0x18] & 0x1

    completed_desc, resp = await axil_read(dut, COMPLETED_DESC_COUNT)
    assert resp == 0
    assert completed_desc == len(descriptors)
    completed_bytes, resp = await axil_read(dut, COMPLETED_BYTE_COUNT_LO)
    assert resp == 0
    assert completed_bytes == expected_bytes
    irq_status, resp = await axil_read(dut, IRQ_STATUS)
    assert resp == 0
    assert (irq_status & 0xC) == 0xC
    assert int(dut.irq.value) == 1


@cocotb.test()
async def descriptor_validation_error_causes(dut):
    # table-driven invalid inputs make sure each public error code stays distinct
    start_clocks(dut)
    memory = {}
    cocotb.start_soon(axi_memory_model(dut, memory))

    cases = (
        ("zero length", 0x60000, 1, (0x61000, 0x62000, 0), ERROR_CAUSE_ZERO_LEN, True),
        (
            "unaligned source",
            0x60020,
            1,
            (0x61002, 0x62000, 4 * DATA_BYTES),
            ERROR_CAUSE_SRC_UNALIGNED,
            True,
        ),
        (
            "unaligned destination",
            0x60040,
            1,
            (0x61000, 0x62002, 4 * DATA_BYTES),
            ERROR_CAUSE_DST_UNALIGNED,
            True,
        ),
        (
            "descriptor count zero",
            0x60060,
            0,
            (0x61000, 0x62000, 4 * DATA_BYTES),
            ERROR_CAUSE_DESC_COUNT_ZERO,
            False,
        ),
        (
            "descriptor base unaligned",
            0x60084,
            1,
            (0x61000, 0x62000, 4 * DATA_BYTES),
            ERROR_CAUSE_DESC_BASE_UNALIGNED,
            False,
        ),
    )

    for name, desc_base, desc_count, desc, expected_cause, expect_status in cases:
        dut._log.info("descriptor validation case: %s", name)
        memory.clear()
        await reset_dut(dut)
        src, dst, length = desc
        write_descriptor(memory, desc_base, src, dst, length)
        await program_descriptor_mode(dut, desc_base, desc_count)
        assert await axil_write(dut, CTRL, 0x1) == 0
        await expect_error_cause(dut, expected_cause)
        if expect_status:
            assert memory[desc_base + 0x18] & 0x2


@cocotb.test()
async def reset_idle_and_active_clears_state(dut):
    # reset once while idle and once mid-job, both should return every csr to quiet state
    start_clocks(dut)
    memory = {}
    src = 0x70000
    dst = 0x71000
    fill_memory(memory, src, 32)
    cocotb.start_soon(
        axi_memory_model(dut, memory, config={"ar_stall_every": 1})
    )
    await reset_dut(dut)

    assert await axil_write(dut, IRQ_ENABLE, 0xF) == 0
    assert await axil_write(dut, IRQ_STATUS, 0xF) == 0
    assert await axil_write(dut, STATUS, 0x6) == 0
    status, resp = await axil_read(dut, STATUS)
    assert resp == 0
    assert status == 0
    irq_status, resp = await axil_read(dut, IRQ_STATUS)
    assert resp == 0
    assert irq_status == 0

    await program_transfer(dut, src, dst, 32 * DATA_BYTES)
    assert await axil_write(dut, CTRL, 0x1) == 0
    await wait_for_status_bit(dut, 0x1, expected=True)
    await reset_dut(dut)

    for addr in (STATUS, IRQ_ENABLE, IRQ_STATUS, ERROR_CAUSE, BYTES_REMAINING):
        data, resp = await axil_read(dut, addr)
        assert resp == 0
        assert data == 0
