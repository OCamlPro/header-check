How to use
==========

Collecting headers
------------------


To use, just run::

  $ header-check
  Warning: unknown extension ".rst" for file "./sphinx/install.rst"
  Warning: unknown extension ".rst" for file "./sphinx/index.rst"
  Warning: unknown extension ".rst" for file "./sphinx/usage.rst"
  Warning: unknown extension ".rst" for file "./sphinx/license.rst"
  Warning: unknown extension ".py" for file "./sphinx/conf.py"
  Warning: unknown extension ".rst" for file "./sphinx/about.rst"
  Ignored files saved to .header-check-more
  You can add it to your .header-check
  File "headers-ml.txt" generated
  File "headers-sh.txt" generated

The execution with scan the current directory and sub-directories for
files, extract headers from them and generate 3 reports :

* :code:`headers-ml.txt` for ML files
* :code:`headers-cc.txt` for C/C++ files
* :code:`headers-sh.txt` for SH files

You can then inspect these files to check all the headers present in
the project. For each header, the header is displayed, with a unique
ID (checksum) and a list of locations.

Typically, a report looks like::

  Report on ML Header
  
  Extracted headers
  
  Header id: 5134d42449ef844bc30faac53a02511c
  <<<
  (**************************************************************************)
  (*                                                                        *)
  (*   Typerex Tools                                                        *)
  (*                                                                        *)
  (*   Copyright 2011-2017 OCamlPro SAS                                     *)
  (*                                                                        *)
  (*   All rights reserved.  This file is distributed under the terms of    *)
  (*   the GNU General Public License version 3 described in the file       *)
  (*   LICENSE.                                                             *)
  (*                                                                        *)
  (**************************************************************************)
  >>>
  File "./src/header-check/config.ml", line 0, characters 0-1:
  Warning: file with 1 headers
  File "./src/header-check/config.mli", line 0, characters 0-1:
  Warning: file with 1 headers
  File "./src/header-check/main.ml", line 0, characters 0-1:
  Warning: file with 1 headers

For every header, an identifier is provided using a chechsum, the header
is printed, and all the locations where it was found.

If you are happy, you can then clear temporary files::

  $ header-check --clean
  Removing file ".header-check-more"
  Removing file "headers-ml.txt"
  Removing file "headers-sh.txt"

Modifying headers
-----------------

After inspection, you might want to add a default header to files with
no header::

  header-check --add-default HEADER_ID

Note that only files in the same category as the header can be
modified (i.e. a ML header can only be added to ML files), so that you
can specify this option for every category on the same command.

You might also want to replace some headers by other headers::

  header-check --replace SRC_ID:DST_ID

will replace the source header :code:`SRC_ID` by the destination
header :code:`DST_ID`. You may add directories if you want to restrict
the substitution to these directories.

Since replacement must always be done using checksums, if you want to
create a new header, you will need to insert it in a file, do a run to
get its identifier, and then replace it.

If you want to replace multiple headers :code:`SRC1_ID`,
:code:`SRC2_ID`, ... by the same header :code:`DST_ID`, you can also
use::

  header-check --replace-by DST_ID --from SRC1_ID --from SRC2_ID

Configuring a project
---------------------

During the scan, :code:`header-check` uses a default configuration to
ignore or select files. You can extend this configuration using files
:code:`.header-check` in directories (their config will apply to
where they are and their sub-directories). If the default
configuration is wrong for you, you can use the option :code:`--empty` to
start with an empty configuration.

The format of :code:`.header-check` is a list of lines starting
with a command and a list of space-separated case-insensitive entries
(comments can be introduced with # at the beginning of the line)::

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

To check the default configuration, use::

  header-check --show-config

Header formats
--------------

Headers are recognized as starting and ending with the same beginning
of line::

  (************************** for OCaml
  /************************** for C-likes
  ########################### for shells

with internal char repeated at least 50 times.

Headers can be located anywhere in the file, so it may happens that
comments with such beginning and ending are also recognize as headers.
