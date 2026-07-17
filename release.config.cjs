/**
 * semantic-release config for Line open-source GitHub releases.
 *
 * - Version from Conventional Commits on main
 * - prepare: build Line-<version>.zip/dmg (no Developer ID)
 * - github: full Release (not prerelease) with assets
 * - no npm, no CHANGELOG.md commit
 * - appcast PR is handled by the workflow after publish
 */
module.exports = {
  branches: ["main"],
  tagFormat: "v${version}",
  plugins: [
    [
      "@semantic-release/commit-analyzer",
      {
        preset: "conventionalcommits",
        releaseRules: [
          { type: "feat", release: "minor" },
          { type: "fix", release: "patch" },
          { type: "perf", release: "patch" },
          { type: "revert", release: "patch" },
          { breaking: true, release: "major" },
          { type: "docs", release: false },
          { type: "style", release: false },
          { type: "chore", release: false },
          { type: "refactor", release: false },
          { type: "test", release: false },
          { type: "build", release: false },
          { type: "ci", release: false }
        ],
        parserOpts: {
          noteKeywords: ["BREAKING CHANGE", "BREAKING CHANGES"]
        }
      }
    ],
    [
      "@semantic-release/release-notes-generator",
      {
        preset: "conventionalcommits",
        presetConfig: {
          types: [
            { type: "feat", section: "Features" },
            { type: "fix", section: "Bug Fixes" },
            { type: "perf", section: "Performance" },
            { type: "revert", section: "Reverts" },
            { type: "docs", section: "Documentation", hidden: true },
            { type: "chore", section: "Maintenance", hidden: true },
            { type: "refactor", section: "Maintenance", hidden: true },
            { type: "test", section: "Tests", hidden: true },
            { type: "build", section: "Build", hidden: true },
            { type: "ci", section: "CI", hidden: true }
          ]
        }
      }
    ],
    [
      "@semantic-release/exec",
      {
        // verifyRelease runs in dry-run and real publishes; prepare is skipped in dry-run.
        verifyReleaseCmd:
          "bash scripts/release/sr_prepare.sh \"${nextRelease.version}\""
      }
    ],
    [
      "@semantic-release/github",
      {
        assets: [
          {
            path: "dist/Line-*.zip",
            label: "Line macOS zip (not Apple-notarized)"
          },
          {
            path: "dist/Line-*.dmg",
            label: "Line macOS dmg (not Apple-notarized)"
          },
          {
            path: "dist/SHA256SUMS.txt",
            label: "SHA-256 checksums"
          }
        ],
        successComment: false,
        failComment: false,
        failTitle: false,
        releasedLabels: false,
        addReleases: "bottom"
      }
    ]
  ]
};
