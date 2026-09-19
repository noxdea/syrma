# ADR 001: Demo recording uses the virtual clock

Frame capture advances only a session virtual clock. Real-time sessions are
rejected because their timing and pixels cannot be reproduced in CI.
