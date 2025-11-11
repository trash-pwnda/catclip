# 🐱 catclip
**cat + clipboard — a clipboard-aware `cat` for Unix-like systems**

Output to stdout _and_ clipboard simultaneously. One command, zero configuration. Perfect for everyday dev work, pentesting, and CTFs.

```bash
catclip exploit.py              # print the file AND copy it to clipboard
echo "payload" | catclip        # works with pipes
catclip -c secrets.txt          # copy to clipboard only (no stdout)
catclip -p | jq .               # paste: read clipboard → stdout → pipe
```

---

## Install
```bash
mkdir -p ~/.local/bin && curl -sL https://raw.githubusercontent.com/trash-pwnda/catclip/main/catclip.sh -o ~/.local/bin/catclip && chmod +x ~/.local/bin/catclip
```

Add `~/.local/bin` to PATH if needed:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

**Verify:**
```bash
catclip --version
```

---

## Why catclip?

**Auto-detects your clipboard tool** — Works immediately on macOS (`pbcopy`), Linux Wayland (`wl-copy`), X11 (`xclip`), WSL (`clip.exe`), and Termux (`termux-clipboard-set`). No configuration needed.

**POSIX-compliant** — Unlike `cat file | tee >(pbcopy)`, this works in any shell (sh, bash, zsh, dash). No bashisms, no process substitution.

**Single-file, no build step** — Easy install, same behavior on different machines.

**Bidirectional clipboard support** — copy (files/stdin → stdout + clipboard), and optionally paste (clipboard → stdout) with a single tool.

---

## Usage
```bash
catclip [OPTION]... [FILE]...
```

### Paste mode
Use `-p, --paste` to print clipboard contents to stdout:

```bash
catclip -p                # view clipboard contents
catclip -p | jq .         # parse JSON copied from a browser/IDE
catclip -p | hexdump -C   # inspect bytes / encoding
catclip -p > pasted.txt   # save clipboard to a file
```

**Note:** On Windows/WSL, clipboard paste is text-only; binary round-trips are not guaranteed. To safely copy binary files or ensure byte-for-byte integrity, encode first:

```bash
base64 file.bin | catclip
# or
openssl base64 < file.bin | catclip
```

And decode after pasting:
```bash
catclip -p | base64 --decode > file.bin
```

---

### Examples
```bash
# Basic usage
catclip payload.txt

# Multiple files
catclip file1.txt file2.txt

# Pipe input
curl https://example.com/exploit.sh | catclip

# Chain with other commands
catclip recon.txt | grep -i "admin"

# Copy to clipboard only (hide sensitive output)
catclip -c api_keys.txt

# Write to file while copying to clipboard
catclip data.txt > output.txt

# Interactive mode (type, then Ctrl+D)
catclip
```

### Options

- `-c, --clip-only` — Copy to clipboard without stdout (for sensitive data)
- `-v, --verbose` — Show clipboard status messages
- `-p, --paste` — Paste clipboard contents to stdout (text-mode paste)
- `-q, --quiet` — Suppress all status messages
- `--help` — Show help
- `--version` — Show version

---

## Supported Platforms

| Platform | Copy | Paste | Tool |
|----------|------|--------|-----|
| macOS | ✅ | ✅ | `pbcopy` |
| Linux (Wayland) | ✅ | ✅ | `wl-copy` |
| Linux (X11) | ✅ | ✅ | `xclip` |
| Android (Termux) | ✅ | ✅ | `termux-clipboard-set` |
| Windows (WSL) | ✅ | ❌ | `clip.exe` |

> **Note:** `clip.exe` is used only as a fallback on WSL when no other clipboard tool is available. If no supported clipboard tool is found, `catclip` will warn and behave like cat (stdout only).

---

## Security Recommendations
`catclip` never encrypts or stores clipboard contents — it simply bridges stdin/stdout with your system clipboard. For sensitive data, encrypt before copying (e.g. `age -r <recipient> --armor | catclip`) and decrypt after pasting (`catclip -p | age -d -i <key>`). Use `--clip-only` to avoid terminal logs. Remember: clipboard history or OS sync may retain copies.

---

## FAQ

**Q: Why not just use an alias like `alias cpcat='tee >(pbcopy)'`?**  
A: Three reasons:
1. You'd need different aliases per platform (`pbcopy`/`xclip`/`wl-copy`/`clip.exe`)
2. Aliases don't persist on new systems — `catclip` installs once, works everywhere
3. Process substitution `>(...)` isn't POSIX (requires bash/zsh)
4. `catclip` is meant for quick, disposable environments (think remote shells, CTF boxes, or Docker containers) where you may not know which OS or clipboard utility is available

**Q: Can I pipe clipboard contents into other commands?**  
A: Yes — that’s one of the most useful patterns: `catclip -p | jq .` or `catclip -p | hexdump -C`.

**Q: Will catclip corrupt binary files?**  
A: `catclip` will forward bytes to both stdout and the clipboard tool, but system clipboard managers are often text-oriented. If you need to avoid terminal binary output, use `--clip-only` to copy only.

**Q: Is piping the install script safe?**  
A: Inspect before running:
```bash
curl -sL https://raw.githubusercontent.com/trash-pwnda/catclip/main/catclip.sh | less
```

**Q: Any security gotchas?**  
A: Clipboard contents can be stored in clipboard histories or synced by OS services. `--clip-only` avoids terminal logs, but cannot control external clipboard history/syncing.

---

## License

MIT © 2025 [@trashpwnda](https://github.com/trash-pwnda)
