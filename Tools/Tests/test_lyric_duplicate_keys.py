"""Compile the real lyric model sources and test duplicate-key resilience."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HARNESS = r"""
import Foundation

enum L10n {
    static func string(_ key: String) -> String { key }
    static func format(_ key: String, _ argument: String) -> String { argument }
}

struct Album { let name: String }
struct Artist { let name: String }
struct Song {
    let id: Int
    let name: String
    let album: Album?
    let artists: [Artist]
    let durationMS: Int
}

@main
enum LyricDuplicateRegression {
    static func main() {
        let line = LyricLine(time: 2, text: "same")
        let duplicates = [
            line,
            LyricLine(time: 2, text: "same"),
            LyricLine(time: 2, text: "same"),
        ]
        let ids = duplicates.withUniqueIDs().map(\.id)
        precondition(ids == [line.id, "\(line.id)#1", "\(line.id)#2"])
        precondition(duplicates.withUniqueIDs().map(\.text) == duplicates.map(\.text))

        let collision = [
            LyricLine(id: "x", time: 0, text: "first"),
            LyricLine(id: "x#1", time: 1, text: "reserved suffix"),
            LyricLine(id: "x", time: 2, text: "duplicate"),
        ].withUniqueIDs()
        precondition(collision.map(\.id) == ["x", "x#1", "x#2"])

        let resolved = ResolvedLyrics(
            source: .netease,
            quality: .neteaseLineSynchronized,
            lines: duplicates,
            isPureMusic: false
        )
        precondition(Set(resolved.lines.map(\.id)).count == resolved.lines.count)
        precondition(resolved.lines.map(\.text) == duplicates.map(\.text))

        let values: [String: Int] = Dictionary(
            keepingFirst: [("duplicate", 1), ("duplicate", 2), ("other", 3)]
        )
        precondition(values == ["duplicate": 1, "other": 3])
        let empty: [String: Int] = Dictionary(keepingFirst: [])
        precondition(empty.isEmpty)
        print("PASS: duplicate lyric IDs, suffix collisions, resolved lyrics, and mapping keys")
    }
}
"""


class LyricDuplicateKeyTests(unittest.TestCase):
    def test_production_lyric_models(self):
        xcrun = shutil.which("xcrun")
        swiftc = shutil.which("swiftc")
        if xcrun:
            compiler = [xcrun, "swiftc"]
        elif swiftc:
            compiler = [swiftc]
        else:
            self.skipTest("Swift compiler is unavailable")

        with tempfile.TemporaryDirectory() as directory:
            harness = Path(directory) / "LyricDuplicateHarness.swift"
            executable = Path(directory) / "lyric-duplicate-checks"
            harness.write_text(HARNESS, encoding="utf-8")
            result = subprocess.run(
                compiler + [
                    "-swift-version", "5", "-parse-as-library",
                    str(ROOT / "MeloX/Core/Lyrics/LyricModels.swift"),
                    str(ROOT / "MeloX/Core/Lyrics/LyricSourceModels.swift"),
                    str(harness), "-o", str(executable),
                ],
                capture_output=True, text=True, timeout=90,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run(
                [str(executable)], capture_output=True, text=True, timeout=15
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("PASS:", result.stdout)


if __name__ == "__main__":
    unittest.main()
