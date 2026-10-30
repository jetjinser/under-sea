"""Offline integration smoke through Camoufox's Playwright controller."""

import os

from camoufox import DefaultAddons
from camoufox.sync_api import Camoufox


from camoufox.fpgen_model import ensure_fpgen_model

ensure_fpgen_model()
with Camoufox(
    headless=True,
    geoip=False,
    os="linux",
    executable_path=os.environ["CAMOUFOX_EXECUTABLE_PATH"],
    exclude_addons=[DefaultAddons.UBO],
) as browser:
    page = browser.new_page()
    page.goto("data:text/html,<title>under-sea-camoufox-smoke</title><p>ready</p>")
    assert page.title() == "under-sea-camoufox-smoke"
    page.screenshot(path="/tmp/camoufox-smoke.png")
