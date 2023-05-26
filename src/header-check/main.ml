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
open Config

type header_sep = {
  sep_name : string;
  sep_regexp : Str.regexp;
  sep_add_line : int; (* add the header at this line by default *)
  mutable sep_headers : header list;
}

and header = {
  header_id : string;
  header_lines : string list;
  header_sep : header_sep;
  mutable header_files : (int * file) list;
}

and file = {
  file_name : string;
  file_headers : (int * header) list; (* position x header *)
}

type env = {
  headers : (string, header) Hashtbl.t;
  mutable files : (string, file) Hashtbl.t;
  mutable save_to_ignore : StringSet.t;
  skip_dirs : StringSet.t;
}

let homedir = try
    Sys.getenv "HOME"
  with Not_found -> "/"
let config_dir = Filename.concat homedir ".ocp/check-headers"

let max_header_lines = ref 30
let min_char_repetition = ref 50

let stars = String.concat "" (
    Array.to_list (Array.init !min_char_repetition (fun _ -> "\\*")))
let spaces = "[\t ]*"
let new_header_sep ?(sep_add_line=0) sep_name sep_regexp =
  { sep_name;
    sep_regexp = Str.regexp sep_regexp;
    sep_headers = [];
    sep_add_line;
  }

(* Morally, these structures should be in [env], as they are modified
   during the scan. Instead, we reset them at the beginning of
   [scan_dirs].
*)
let ml_header = new_header_sep  "ML Header" (spaces ^ "(" ^ stars)
let cc_header = new_header_sep "C header" (spaces ^ "/" ^ stars)
let sh_header = new_header_sep ~sep_add_line:2 "Shell header"
    (spaces ^ String.make !min_char_repetition '#')

let reset_headers env =
  List.iter (fun sep ->
    List.iter (fun h ->
      h.header_files <- []
    )
      sep.sep_headers) [
    ml_header; cc_header; sh_header
  ];
  Hashtbl.clear env.files

let is_header_sep line header_sep =
  Str.string_match header_sep.sep_regexp line 0

let new_header_id s = Digest.to_hex (Digest.string s)

let new_header env config header_sep header_pos header_lines  =
  let header = String.concat " " header_lines in
  let header_id = new_header_id header in
  if StringSet.mem header_id config.ignore_headers then
    []
  else
    let h =
      try
        Hashtbl.find env.headers header_id
      with Not_found ->
        let h = {
          header_sep;
          header_id;
          header_lines;
          header_files = [];
        } in
        Hashtbl.add env.headers header_id h;
        header_sep.sep_headers <- h :: header_sep.sep_headers;
        h
    in
    [header_pos, h]

let read_headers env config lines header_sep =
  let rec iter_out pos lines headers =
    match lines with
    | [] -> List.rev headers
    | line :: lines ->
      if is_header_sep line header_sep then
        iter_in (pos+1) lines pos [line] headers
      else
        iter_out (pos+1) lines headers
  and iter_in pos lines header_pos header_lines headers =
    match lines with
    | [] -> (* abort header *)
      List.rev headers
    | line :: lines ->
      if is_header_sep line header_sep then
        let header_lines = List.rev (line :: header_lines) in
        let header = new_header env config header_sep header_pos header_lines in
        iter_out (pos+1) lines (header @ headers)
      else
      if pos - header_pos > !max_header_lines then (* not a header *)
        iter_out (pos+1) lines headers
      else
        iter_in (pos+1) lines header_pos (line :: header_lines) headers
  in
  iter_out 0 lines []

let record_header ?(from_config=false) env config file_name header_sep =
  let lines = EzFile.read_lines_to_list file_name in
  let file_headers = read_headers env config lines header_sep in
  let file = {
    file_name;
    file_headers;
  } in
  Hashtbl.add env.files file_name file;
  let file_headers = match file_headers with
    | [] ->
      (* We create a specific header for no-header. This specific header has
             its id generated from the name of the header_sep, because we want
             each header_sep to have a different set of no-header files. *)
      new_header env config header_sep 0 [ header_sep.sep_name ]
    | _ -> file_headers in
  if not from_config then
    List.iter (fun (header_pos, header) ->
      header.header_files <- (header_pos, file) :: header.header_files
    ) file_headers


