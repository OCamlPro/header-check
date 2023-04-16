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

type config = {
  ignore_headers : StringSet.t;
  ignore_dirs : StringSet.t ;
  ignore_files : StringSet.t;

  ml_extensions : StringSet.t ;
  cc_extensions : StringSet.t ;
  sh_extensions : StringSet.t ;
  ignore_extensions : StringSet.t ;
}

val initial : config
val empty : config

val load : config -> string -> config

val filename : string
val filename_bis : string

val show : unit -> unit
