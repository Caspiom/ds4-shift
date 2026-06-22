# ds4-shift

Zero-overhead, on-demand DualShock 4 → Xbox 360 emulation for Linux.

Drives `ds4drv` automatically via udev — the driver starts the moment your
controller connects over Bluetooth and stops the moment it disconnects.
No background daemons. No boot services. No manual commands.

## How it works

```
Controller powers on
  → Bluetooth connects → kernel creates /dev/hidrawX
  → udev matches the HID device (Sony 054C, DS4 protocol)
  → ds4drv starts, emulates an Xbox 360 pad via uinput
  → Controller powers off → ds4drv stops automatically
```

Multiple controllers are supported. Each connection triggers a re-scan;
removing one controller restarts the driver only if others remain active.

## Requirements

- Linux kernel 5.12+ (for the `playstation` HID driver)
- `ds4drv` — `pip install ds4drv` or via AUR: `yay -S ds4drv`
- `systemd` 220+
- Bluetooth stack (`bluez`, `bluez-utils`)

## Compatibility

Tested with the **Fantech Nova II** (presents as `054C:09CC`, DS4 v2 clone).
Works with any controller that identifies as:

| Product ID | Controller |
|---|---|
| `05C4` | DualShock 4 v1 (CUH-ZCT1) |
| `09CC` | DualShock 4 v2 (CUH-ZCT2) and clones |

## Installation

```bash
git clone https://github.com/Caspiom/ds4-shift
cd ds4-shift
sudo bash install.sh
```

### Manual installation

```bash
# 1. Hotplug lifecycle script
sudo install -m 755 ds4drv-hotplug /usr/local/bin/ds4drv-hotplug

# 2. Systemd service (on-demand, never starts at boot)
sudo install -m 644 ds4drv.service /etc/systemd/system/ds4drv.service
sudo systemctl daemon-reload
sudo systemctl disable ds4drv.service 2>/dev/null || true

# 3. udev rules
sudo install -m 644 99-fantech-ds4drv.rules /etc/udev/rules.d/99-fantech-ds4drv.rules
sudo udevadm control --reload-rules
```

## Files

```
ds4drv-hotplug            # Lifecycle manager called by udev
ds4drv.service            # Systemd service unit (on-demand only)
99-fantech-ds4drv.rules   # udev rules for DS4 device detection
install.sh                # Convenience installer
```

## Uninstall

```bash
sudo bash install.sh --uninstall
```

## Troubleshooting

**Controller connects but driver doesn't start**

Check that udev is picking up the device:
```bash
sudo udevadm test /sys/class/hidraw/hidraw11 2>&1 | grep -E "ds4|09CC|RUN"
```

Check the service journal:
```bash
journalctl -u ds4drv.service -n 50
```

**Two gamepads appear when the controller connects**

The kernel `playstation` driver creates one device; ds4drv creates another
(Xbox 360). Configure your game or Steam Input to use the Xbox 360 device
(`/dev/input/js*` with `Microsoft` in the name).

**Manually trigger the driver (for testing)**

```bash
sudo /usr/local/bin/ds4drv-hotplug add
journalctl -u ds4drv.service -f
```

## License

MIT
