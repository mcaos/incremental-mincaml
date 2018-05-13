open Annotast
open Typing

(*
   Prove di annotazioni
 *)

(* type hash_annot = H of int
 * let string_of_hash (H(n)) = string_of_int n
 * let string_of_hashtype (H(n),t) = Printf.sprintf "%d - %s" n (Type.string_of_type t) *)

let external_signatures = [
    "print_int" , Type.Fun([Type.Int], Type.Unit) ;
    "print_newline" , Type.Fun([Type.Unit], Type.Unit) ;
  ]

(*
let string_of_type (_,t) = Printf.sprintf "%s" (Type.string_of_type t)
 *)
let string_of_type ppf (_,t) = Type.type_ppf ppf t

let analyzeExpr (file : string) =
  Printf.printf "Analyzing: %s ...\n" file;
  let channel = open_in file in
  let lexbuf = Lexing.from_channel channel in
  let e = Parser.exp Lexer.token lexbuf in
  try
    let te = Typing.f e in
    print_string (Annotast.string_of_annotast string_of_type te);
    print_string "\n\n"
  with Typing.TypeError _ ->
        print_string (Annotast.string_of_annotast (fun _ _ -> ()) e);
        print_newline ()


let _ =
  Typing.extenv := M.add_list external_signatures M.empty;
  if Array.length Sys.argv > 1 then
    Array.iteri (fun i exp -> if i > 0 then analyzeExpr exp else ()) Sys.argv
  else
    Printf.eprintf "Usage:\n %s file1.ml file2.ml ... fileN.ml\n" Sys.argv.(0)
