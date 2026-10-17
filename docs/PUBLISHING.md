# Verified update publishing

Repository: https://github.com/deadclass/Oblivion

The Commander requested: “Please upload any verified updates you make to the Oblivion repository”.

For each development change:

1. Inspect current local source and remote state; preserve unrelated work.
2. Run the relevant regression checks and a source smoke test. Record exact results and limits, not just an exit code.
3. Publish verified source, tests and useful documentation through the linked GitHub account. Do not upload secrets, personal filesystem paths, generated `.godot`/`.artifacts`, local logs, executables or archive bundles as source.
4. Verify the remote commit and file contents before reporting the upload complete.

This baseline uses a separate review branch, `verified/return-relay-mechanics-2026-10-17`, rather than merging the older guarded-weight draft PR or overwriting main. A review branch/PR is the chosen publishing convention for this handoff, not a Commander-approved requirement for every future change. Keep licensing undecided unless the Commander selects a license.
