# Fan Boost

An Omarchy bar widget that pushes the machine's fans to maximum — on a timer or
held — shows CPU and GPU temperature, and returns the fans to the firmware's
automatic control.

It serves two very different machines through one door:

| Mechanism | Where | What it writes |
| --- | --- | --- |
| `hwmon` pwm | Dell (`dell_smm`), ASUS, ThinkPad, others | `pwmN_enable=1`, `pwmN=255` |
| `platform_profile` | anything with ACPI platform profiles (pulled as well, not only as a fallback) | `performance`, restored on release |
| `asusctl` | ASUS ROG laptops without pwm channels | maxed fan curves + the Performance profile |

The plugin probes at run time; nothing is hard-coded to one machine. It pulls
**every** lever a machine offers rather than stopping at the first, because a
lever can be present and inert — measured on this house's Dell Precision 7560,
where `dell_smm` accepts `pwm1=255` and the fans do not move, while the ACPI
profile took them from 3 690 rpm to 4 810 rpm in ten seconds.

## Install

The widget reads fan state without privileges, but writing it needs root. The
door is one named binary — `/usr/local/bin/fanctl` — and one sudoers rule that
allows exactly that path and nothing else.

```sh
cd ~/.config/omarchy/plugins/io.github.zerwiz.fan-boost
sudo ./install.sh
```

`install.sh` installs `fanctl`, writes `/etc/sudoers.d/20-fanctl` validated by
`visudo -c`, and prints the probe commands.

Then enable the widget:

```sh
omarchy plugin enable io.github.zerwiz.fan-boost --enable
omarchy restart shell
```

## Usage

- **Left-click** the bar icon to open the panel.
- **Cool 5 min** and **Max 5 min** run flat out for the configured time, then
  revert by themselves (a transient `systemd` timer does the reverting, so it
  survives the shell closing).
- **Cool** drives the fans with the power limit held back; **Max** raises the
  performance profile as well. On this house's Dell they are the same firmware
  knob seen from two sides, measured: `Ultra Performance` on the BIOS attribute
  flips the ACPI profile to `performance`, `Cool` to `cool`, and at 67 °C the
  `cool` setting spun the fans to 4 214 rpm while `performance` sat at 3 170.
- **Hold max** keeps them flat out until you press **Auto**.
- **Auto** returns the fans to the firmware, replaying the state it saved
  before the boost.

The panel also shows CPU and GPU temperature: the CPU package sensor
(`coretemp` on Intel, `k10temp` on AMD, falling back to the platform sensor), and
the GPU through `nvidia-smi`, or an `amdgpu` hwmon edge sensor where there is no
NVIDIA card.

The bar carries a wind glyph with the average fan speed (🌬 4502), and
🌬 MAX while boosted.

## The command line

`fanctl` is the same door, usable by hand — handy when the shell is not up:

```sh
fanctl status        # mode, per-fan rpm/pwm, temperatures, active mechanism
sudo fanctl max 300  # fans to max, profile to performance, five minutes
sudo fanctl cool 300 # fans to max, power profile held back, five minutes
sudo fanctl max hold # boost until released
sudo fanctl auto     # back to automatic
```

## Limits worth knowing

- **A pwm channel can be present and powerless.** On the Precision 7560 here,
  `dell_smm` accepts a write and clamps it (255 in, 128 back), and the fans do
  not follow; the ACPI platform profile is what actually moves them. `fanctl`
  reads every written value back and prints a warning when the driver ignores
  it.
- **Dell SMM writes can freeze some Precision models.** The helper arms the
  revert timer before it returns, so a machine left in `MAX` still frees
  itself.
- A held boost is loud and drains the battery; the timer exists so that
  forgetting is not a trap.
- `hwmon` writes are allow-listed to fan drivers (`dell_smm`, `asus*`,
  `thinkpad`, `ideapad`, `hp`, `system76`, `acer`, `acpi_fan`), never to every
  `pwm` node the kernel exposes.
- State lives in `/run/fanctl/`, so it is gone after a reboot — a reboot is
  always a clean return to automatic.

## Remove

```sh
omarchy plugin remove io.github.zerwiz.fan-boost
sudo rm -f /usr/local/bin/fanctl /etc/sudoers.d/20-fanctl
```

## Contributors

**zerwiz (Josef Lindbom)**, author and maintainer.

## License

MIT — see [LICENSE](LICENSE).
