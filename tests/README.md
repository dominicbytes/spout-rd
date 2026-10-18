# Native regression tests

Set REDOT_BIN to the Redot console executable, then run:

    ./tests/run_tests.ps1 -WorkRoot <scratch-directory>
    ./tests/run_tests.ps1 -SkipGpu -WorkRoot <scratch-directory>

The default suite uses D3D12 and Vulkan in small off-screen Windows windows.
Redot 26.3 headless display supports only the dummy renderer, so only extension
load and API tests use true headless mode. Each process has a 600-frame limit
and an external timeout. Logs and JSON results are saved under WorkRoot.
No editor import is needed. The runner creates missing submodule .gdignore
files without changing tracked dependency sources.

Success requires exit 0, a PASS marker, no engine/script errors, and no unexpected
engine warnings. The known D3D12 PSO-cache warning is allowed. Guard tests require
exactly one matching addon warning. API invalid-input tests suppress error printing
only during synchronous calls that are expected to reject their inputs.

The test_guard separate_config case sets the separate-thread project setting after
safe renderer initialization, testing the guard without invoking an engine shutdown
bug. Actual --render-thread separate diagnostics on 26.3 still produce an RD
finalize error and ObjectDB leak warning on addon-free projects. Those diagnostics
are separate from the clean gate; the addon must warn once and send zero frames.
The gl case verifies the inert GL Compatibility path; experimental direct GL
sharing is not exercised.

Spout CPU receive uses two staging textures. Pixel tests allow initial connection
and staging frames before checking data. The gradient test preserves the original
GDScript send_image default orientation (invert=true).
