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

open EzCompat
open Ez_file.V1

type config = {
  ignore_headers : StringSet.t;
  ignore_dirs : StringSet.t ;
  ignore_files : StringSet.t;

  ml_extensions : StringSet.t ;
  cc_extensions : StringSet.t ;
  sh_extensions : StringSet.t ;
  ignore_extensions : StringSet.t ;
}

let ignore_dirs = [
  "_obuild" ; "_build" ; ".git" ; ".svn" ; "_opam"
]

let filename = ".ocp-check-headers"
let filename_bis = ".ocp-check-headers-more"

let ignore_files = [
  filename ;
  filename_bis ;
  "opam";
  "url";
  "descr";
  "_tags"; "_oasis";
  "meta";
  "readme"; "todo";
  "license";
  "authors";  "copying"; "changes";
  "check-headers.undo";
  "dune" ; "dune-project" ;
]


let ml_extensions = [
  ".ml" ; ".mli" ; ".mll" ; ".ocp" ; ".ocp2" ; ".mlp" ; ".ml4"
                    ]
let c_extensions = [
  ".c" ; ".h" ; ".cpp" ; ".mly" ; ".js"
]
let sh_extensions = [
  ".sh" ; ".ac" ; ".in" ; ".m4"
]
let ignore_extensions = [
  "" ;
  ".cmo" ; ".cmi" ; ".cmxs" ; ".cmxa" ; ".cma"
  ; ".cmt" ; ".cmti" ; ".cmx" ; ".annot"

  ; ".opam" ; ".locked"

  ; ".toml" ; ".mlt"

  ; ".mlmods" ; ".mlimods" ; ".mlpp" ; ".mlipp"
  ; ".asm" ; ".byte" ; ".native" ; ".out"

  ; ".mllib" ; ".mldylib" ; ".odocl"

  ; ".so" ; ".o" ; ".a"
  ; ".exe" ; ".dll"

  ; ".log" ; ".status"
  ; ".md" ; ".txt" ; ".tex" ; ".plot"
  ; ".html" ; ".css" ; ".xml" ; ".dtd" ; ".sgml"
  ; ".el"
  ; ".png" ; ".jpg" ; ".jpeg" ; ".git"
  ; ".old"
  ; ".gz" ; ".pdf"

]

let empty = {
  ignore_headers = StringSet.empty ;
  ignore_dirs = StringSet.empty ;
  ignore_files = StringSet.empty ;

  ml_extensions = StringSet.empty ;
  cc_extensions = StringSet.empty ;
  sh_extensions = StringSet.empty ;
  ignore_extensions = StringSet.of_list [ "" ] ;
}

let initial = {
  ignore_headers = StringSet.empty ;
  ignore_dirs = StringSet.of_list ignore_dirs ;
  ignore_files = StringSet.of_list ignore_files ;

  ml_extensions = StringSet.of_list ml_extensions ;
  cc_extensions = StringSet.of_list c_extensions ;
  sh_extensions = StringSet.of_list sh_extensions ;
  ignore_extensions = StringSet.of_list ignore_extensions ;
}

let load initial filename =
  let lines = EzFile.read_lines_to_list filename in

  let rec iter config lines =
    match lines with
      [] -> config
    | line :: lines ->
      let line = String.lowercase line in
      let line = String.map (function
            '\t' -> ' '
          | c -> c) line in
      match EzString.split_simplify line ' ' with
      | [] -> iter config lines
      | prefix :: set ->
        if prefix.[0] = '#' then
          iter config lines
        else
          let set = StringSet.of_list set in
          let config =
            match prefix with
            | "ignore-dirs" ->
              { config with ignore_dirs = StringSet.union config.ignore_dirs set }
            | "ignore-files" ->
              { config with ignore_files = StringSet.union config.ignore_files set }
            | "ignore-headers" ->
              { config with ignore_headers = StringSet.union config.ignore_headers set }
            | "ignore-ext" ->
              { config with ignore_extensions = StringSet.union config.ignore_extensions set }
            | "ml-ext" ->
              { config with ml_extensions = StringSet.union config.ml_extensions set }
            | "cc-ext" ->
              { config with cc_extensions = StringSet.union config.cc_extensions set }
            | "sh-ext" ->
              { config with sh_extensions = StringSet.union config.sh_extensions set }
            | _ ->
              Printf.eprintf "Error in config file %S at line:\n" filename ;
              Printf.eprintf "> %s\n%!" line;
              exit 2
          in
          iter config lines
  in
  iter initial lines

let show () =

  let rec split name list =
    match list with
    | [] -> [ "" ]
    | a :: b :: c :: d  :: e :: list ->
      Printf.sprintf "%s %s" name
        ( String.concat " " [ a ; b ; c ; d ; e  ] )
      :: split name list
    | _ ->
      [ Printf.sprintf "%s %s" name ( String.concat " " list ) ; "" ]
  in

  let set comment name set =
    String.concat "\n" (
      Printf.sprintf "# %s" comment ::
      split name ( StringSet.to_list set ))
  in

  Printf.printf "%s\n%!"
    ( String.concat "\n" [

          set "directories to ignore" "IGNORE-DIRS" initial.ignore_dirs ;

          set "files to ignore" "IGNORE-FILES" initial.ignore_files ;

          set "extensions to ignore" "IGNORE-DIRS" initial.ignore_extensions ;

          set "headers to ignore" "IGNORE-HEADERS" initial.ignore_headers ;

          set "extensions for ML files" "ML-EXT" initial.ml_extensions ;

          set "extensions for C/C++ files" "CC-EXT" initial.cc_extensions ;

          set "extensions for SH files" "SH-EXT" initial.ml_extensions ;

        ] )
