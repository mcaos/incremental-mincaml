open Batteries
open Landmark

module OriginalFunAlgorithm = Original.TypeAlgorithm(FunSpecification.FunSpecification)
module IncrementalFunAlgorithm = Incrementalizer.TypeAlgorithm(FunSpecification.FunSpecification)

open FunSpecification.FunSpecification

open Generator
open VarSet

let mem_orig e lo =
  enter lo;
    (* Minimal quantity of memory for non incremental *)
    let initial_gamma_list e = (List.map (fun id -> (id, TInt)) (VarSet.elements (compute_fv e))) in
    let gamma_init = (FunContext.add_list (initial_gamma_list e) (FunContext.get_empty_context ()) ) in
    ignore (OriginalFunAlgorithm.typing gamma_init e);
  exit lo

let mem_inc e li =
  enter li;
    (* Minimal quantity of memory for incremental *)
    let initial_gamma_list e = (List.map (fun id -> (id, TInt)) (VarSet.elements (compute_fv e))) in
    let gamma_init = (FunContext.add_list (initial_gamma_list e) (FunContext.get_empty_context ()) ) in
    let full_cache = IncrementalFunAlgorithm.get_empty_cache 4096 in
    ignore (IncrementalFunAlgorithm.build_cache e gamma_init full_cache);
    ignore (IncrementalFunAlgorithm.typing full_cache gamma_init e);
  exit li

let just_cache e l =
    let initial_gamma_list e = (List.map (fun id -> (id, TInt)) (VarSet.elements (compute_fv e))) in
    let gamma_init = (FunContext.add_list (initial_gamma_list e) (FunContext.get_empty_context ()) ) in
    enter l;
      let full_cache = IncrementalFunAlgorithm.get_empty_cache 4096 in
      ignore (IncrementalFunAlgorithm.build_cache e gamma_init full_cache);
    exit l


let gen_list min max next =
  let rec gen_aux curr =
    if curr >= max then [max] else curr :: (gen_aux (next curr))
  in gen_aux min

let rec cartesian a b = match b with
| [] -> []
| be :: bs ->  (List.map (fun ae -> (be, ae)) a) @ (cartesian a bs)

(*
let repeat f k =
  let rec _repeat f i =
    match i with
    | k - 1 -> ()
    | _ -> Printf.printf "\tRun #%d\n" (i+1); ignore f; _repeat f (i+1)
  in _repeat f 0 *)

(*
  This is a pretty rough evaluation for the memory.
  We simply take the number of repetitions we should do, the maximum depth of the synthetic program and we evaluate the running.
  Note that here modifications do not matter at all!
*)
let _ =
  if Array.length Sys.argv < 4 then
    Printf.printf "%s min_depth max_depth cache\n" Sys.argv.(0)
  else
    let options = {
      debug = false;
      allocated_bytes = true;
      sys_time = false;
      recursive = true;
      output = Channel Stdlib.stdout;
      format = JSON;
    } in
    set_profiling_options options;
    let min_depth, max_depth, cache = int_of_string Sys.argv.(1), int_of_string Sys.argv.(2), bool_of_string Sys.argv.(3) in
    let depth_list = gen_list min_depth max_depth (fun n -> n+2) in
    let fv_c_list = 1 :: (gen_list (BatInt.pow 2 (min_depth-1)) (BatInt.pow 2 (max_depth-1)) (fun n -> 2*n)) in
    let tpl_cmp (a_id, a_fvc) (b_id, b_fvc) = if (a_id = b_id && a_fvc=b_fvc) then 0 else -1 in
    let param_list = List.sort_uniq tpl_cmp (cartesian depth_list fv_c_list) in
    let param_list = List.filter (fun (fv_c, depth) -> fv_c <= (BatInt.pow 2 (depth-1))) param_list in
    let len = List.length param_list in
      List.iteri (fun i (fv_c, depth) -> (
        Printf.eprintf "[%d/%d] --- depth=%d; fv_c=%d;\n" (i+1) len depth fv_c;
        flush stderr;
        let e = Generator.gen_ibop_ids_ast depth "+" fv_c in
        let lo = register ("orig_" ^ (string_of_int depth) ^ "_" ^ (string_of_int fv_c)) in
        let li = register ("inc_" ^ (string_of_int depth) ^ "_" ^ (string_of_int fv_c)) in
        let lc = register ("cache_" ^ (string_of_int depth) ^ "_" ^ (string_of_int fv_c)) in
        if cache then
          ignore (just_cache e lc)
        else
          (ignore (mem_orig e lo); ignore (mem_inc e li))
      )) param_list