let rec scan_dir env config dir =
  let files =
    if StringSet.mem dir env.skip_dirs then
      [||]
    else
      Sys.readdir dir
  in

  let config =
    let dirfile = Filename.concat dir Config.filename in
    if Sys.file_exists dirfile then
      Config.load config dirfile
    else config
  in

  Array.iter (fun file ->
      let lfile = String.lowercase file in
      if not ( StringSet.mem lfile config.ignore_dirs ) &&
         match lfile.[0] with
         | '.' | '_' | '#' -> false
         | _ -> true
      then
        let dirfile = Filename.concat dir file in
        match
          try Some ( Sys.is_directory dirfile ) with
          | _ -> None
        with
        | None -> ()
        | Some false ->
          if not ( StringSet.mem lfile config.ignore_files ) then
            check_file env config lfile dirfile
        | Some true ->
          if Sys.file_exists
              (Filename.concat dirfile ".header-check-stop") then
            ()
          else
            scan_dir env config dirfile
    ) files

and check_file env config lfile dirfile =
  let len = String.length lfile in
  if lfile.[len-1] <> '~' &&
     match lfile.[0] with
     | '.' | '_' | '#' -> false
     | _ -> true
  then
    let ext = try
        let pos = String.rindex lfile '.' in
        String.sub lfile pos (len-pos)
      with _ -> ""
    in

    if not ( StringSet.mem ext config.ignore_extensions ) then
      if StringSet.mem ext config.ml_extensions then
        record_header env config dirfile ml_header
      else
      if StringSet.mem ext config.cc_extensions then
        record_header env config dirfile cc_header
      else
      if StringSet.mem ext config.sh_extensions then
        record_header env config dirfile sh_header
      else
        match lfile with
        | "configure" | "makefile" ->
          record_header env config dirfile sh_header
        | _ ->
          if not (
              StringSet.mem lfile env.save_to_ignore
            ) then begin
            env.save_to_ignore <- StringSet.add lfile env.save_to_ignore;
            Printf.eprintf "Warning: unknown extension %S for file %S\n%!"
              ext dirfile;
          end

let scan_dirs env config dirs =

  (* do not clear headers, clear their positions instead *)
  reset_headers env;

  List.iter (fun (file, header_sep) ->
    let dirfile = Filename.concat config_dir file in
    if Sys.file_exists dirfile then
      record_header ~from_config:true env config dirfile header_sep
  ) [ "headers.ml", ml_header;
      "headers.cc", cc_header;
      "headers.sh", sh_header];

  List.iter (fun dir ->
    if Sys.is_directory dir then
      scan_dir env config dir
    else
      let lfile = String.lowercase (Filename.basename dir) in
      check_file env config lfile dir
  ) dirs;
  ()

let fprintf_loc oc file_name line_pos =
  Printf.fprintf oc "File %S, line %d, characters 0-1:\n" file_name line_pos


let print_headers skip_headers sep file_name =
  if sep.sep_headers <> [] then begin
    let oc = open_out file_name in
    Printf.fprintf oc "Report on %s\n" sep.sep_name;

    if sep.sep_headers <> [] then begin

      Printf.fprintf oc "\nExtracted headers\n";

      List.iter (fun header ->
        if not (StringSet.mem header.header_id skip_headers) then begin
          Printf.fprintf oc "\nHeader id: %s\n" header.header_id;
          if header.header_lines = [ header.header_sep.sep_name ] then begin
            Printf.fprintf oc "\n\n\n\n         EMPTY HEADER\n\n\n\n\n";
          end else begin
            Printf.fprintf oc "<<<\n";
            List.iter (fun line ->
                Printf.fprintf oc "   %s\n" line;
              ) header.header_lines;
            Printf.fprintf oc ">>>\n";
          end;
          List.iter (fun (line_pos, file) ->
              fprintf_loc oc file.file_name line_pos;
              Printf.fprintf oc "Warning: file with %d headers\n%!"
                (List.length file.file_headers)
          ) header.header_files;
        end
        ) sep.sep_headers;

    end;
    close_out oc;
    Printf.printf "File %S generated\n%!" file_name;
  end



let save_ignored env =
  if env.save_to_ignore <> StringSet.empty then begin
    let oc = open_out Config.filename_bis in
    StringSet.iter (fun line ->
      Printf.fprintf oc "IGNORE-FILES %s\n" line) env.save_to_ignore;
    close_out oc;
    Printf.eprintf "Ignored files saved to %s\n%!" Config.filename_bis;
    Printf.eprintf "You can add it to your %s\n%!" Config.filename

  end

let rec remove_empty_lines lines =
  match lines with
    "" :: lines -> remove_empty_lines lines
  | lines -> lines

