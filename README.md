
[![Actions Status](https://github.com/ocamlpro/header-check/workflows/Main%20Workflow/badge.svg)](https://github.com/ocamlpro/header-check/actions)
[![Release](https://img.shields.io/github/release/ocamlpro/header-check.svg)](https://github.com/ocamlpro/header-check/releases)

# header-check

This header-check tool uses checksums to manage headers in a software
project. It can list all existing headers, and replace them using checksums
as identifiers.

## Usage

To use, just run:

```
header-check
```

The execution with scan the current directory and sub-directories for
files, extract headers from them and generate 3 reports :

* `headers-ml.txt` for ML files
* `headers-cc.txt` for C/C++ files
* `headers-sh.txt` for SH files

You can then inspect these files to check all the headers present in
the project. For each header, the header is displayed, with a unique
ID (checksum) and a list of locations.

If you are happy, you can then clear temporary files:

```
header-check --clean
```

After inspection, you might want to add a default header to files with
no header:

```
header-check --add-default HEADER_ID
```

Note that only files in the same category as the header can be
modified (i.e. a ML header can only be added to ML files), so that you
can specify this option for every category on the same command.

You might also want to replace some headers by other headers:

```
header-check --replace SRC_ID:DST_ID
```

will replace the source header by the destination header.

Since replacement must always be done using checksums, if you want to
create a new header, you will need to insert it in a file, do a run to
get its identifier, and then replace it.

If you want to replace multiple identifiers by the same identifier,
you can also use:

```
header-check --replace-by DST_ID --from SRC1_ID --from SRC2_ID
```

During the scan, `header-check` uses a default configuration to
ignore or select files. You can extend this configuration using files
`.header-check` in directories (their config will apply to
where they are and their sub-directories). If the default
configuration is wrong for you, you can use the option `--empty` to
start with an empty configuration.

The format of `.header-check` is a list of lines starting
with a command and a list of space-separated case-insensitive entries
(comments can be introduced with # at the beginning of the line):

```
# files to ignore
IGNORE-FILES opam meta

# directories to ignore
IGNORE-DIRS _build .git .svn _opam

# extensions to ignore
IGNORE-EXT .cmx .cmo .mlt .md .toml

# headers to ignore
IGNORE-HEADERS fb748e994094746482684

# extensions for the ML files
ML-EXT .ml .mli .mll .mlp .ml4

# extensions for C/C++ files
CC-EXT .c .h .cpp .mly .js

# extensions for SH files
SH-EXT .sh .ac .in .m4
```

To check the default configuration, use:

```
header-check --show-config
```

Headers are supposed to start and end with the same beginning of line:

```
(************************** for OCaml
/************************** for C-likes
########################### for shells
```

with internal char repeated at least 50 times.

