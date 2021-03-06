open Core
open Core_bench
open FunSpecification.FunSpecification
open VarSet

module IncrementalFunAlgorithm = Incrementalizer.TypeAlgorithm(FunSpecification.FunSpecification)

let _ =
   if Array.length Sys.argv < 4 then
    Printf.eprintf "%s quota min_depth max_depth\n" Sys.argv.(0)
  else
     let quota, min_depth, max_depth =
      Quota.of_string Sys.argv.(1),
      int_of_string Sys.argv.(2),
      int_of_string Sys.argv.(3) in
    let depth_list = Generator.gen_list min_depth max_depth (fun n -> n+2) in  (* Seems that big ASTs have ~20k nodes, cfr. [Erdweg et al.] *)
    let len = List.length depth_list in
    Printf.printf "name, fvc, invalidation_parameter, nodecount, diffsz, threshold, rate\n"; Out_channel.flush stdout;
    List.iteri ~f:(fun i depth -> (
      let fv_c_list =  1 :: Generator.gen_list (Generator.pow 2 7) (Generator.pow 2 (depth-1)) (fun n -> n*2) in
      let inv_depth_list = [1; 2; 3] @ Generator.gen_list 4 (depth - 1) (fun n -> n + 2) in
      Printf.eprintf "[%d/%d] depth=%d ...\n" (i+1) len depth;
      Out_channel.flush stderr;
        List.iteri ~f:(fun j fv_c -> (
          Printf.eprintf "\t[%d/%d] fv_c=%d ...\n" (j+1) (List.length fv_c_list) fv_c;
          Out_channel.flush stderr;
          let e = Generator.ibop_gen_ast depth "+" fv_c in
          let initial_gamma_list e = (List.map ~f:(fun id -> (id, TInt)) (VarSet.elements (compute_fv e))) in
          let gamma_init = (FunContext.add_list (initial_gamma_list e) (FunContext.get_empty_context ()) ) in
          Printf.eprintf "\t\t[1/%d] testing caches ... " (1+List.length inv_depth_list); Out_channel.flush stderr;
          let caches_res =
            Experiments.throughput_caches
            quota
            Core_bench.Verbosity.Quiet
            IncrementalFunAlgorithm.typing
            fv_c
            gamma_init
            e in
          Printf.eprintf "done\n"; Out_channel.flush stderr;
          Experiments.print_csv caches_res; Out_channel.flush stdout;
          List.iteri ~f:(fun k inv_depth ->
            Printf.eprintf "\t\t[%d/%d] inv_depth=%d ... \n" (k+2) (1+List.length inv_depth_list) inv_depth;
            Out_channel.flush stderr;
            (* A few fixed thresholds, just on trees with the max num of free variables *)
            let t_list = None::(if Generator.pow 2 (depth-1) = fv_c then (List.map ~f:(fun v -> Some v) [3; 6]) else []) in
            List.iteri ~f:(fun l t ->
              Printf.eprintf "\t\t\t[%d/%d] threshold=%d ... " (l+1) (List.length t_list) (Option.value t ~default:(-1));
              Out_channel.flush stderr;
              let orig_vs_inc_res =
                Experiments.throughput_original_vs_inc
                  quota
                  Core_bench.Verbosity.Quiet
                  ?threshold:t
                  (* (fun ?threshold cache gamma term ->
                    let res = IncrementalFunAlgorithm.typing_w_report (Generator.nodecount e) ?threshold:threshold cache gamma term in
                    Printf.printf "%s\n" (IncrementalFunAlgorithm.IncrementalReport.string_of_report IncrementalFunAlgorithm.report);
                    Out_channel.flush stdout;
                    res
                  ) *)
                  IncrementalFunAlgorithm.typing
                  Generator.ibop_sim_change
                  inv_depth
                  fv_c
                  gamma_init
                  e in
                    Experiments.print_csv orig_vs_inc_res;
                    Printf.eprintf "done!\n";
                    Out_channel.flush stderr;
            ) t_list
          ) inv_depth_list
        )) fv_c_list
        )
      )
    depth_list
