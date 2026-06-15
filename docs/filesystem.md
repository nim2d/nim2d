# Files

Reading and writing files goes through `n2d.fs`, a small virtual filesystem. It knows two places. The save directory is the one writable spot, meant for save games and settings, and it lives in the per-user location the operating system sets aside for your program. The source directory is read-only and is the directory the executable lives in, which is where the assets you ship live.

Before you can write saves you set an identity, which picks the save directory's folder names. Do this once near the start.

```nim
n2d.fs.setIdentity("mygame")
# or with an organization name as well:
n2d.fs.setIdentity("mystudio", "mygame")
```

[`write`](api/filesystem.md#write) and [`append`](api/filesystem.md#append) put data in the save directory, creating any missing folders along the way. [`read`](api/filesystem.md#read) returns a whole file as a string, and [`lines`](api/filesystem.md#lines) walks it a line at a time. Reading searches the save directory first, then the source directory, then anything you mounted, so a file you have saved shadows the one you shipped.

```nim { .annotate }
n2d.fs.write("save.txt", "level 3\nscore 1200")  # (1)!
if n2d.fs.exists("save.txt"):                     # (2)!
  for line in n2d.fs.lines("save.txt"):           # (3)!
    echo line
```

1.  Writes the file in the save directory, creating folders as needed.
2.  True when a file by that name exists in any search location.
3.  Walks the file one line at a time.

[`mount`](api/filesystem.md#mount) adds another directory to search when reading and [`unmount`](api/filesystem.md#unmount) removes it. [`getDirectoryItems`](api/filesystem.md#getDirectoryItems) lists the names in a directory across every search location with duplicates removed, [`createDirectory`](api/filesystem.md#createDirectory) makes a folder in the save directory, [`remove`](api/filesystem.md#remove) deletes a file or an empty folder from it, and [`getInfo`](api/filesystem.md#getInfo) reports a name's kind, size and modification time, as an `Option[`[`FileInfo2d`](api/filesystem.md#FileInfo2d)`]` from `std/options` that is `none` when nothing by that name exists.

Names are always relative and stay inside the sandbox, so a name with a leading slash or a `..` in it is refused rather than reaching outside the save and source directories. [`getSaveDirectory`](api/filesystem.md#getSaveDirectory) and [`getSourceDirectory`](api/filesystem.md#getSourceDirectory) tell you where those two places actually are on disk.

!!! info "See also"
    The runnable [`filesystem` example](https://github.com/nim2d/nim2d/blob/master/examples/filesystem.nim), and the [`filesystem` API reference](api/filesystem.md).