let replace_header src_header dst_header line_pos file =
  Printf.printf "Replacing %s by %s on %s\n%!" src_header.header_id
    dst_header.header_id file.file_name;
  let lines = EzFile.read_lines_to_list file.file_name in
  let rec insert_header pos lines rev_lines =
    if pos = line_pos then
      check_src_header lines src_header.header_lines rev_lines
    else
      match lines with
      | [] ->
        Printf.eprintf "Error: header %s not found in %S (EOF before pos)\n%!"
          src_header.header_id file.file_name;
        raise Not_found
      | line :: lines ->
        insert_header (pos+1) lines (line :: rev_lines)

  and check_src_header lines header_lines rev_lines =
    match lines, header_lines with
    | _, [] -> (List.rev rev_lines) @ dst_header.header_lines @
      ("" :: remove_empty_lines lines)
    | [], _ ->
      Printf.eprintf "Error: header %s not found in %S (truncated header)\n%!"
        src_header.header_id file.file_name;
      raise Not_found
    | left :: lines, right :: header_lines ->
      if left <> right then begin
        Printf.eprintf "Error: header %s not found in %S (line mismatch)\n%!"
          src_header.header_id file.file_name;
        raise Not_found
      end;
      check_src_header lines header_lines rev_lines
  in
  try
    let lines = insert_header 0 lines [] in
    EzFile.write_lines_of_list file.file_name lines;
    true
  with Not_found -> false

let add_default_header header file =
  Printf.printf "Adding header %s on %s\n%!" header.header_id file.file_name;
  (* This is the easiest one *)
  let sep = header.header_sep in
  let lines = EzFile.read_lines_to_list file.file_name in
  let rec insert_header pos lines rev_lines =
    if pos = sep.sep_add_line then
      (List.rev rev_lines) @ header.header_lines @ (
        "" :: remove_empty_lines lines)
    else
      match lines with
      | [] -> (List.rev rev_lines) @ header.header_lines @ [""]
      | line :: lines ->
        insert_header (pos+1) lines (line :: rev_lines)
  in
  let lines = insert_header 0 lines [] in
  EzFile.write_lines_of_list file.file_name lines;
  true

type args = {
  mutable arg_add_default : string list;
  mutable arg_dirs : string list; (* reverse order *)
  mutable arg_replace : string list;
}

let undo_oc = ref None

let get_undo_oc () =
  match !undo_oc with
  | None ->
    let oc = open_out "check-headers.undo" in
    undo_oc := Some oc;
    oc
  | Some oc -> oc

let init_action args env config =

  let dirs = List.rev args.arg_dirs in

  scan_dirs env config dirs;
  save_ignored env;
  ()



let do_actions args env config =

  if args.arg_add_default <> [] then
    List.iter (fun header_id ->
        try
          let header = Hashtbl.find env.headers header_id in
          let sep = header.header_sep in
          let empty_header_id = new_header_id sep.sep_name in
          try
            let empty_header = Hashtbl.find env.headers empty_header_id in
            let updates = ref 0 in
            List.iter (fun (_, file) ->
                if add_default_header header file then begin
                  Printf.fprintf (get_undo_oc ())
                    "add:%s:%s\n" header_id file.file_name;
                  incr updates
                end
              ) empty_header.header_files;
            Printf.printf "add_default %s: %d files changed\n%!"
              header_id !updates;
            if !updates > 0 then begin
              Printf.printf
                "Scanning again after %d changes for %s\n%!" !updates
                header_id;
              let dirs = List.rev args.arg_dirs in
              scan_dirs env config dirs
            end
          with Not_found ->
            Printf.printf "add-default %s: no file with no header\n%!"
              header_id
        with Not_found ->
          Printf.eprintf "Error: default header %s not found\n%!" header_id
      ) (List.rev args.arg_add_default);

  if args.arg_replace <> [] then
    List.iter (fun header_pair ->
        let src_id, dst_id = try
            let pos = String.index header_pair ':' in
            let len = String.length header_pair in
            String.sub header_pair 0 pos,
            String.sub header_pair (pos+1) (len-pos-1)
          with Not_found ->
            Printf.eprintf "Error: cannot parse pair %S\n%!" header_pair;
            exit 2
        in
        let src_header = try
            Hashtbl.find env.headers src_id
          with Not_found ->
            Printf.eprintf "Error: source header of %S not found\n%!" header_pair;
            exit 2
        in
        let src_sep = src_header.header_sep in
        let dst_header = try
            Hashtbl.find env.headers dst_id
          with Not_found ->
            Printf.eprintf "Error: destination header of %S not found\n%!" header_pair;
            exit 2
        in
        let dst_sep = dst_header.header_sep in

        if dst_sep != src_sep then begin
          Printf.eprintf "Error: %s and %s of different kind\n%!"
            src_id dst_id;
          exit 2
        end;
        let updates = ref 0 in
        List.iter (fun (line_pos, file) ->
            if replace_header src_header dst_header line_pos file then begin
              incr updates;
              Printf.fprintf (get_undo_oc ())
                "replace:%s:%d:%s:%s\n" src_id line_pos dst_id file.file_name;
            end
          ) src_header.header_files;
        Printf.printf "replace %s: %d files changed\n%!"
          src_id !updates;
        if !updates > 0 then begin
          Printf.printf
            "Scanning again after %d changes for %s\n%!" !updates
            src_id;
          let dirs = List.rev args.arg_dirs in
          scan_dirs env config dirs
        end
      ) (List.rev args.arg_replace)

