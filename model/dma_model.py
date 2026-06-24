#!/usr/bin/env python3
"""Reference-model scaffold for the descriptor-based AXI4 DMA engine."""

from dataclasses import dataclass
from enum import Enum, auto


class CompletionStatus(Enum):
    # model-side names mirror the broad completion buckets used by the rtl
    OKAY = auto()
    AXI_READ_ERROR = auto()
    AXI_WRITE_ERROR = auto()
    INTERNAL_ERROR = auto()


@dataclass
class Descriptor:
    # plain python shape for building descriptors without worrying about bit packing yet
    src_addr: int
    dst_addr: int
    byte_count: int
    desc_id: int = 0
    flags: int = 0


@dataclass
class Completion:
    # this is what a future scoreboard can compare against the hardware result
    desc_id: int
    status: CompletionStatus
    bytes_transferred: int = 0
    error_code: int = 0


class DmaModel:
    """High-level behavioral scaffold for future checking."""

    def execute(self, descriptor: Descriptor) -> Completion:
        """Return an internal-error completion until copy behavior is modeled."""
        # keep the scaffold honest for now, no pretend copy behavior until it is modeled
        return Completion(
            desc_id=descriptor.desc_id,
            status=CompletionStatus.INTERNAL_ERROR,
            bytes_transferred=0,
            error_code=0,
        )
