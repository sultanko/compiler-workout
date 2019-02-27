open GT       
open Syntax
       
(* The type for the stack machine instructions *)
@type insn =
(* binary operator                 *) | BINOP of string
(* put a constant on the stack     *) | CONST of int                 
(* read to stack                   *) | READ
(* write from stack                *) | WRITE
(* load a variable to the stack    *) | LD    of string
(* store a variable from the stack *) | ST    of string with show

(* The type for the stack machine program *)                                                               
type prg = insn list

(* The type for the stack machine configuration: a stack and a configuration from statement
   interpreter
 *)
type config = int list * Syntax.Stmt.config

(* Stack machine interpreter

     val eval : config -> prg -> config

   Takes a configuration and a program, and returns a configuration as a result
 *)                         
let eval_one (stack, cfg) instr = 
    let (s, i, o) = cfg in
	match instr with
        | BINOP op -> (match stack with
            | x::y::tail -> ((Expr.str_to_op op y x)::tail, cfg)
            | _ -> failwith "binop")
        | CONST z -> (z::stack, cfg)
        | READ -> (match i with
            | z::tail -> (z::stack, (s, tail, o))
            | _ -> failwith "read")
        | WRITE -> (match stack with
            | z::tail -> (tail, (s, i, o@[z]))
            | _ -> failwith "write")
        | LD x -> ((s x)::stack, cfg)
        | ST x -> (match stack with
            | z::tail -> (tail, (Expr.update x z s, i, o))
            | _ -> failwith "st")

let eval cfg p = List.fold_left eval_one cfg p

(* Top-level evaluation

     val run : int list -> prg -> int list

   Takes an input stream, a program, and returns an output stream this program calculates
*)
let run i p = let (_, (_, _, o)) = eval ([], (Syntax.Expr.empty, i, [])) p in o

(* Stack machine compiler

     val compile : Syntax.Stmt.t -> prg

   Takes a program in the source language and returns an equivalent program for the
   stack machine
 *)

let rec compile_expr e = match e with
    | Expr.Const n -> [CONST n]
    | Expr.Var v -> [LD v]
    | Expr.Binop (op, l, r) -> (compile_expr l)@(compile_expr r)@[BINOP op]

let rec compile stmt = match stmt with
    | Stmt.Read x -> [READ; ST x]
    | Stmt.Write e -> (compile_expr e)@[WRITE]
    | Stmt.Assign (x, e) -> (compile_expr e)@[ST x]
    | Stmt.Seq (l, r) -> (compile l)@(compile r)