let new_args () = {
  arg_add_default = [];
  arg_replace = [];
  arg_dirs = [];
}

let ml_headers_file = "headers-ml.txt"
let cc_headers_file = "headers-cc.txt"
let sh_headers_file = "headers-sh.txt"

let () =

  let args = new_args () in
  let arg_replace_by = ref None in
  let arg_skip_headers = ref StringSet.empty in
  let arg_empty_config = ref false in
  let arg_clean = ref false in
  let arg_show_config = ref false in

  let skip_dirs = ref StringSet.empty in

  let arg_list = Arg.align [
      "--empty-config", Arg.Set arg_empty_config,
      " Start with an empty config (and read local config files)";

      "--skip-dir", Arg.String
        (fun s -> skip_dirs := StringSet.add s !skip_dirs),
      "DIR Skip directory dir";

      "--show-config", Arg.Set arg_show_config,
      " Show the default configuration and exit" ;

      "--clean", Arg.Set arg_clean,
      " Remove generated files and exit" ;

      "--add-default", Arg.String (fun s ->
          args.arg_add_default <- s :: args.arg_add_default),
      "HEADER_ID Add this header as the default for these files";

      "--replace", Arg.String (fun s ->
          args.arg_replace <-
            EzString.split s ',' @ args.arg_replace),
      "SRC:DST Replace header SRC by header DST";

      "--replace-by", Arg.String (fun s ->
          arg_replace_by := Some s),
      "HEADER_ID Replace by this header";

      "--from", Arg.String (fun src_id ->
          match !arg_replace_by with
          | None ->
            Printf.eprintf "Error: --from should come after --replace-by\n%!";
            exit 2
          | Some dst_id ->
            List.iter (fun id ->
                args.arg_replace <-
                  (Printf.sprintf "%s:%s" id dst_id) :: args.arg_replace
              ) (EzString.split src_id ':')
        ),
      "HEADER_ID Replace this header";
      "--skip", Arg.String (fun id ->
          arg_skip_headers := StringSet.add id !arg_skip_headers),
      "HEADER_ID skip this header when printing headers";

    ] in
  let arg_usage =
    "header-check [OPTIONS] DIRS : check OCaml headers in DIRS" in
  Arg.parse arg_list (fun dir ->
      args.arg_dirs <- dir :: args.arg_dirs) arg_usage;
  if args.arg_dirs = [] then args.arg_dirs <- ["."];

  if !arg_show_config then begin

    Config.show ();
    exit 0
  end;

  if !arg_clean then begin
    List.iter (fun file ->
        if Sys.file_exists file then begin
          Printf.eprintf "Removing file %S\n%!" file;
          Sys.remove file
        end
      ) [
      Config.filename_bis ;
      ml_headers_file ;
      cc_headers_file ;
      sh_headers_file ;
    ] ;
    exit 0
  end;

  let config =
    let config =
      if !arg_empty_config then
        Config.empty
      else
        Config.initial
    in
    if Sys.file_exists Config.filename then
      Config.load config Config.filename
    else
      config
  in
  let env = {
    headers = Hashtbl.create 113;
    files = Hashtbl.create 113;
    save_to_ignore = StringSet.empty;
    skip_dirs = !skip_dirs ;
  } in
  init_action args env config;
  do_actions args env config;

  begin match !undo_oc with
    | None -> ()
    | Some oc -> close_out oc
  end;

  print_headers !arg_skip_headers ml_header ml_headers_file ;
  print_headers !arg_skip_headers cc_header cc_headers_file ;
  print_headers !arg_skip_headers sh_header sh_headers_file ;
  ()
