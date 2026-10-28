Local copy of reactive_ble_mobile 5.6.0 (original license retained).

Only discovery-name resolution is patched: trim advertisement and platform names, and fall back to the platform name when the advertisement name is blank. Public protobuf messages, scan filters, permissions, GATT operations, timeouts and connection behavior remain upstream. When upgrading, retain this patch or adopt an upstream equivalent.
