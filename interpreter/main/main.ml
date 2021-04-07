let name = "wasm"
let version = "1.0"

let configure () =
  Import.register (Utf8.decode "spectest") Spectest.lookup;
  Import.register (Utf8.decode "env") Env.lookup

let banner () =
  print_endline (name ^ " " ^ version ^ " reference interpreter")

let usage = "Usage: " ^ name ^ " [option] [file ...]"

let args = ref []
let add_arg source = args := !args @ [source]

let quote s = "\"" ^ String.escaped s ^ "\""

let argspec = Arg.align
[
  "-", Arg.Set Flags.interactive,
    " run interactively (default if no files given)";
  "-e", Arg.String add_arg, " evaluate string";
  "-i", Arg.String (fun file -> add_arg ("(input " ^ quote file ^ ")")),
    " read script from file";
  "-o", Arg.String (fun file -> add_arg ("(output " ^ quote file ^ ")")),
    " write module to file";
  "-w", Arg.Int (fun n -> Flags.width := n),
    " configure output width (default is 80)";
  "-s", Arg.Set Flags.print_sig, " show module signatures";
  "-u", Arg.Set Flags.unchecked, " unchecked, do not perform validation";
  "-h", Arg.Clear Flags.harness, " exclude harness for JS conversion";
  "-d", Arg.Set Flags.dry, " dry, do not run program";
  "-t", Arg.Set Flags.trace, " trace execution";
  "-b", Arg.Set Flags.bfs, " run breadth first Search instead of default DFS";
  "-l", Arg.Set Flags.loop_invar, " use loop invariant";
  "-m", Arg.Set Flags.simplify, " enable simplify from Z3";
  "-p", Arg.Set Flags.pfs, " run pfs instead of default DFS";
  "-S", Arg.Set Flags.select_unsafe, " set \"select\" instruction as unsafe";
  "--z3-only", Arg.Set Flags.z3_only, " run using the z3 bindings";
  "--portfolio-only", Arg.Set Flags.portfolio_only, " run using the portfolio solver";
  "--elim-indvar", Arg.Set Flags.elim_induction_variables, " perform induction variable elimination";
  "--unroll-one", Arg.Set Flags.unroll_one, " use with -l to unroll the first iteration of each loop";
  "--no-clean", Arg.Set Flags.no_clean, " don't clean the solver tmp files from the /tmp fs";
  "--explicit-leaks", Arg.Set Flags.explicit_leaks, " include explicit leaks to the memory";
  "--estimate-loop-size", Arg.Set Flags.estimate_loop_size, " estimate the loop size and deside on whether to apply the invariant or not ";
  "--stats", Arg.Set Flags.stats, " generate solver statistics";
  "--debug", Arg.Set Flags.debug, " enable debug msgs";
  "-v", Arg.Unit banner, " show version"
]

let () =
  Printexc.record_backtrace true;
  try
    configure ();
    Arg.parse argspec
      (fun file -> add_arg ("(input " ^ quote file ^ ")")) usage;
    List.iter (fun arg -> if not (Run.run_string arg) then exit 1) !args;
    if !args = [] then Flags.interactive := true;
    if !Flags.interactive then begin
      Flags.print_sig := true;
      banner ();
      Run.run_stdin ()
    end
  with exn ->
    flush_all ();
    prerr_endline
      (Sys.argv.(0) ^ ": uncaught exception " ^ Printexc.to_string exn);
    Printexc.print_backtrace stderr;
    exit 2
