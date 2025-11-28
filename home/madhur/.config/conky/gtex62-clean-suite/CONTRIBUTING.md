# Contributing to gtex62-clean-suite

Thanks for your interest!

## How to contribute
1. **Open an Issue** describing the bug/feature. Include OS/Conky version and screenshots if relevant.
2. **Fork** the repo, create a branch:
```bash
   git checkout -b feat/your-short-title
```
3. **Make changes**:

   * Keep code readable and minimal.
   * Lua/Conky: prefer clear names, avoid hard-coded user paths when possible.
   * Add/update screenshots if a widget’s look changes.
4. **Test locally** on your desktop (Conky X11).
5. **Commit** with a clear message:

   * Example: `fix(net-sys): show (VPN) label while reconnecting`
6. **Open a Pull Request** and link the Issue.

## Project layout

* `widgets/` – widget configs/scripts
* `lua/` – shared Lua helpers
* `theme.lua` – fonts/colors/sizes
* `screenshots/` – small PNGs shown in README

## Reporting bugs

* Include steps to reproduce, logs (if any), and screenshots.

## License

By contributing, you agree your contributions are licensed under the repository’s MIT License.


