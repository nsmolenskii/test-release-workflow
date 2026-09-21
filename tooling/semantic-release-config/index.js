/**
 * Release behaviour shared by every pack in this repository.
 *
 * A pack opts in with nothing but:
 *   { "extends": ["semantic-release-monorepo", "@demo/semantic-release-config"] }
 *
 * semantic-release-monorepo scopes a run to that pack's directory and derives
 * its tag prefix from the pack's package.json name. Everything else is here.
 */

/**
 * The commit vocabulary, and the only place it is defined. `release` is the
 * bump a type earns; `section` is its heading in the release notes, and a type
 * with no section is hidden from them.
 *
 * A pack's prose is its product, so rewording a skill is a `refactor` when the
 * guidance is restructured and a `fix` when it was wrong. `docs` is for the
 * repository's own prose and ships nothing.
 */
const VOCABULARY = [
  { type: 'feat', release: 'minor', section: 'Added' },
  { type: 'fix', release: 'patch', section: 'Fixed' },
  { type: 'refactor', release: 'patch', section: 'Changed' },
  { type: 'docs', release: false },
  { type: 'chore', release: false },
  { type: 'ci', release: false },
  { type: 'test', release: false },
  { type: 'build', release: false },
  { type: 'style', release: false },
  { type: 'perf', release: false },
  { type: 'revert', release: false },
];

module.exports = {
  branches: ['master'],
  plugins: [
    [
      '@semantic-release/commit-analyzer',
      {
        preset: 'conventionalcommits',
        // Breaking is listed first so `feat!`, `fix!` and a BREAKING CHANGE
        // footer still reach major instead of matching their type rule below.
        releaseRules: [
          { breaking: true, release: 'major' },
          ...VOCABULARY.map(({ type, release }) => ({ type, release })),
        ],
      },
    ],
    [
      '@semantic-release/release-notes-generator',
      {
        preset: 'conventionalcommits',
        presetConfig: {
          types: VOCABULARY.map(({ type, section }) =>
            section ? { type, section } : { type, hidden: true }
          ),
        },
      },
    ],
    ['@semantic-release/changelog', { changelogFile: 'CHANGELOG.md' }],
    [
      '@semantic-release/exec',
      {
        prepareCmd:
          "jq --arg v '${nextRelease.version}' '.version = $v' .claude-plugin/plugin.json > .plugin.tmp.json && mv .plugin.tmp.json .claude-plugin/plugin.json",
      },
    ],
    [
      '@semantic-release/git',
      {
        assets: ['CHANGELOG.md', 'package.json', '.claude-plugin/plugin.json'],
        message: 'chore(release): ${nextRelease.gitTag} [skip ci]',
        gitUserName: 'Demo Release Bot',
        gitUserEmail: 'release-bot@example.com',
      },
    ],
    '@semantic-release/github',
  ],
};
