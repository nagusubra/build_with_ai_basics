"""Capture and audit every Jill artboard; --quick omits the animated WebP."""
import sys

from build_jill import ARTBOARDS, HERE
from audit_rig import audit

if __name__ == "__main__":
    audit(HERE, ARTBOARDS, "jill_wingwoman", "--quick" in sys.argv)
