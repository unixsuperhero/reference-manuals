---
title: git bundle
tags:
  - git
  - cli
  - backup
---

`git bundle` packs a repository's history into one ordinary file. The file is a
self-contained archive of commits, trees, blobs and refs that any `git` can
clone from or fetch from, with no server and no network. Think of it as a
packfile with a table of contents stapled to the front.

Use it when you want history to survive outside the repository: an offline
backup, moving a repo across an air gap, mailing a change set, or, as on
2026-10-24, keeping the history of a repository you are about to delete.

## The worked case: the home directory repo

`~` was itself a git repository (remote `home.git`) that had not been pushed in
six months and had 29 local commits. Before `rm -rf ~/.git`, its whole history
went into one file on the backup volume:

```sh
cd ~
git bundle create /Volumes/yaba/backups/home-dotfiles-2026-10-24.bundle --all
git bundle verify /Volumes/yaba/backups/home-dotfiles-2026-10-24.bundle
rm -rf ~/.git
```

`--all` means every ref: all branches, all tags, and `HEAD`. The result was
824 MB, about the size of the packfile it came from. `verify` printed
`The bundle records a complete history.`, which is the line that makes the
deletion safe.

To get it back, in whole, into a new directory:

```sh
git clone /Volumes/yaba/backups/home-dotfiles-2026-10-24.bundle ~/tmp/home-history
cd ~/tmp/home-history && git log --oneline | head
```

To pull one file out of it without cloning the working tree:

```sh
git clone --bare /Volumes/yaba/backups/home-dotfiles-2026-10-24.bundle /tmp/home.git
git -C /tmp/home.git show main:.config/nvim/init.lua > init.lua.old
```

## Commands

| Command | What it does |
|---|---|
| `git bundle create FILE REFS...` | Write the objects reachable from REFS into FILE. REFS is anything `git rev-list` accepts: `--all`, `main`, `v1.2..main`, `HEAD~10..HEAD`. |
| `git bundle verify FILE` | Check the file is intact and report which commits it needs you to already have (its prerequisites). Exit 0 means a clone or fetch will work. |
| `git bundle list-heads FILE [REFS]` | Print the refs the bundle carries. |
| `git bundle unbundle FILE [REFS]` | Low level: put the objects into the current repository and print the refs. `fetch` and `clone` call this for you. |
| `git clone FILE DIR` | Clone from a bundle exactly as from a URL. The bundle becomes `origin`. |
| `git fetch FILE REF:REF` | Fetch refs from a bundle into an existing repository. |
| `git pull FILE main` | Fetch and merge from a bundle. |

A bundle is a valid remote, so `git remote add backup /path/to/file.bundle`
works too, and `git fetch backup` then reads from the file.

## Full bundle vs incremental bundle

A full bundle has no prerequisites: it records a complete history and can be
cloned anywhere.

```sh
git bundle create full.bundle --all
```

An incremental bundle carries only the commits after a known point. It is small,
but it can only be applied to a repository that already has that point.

```sh
git bundle create since-v1.2.bundle v1.2..main
git bundle verify since-v1.2.bundle   # lists v1.2's commit as a prerequisite
```

Chaining them is the classic sneakernet workflow: a full bundle once, then one
incremental bundle per trip, each from the last commit the other side has.

```sh
# the side that sends
git bundle create trip-3.bundle last-sent..main
git tag -f last-sent main

# the side that receives
git fetch trip-3.bundle main:refs/remotes/trip/main
git merge trip/main
```

## What goes in, what does not

- Commits, trees, blobs, tags and the refs named on the command line. `--all`
  takes every ref under `refs/` plus `HEAD`.
- Not the working tree, not the index, not uncommitted changes. In the home
  repo case the 17,472 uncommitted modifications were never in the bundle; the
  files on disk simply stayed where they were.
- Not hooks, not `.git/config`, not remotes, not stashes (stashes live under
  `refs/stash`, which `--all` does include as a single ref, but their
  reflog is not carried).
- Not reflogs. A bundle is history as the refs see it today.

## Size and speed

A full bundle is roughly the size of a fresh `git gc` of the same repo, because
it is one packfile plus a header. Creating one is as slow as packing; for the
824 MB home repo it took under a minute on an SSD. `verify` is fast, since it
reads the header and checks prerequisites rather than unpacking everything.

To keep a bundle small, name a range rather than `--all`, or exclude large
history you no longer need with `--since` style ranges such as
`$(git rev-list -n1 --before=2025-01-01 main)..main`.

## Comparison with the alternatives

| Need | Use | Why not a bundle |
|---|---|---|
| Keep history after deleting a repo | **bundle** | This is its job. |
| Share a few commits by mail | `git format-patch` | Patches are readable text and apply with `git am`; bundles are binary. |
| Exact copy of `.git` including hooks, config and reflogs | `tar czf repo.tgz .git` | A tarball keeps everything; a bundle keeps only reachable objects. |
| Archive of the files at one commit, no history | `git archive` | Produces a tar or zip of the tree, not of the history. |
| Push over the network | a remote | Bundles are for when there is no server or no network. |

## Pitfalls

- `verify` before you delete anything. A bundle created from a corrupt repo
  verifies as corrupt; a bundle created with a narrow ref list verifies fine
  but holds less than you meant.
- `--all` without `HEAD` is not a problem, but a bundle of only `HEAD` on a
  detached head carries no branch name. Clone it and you get a detached head.
- A bundle is sha1 or sha256, matching the repository it came from. Git prints
  the algorithm in `verify`; a sha256 bundle cannot be fetched into a sha1 repo.
- Large bundles on an exFAT volume are fine; on FAT32 they fail above 4 GB.

## See also

`git help bundle`, `git help rev-list` for the range syntax, and the backup
volume index at `/Volumes/yaba/backups/`.
