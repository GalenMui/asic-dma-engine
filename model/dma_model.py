#!/usr/bin/env python3
"""Reference-model scaffolding for the descriptor-based AXI4 DMA engine."""

from dataclasses import dataclass
from enum import Enum, auto


class CompletionStatus(Enum):
    OKAY = auto()
    AXI_READ_ERROR = auto()
    AXI_WRITE_ERROR = auto()
    INTERNAL_ERROR = auto()


@dataclass
class Descriptor:
    src_addr: int
    dst_addr: int
    byte_count: int
    desc_id: int = 0
    flags: int = 0


@dataclass
class Completion:
    desc_id: int
    status: CompletionStatus
    bytes_transferred: int = 0
    error_code: int = 0


class DmaModel:
    """High-level behavioral placeholder for future checking."""

    def execute(self, descriptor: Descriptor) -> Completion:
        """Return a placeholder completion until copy behavior is modeled."""
        # TODO: Model expected memory copy behavior, completion formatting,
        # descriptor ownership transitions, and error handling.
        return Completion(
            desc_id=descriptor.desc_id,
            status=CompletionStatus.INTERNAL_ERROR,
            bytes_transferred=0,
            error_code=0,
        )
