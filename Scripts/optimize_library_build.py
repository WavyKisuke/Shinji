from pathlib import Path


def replace_once(text: str, old: str, new: str) -> str:
    if not old or old not in text:
        return text
    return text.replace(old, new, 1)


# This build script intentionally does not mutate the library view anymore.
# The source is versioned directly in the repo and should compile without runtime
# patching in CI. Keeping the script as a no-op prevents future regressions from
# brittle string replacement.
path = Path("Shinji/Views/UnifiedLibraryView.swift")
if path.exists():
    text = path.read_text(encoding="utf-8")
    if "private var featuredItems" not in text:
        raise SystemExit("Missing featuredItems block; repository source is incomplete.")
    print("Library view source is already in the stable state; no patching required.")
else:
    raise SystemExit("Shinji/Views/UnifiedLibraryView.swift not found.")
