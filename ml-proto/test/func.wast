;; Test `func` declarations, i.e. functions

(module
  ;; Auxiliary definition
  (type $sig (func))
  (func $dummy)

  ;; Syntax

  (func)
  (func "f")
  (func $f)
  (func "g" $h)

  (func (local))
  (func (local i32))
  (func (local $x i32))
  (func (local i32 f64 i64))
  (func (local i32) (local f64))
  (func (local i32 f32) (local $x i64) (local) (local i32 f64))

  (func (param))
  (func (param i32))
  (func (param $x i32))
  (func (param i32 f64 i64))
  (func (param i32) (param f64))
  (func (param i32 f32) (param $x i64) (param) (param i32 f64))

  (func (result i32) (unreachable))

  (func (type $sig))

  (func $complex
    (param i32 f32) (param $x i64) (param) (param i32)
    (result i32)
    (local f32) (local $y i32) (local i64 i32) (local) (local f64 i32)
    (unreachable) (unreachable)
  )
  (func $complex-sig
    (type $sig)
    (local f32) (local $y i32) (local i64 i32) (local) (local f64 i32)
    (unreachable) (unreachable)
  )


  ;; Typing of locals

  (func "local-first-i32" (result i32) (local i32 i32) (get_local 0))
  (func "local-first-i64" (result i64) (local i64 i64) (get_local 0))
  (func "local-first-f32" (result f32) (local f32 f32) (get_local 0))
  (func "local-first-f64" (result f64) (local f64 f64) (get_local 0))
  (func "local-second-i32" (result i32) (local i32 i32) (get_local 1))
  (func "local-second-i64" (result i64) (local i64 i64) (get_local 1))
  (func "local-second-f32" (result f32) (local f32 f32) (get_local 1))
  (func "local-second-f64" (result f64) (local f64 f64) (get_local 1))
  (func "local-mixed" (result f64)
    (local f32) (local $x i32) (local i64 i32) (local) (local f64 i32)
    (drop (f32.neg (get_local 0)))
    (drop (i32.eqz (get_local 1)))
    (drop (i64.eqz (get_local 2)))
    (drop (i32.eqz (get_local 3)))
    (drop (f64.neg (get_local 4)))
    (drop (i32.eqz (get_local 5)))
    (get_local 4)
  )

  ;; Typing of parameters

  (func "param-first-i32" (param i32 i32) (result i32) (get_local 0))
  (func "param-first-i64" (param i64 i64) (result i64) (get_local 0))
  (func "param-first-f32" (param f32 f32) (result f32) (get_local 0))
  (func "param-first-f64" (param f64 f64) (result f64) (get_local 0))
  (func "param-second-i32" (param i32 i32) (result i32) (get_local 1))
  (func "param-second-i64" (param i64 i64) (result i64) (get_local 1))
  (func "param-second-f32" (param f32 f32) (result f32) (get_local 1))
  (func "param-second-f64" (param f64 f64) (result f64) (get_local 1))
  (func "param-mixed" (param f32 i32) (param) (param $x i64) (param i32 f64 i32)
    (result f64)
    (drop (f32.neg (get_local 0)))
    (drop (i32.eqz (get_local 1)))
    (drop (i64.eqz (get_local 2)))
    (drop (i32.eqz (get_local 3)))
    (drop (f64.neg (get_local 4)))
    (drop (i32.eqz (get_local 5)))
    (get_local 4)
  )

  ;; Typing of result

  (func "empty")
  (func "value-void" (call $dummy))
  (func "value-i32" (result i32) (i32.const 77))
  (func "value-i64" (result i64) (i64.const 7777))
  (func "value-f32" (result f32) (f32.const 77.7))
  (func "value-f64" (result f64) (f64.const 77.77))
  (func "value-block-void" (block (call $dummy) (call $dummy)))
  (func "value-block-i32" (result i32) (block (call $dummy) (i32.const 77)))

  (func "return-empty" (return))
  (func "return-i32" (result i32) (return (i32.const 78)))
  (func "return-i64" (result i64) (return (i64.const 7878)))
  (func "return-f32" (result f32) (return (f32.const 78.7)))
  (func "return-f64" (result f64) (return (f64.const 78.78)))
  (func "return-block-i32" (result i32)
    (return (block (call $dummy) (i32.const 77)))
  )

  (func "break-empty" (br 0))
  (func "break-i32" (result i32) (br 0 (i32.const 79)))
  (func "break-i64" (result i64) (br 0 (i64.const 7979)))
  (func "break-f32" (result f32) (br 0 (f32.const 79.9)))
  (func "break-f64" (result f64) (br 0 (f64.const 79.79)))
  (func "break-block-i32" (result i32)
    (br 0 (block (call $dummy) (i32.const 77)))
  )

  (func "break-br_if-empty" (param i32)
    (br_if 0 (get_local 0))
  )
  (func "break-br_if-num" (param i32) (result i32)
    (br_if 0 (i32.const 50) (get_local 0)) (i32.const 51)
  )

  (func "break-br_table-empty" (param i32)
    (br_table 0 0 0 (get_local 0))
  )
  (func "break-br_table-num" (param i32) (result i32)
    (br_table 0 0 (i32.const 50) (get_local 0)) (i32.const 51)
  )
  (func "break-br_table-nested-empty" (param i32)
    (block (br_table 0 1 0 (get_local 0)))
  )
  (func "break-br_table-nested-num" (param i32) (result i32)
    (i32.add
      (block (br_table 0 1 0 (i32.const 50) (get_local 0)) (i32.const 51))
      (i32.const 2)
    )
  )

  ;; Default initialization of locals

  (func "init-local-i32" (result i32) (local i32) (get_local 0))
  (func "init-local-i64" (result i64) (local i64) (get_local 0))
  (func "init-local-f32" (result f32) (local f32) (get_local 0))
  (func "init-local-f64" (result f64) (local f64) (get_local 0))
)

(assert_return (invoke "local-first-i32") (i32.const 0))
(assert_return (invoke "local-first-i64") (i64.const 0))
(assert_return (invoke "local-first-f32") (f32.const 0))
(assert_return (invoke "local-first-f64") (f64.const 0))
(assert_return (invoke "local-second-i32") (i32.const 0))
(assert_return (invoke "local-second-i64") (i64.const 0))
(assert_return (invoke "local-second-f32") (f32.const 0))
(assert_return (invoke "local-second-f64") (f64.const 0))
(assert_return (invoke "local-mixed") (f64.const 0))

(assert_return
  (invoke "param-first-i32" (i32.const 2) (i32.const 3)) (i32.const 2)
)
(assert_return
  (invoke "param-first-i64" (i64.const 2) (i64.const 3)) (i64.const 2)
)
(assert_return
  (invoke "param-first-f32" (f32.const 2) (f32.const 3)) (f32.const 2)
)
(assert_return
  (invoke "param-first-f64" (f64.const 2) (f64.const 3)) (f64.const 2)
)
(assert_return
  (invoke "param-second-i32" (i32.const 2) (i32.const 3)) (i32.const 3)
)
(assert_return
  (invoke "param-second-i64" (i64.const 2) (i64.const 3)) (i64.const 3)
)
(assert_return
  (invoke "param-second-f32" (f32.const 2) (f32.const 3)) (f32.const 3)
)
(assert_return
  (invoke "param-second-f64" (f64.const 2) (f64.const 3)) (f64.const 3)
)

(assert_return
  (invoke "param-mixed"
    (f32.const 1) (i32.const 2) (i64.const 3)
    (i32.const 4) (f64.const 5.5) (i32.const 6)
  )
  (f64.const 5.5)
)

(assert_return (invoke "empty"))
(assert_return (invoke "value-void"))
(assert_return (invoke "value-i32") (i32.const 77))
(assert_return (invoke "value-i64") (i64.const 7777))
(assert_return (invoke "value-f32") (f32.const 77.7))
(assert_return (invoke "value-f64") (f64.const 77.77))
(assert_return (invoke "value-block-void"))
(assert_return (invoke "value-block-i32") (i32.const 77))

(assert_return (invoke "return-empty"))
(assert_return (invoke "return-i32") (i32.const 78))
(assert_return (invoke "return-i64") (i64.const 7878))
(assert_return (invoke "return-f32") (f32.const 78.7))
(assert_return (invoke "return-f64") (f64.const 78.78))
(assert_return (invoke "return-block-i32") (i32.const 77))

(assert_return (invoke "break-empty"))
(assert_return (invoke "break-i32") (i32.const 79))
(assert_return (invoke "break-i64") (i64.const 7979))
(assert_return (invoke "break-f32") (f32.const 79.9))
(assert_return (invoke "break-f64") (f64.const 79.79))
(assert_return (invoke "break-block-i32") (i32.const 77))

(assert_return (invoke "break-br_if-empty" (i32.const 0)))
(assert_return (invoke "break-br_if-empty" (i32.const 2)))
(assert_return (invoke "break-br_if-num" (i32.const 0)) (i32.const 51))
(assert_return (invoke "break-br_if-num" (i32.const 1)) (i32.const 50))

(assert_return (invoke "break-br_table-empty" (i32.const 0)))
(assert_return (invoke "break-br_table-empty" (i32.const 1)))
(assert_return (invoke "break-br_table-empty" (i32.const 5)))
(assert_return (invoke "break-br_table-empty" (i32.const -1)))
(assert_return (invoke "break-br_table-num" (i32.const 0)) (i32.const 50))
(assert_return (invoke "break-br_table-num" (i32.const 1)) (i32.const 50))
(assert_return (invoke "break-br_table-num" (i32.const 10)) (i32.const 50))
(assert_return (invoke "break-br_table-num" (i32.const -100)) (i32.const 50))
(assert_return (invoke "break-br_table-nested-empty" (i32.const 0)))
(assert_return (invoke "break-br_table-nested-empty" (i32.const 1)))
(assert_return (invoke "break-br_table-nested-empty" (i32.const 3)))
(assert_return (invoke "break-br_table-nested-empty" (i32.const -2)))
(assert_return
  (invoke "break-br_table-nested-num" (i32.const 0)) (i32.const 52)
)
(assert_return
  (invoke "break-br_table-nested-num" (i32.const 1)) (i32.const 50)
)
(assert_return
  (invoke "break-br_table-nested-num" (i32.const 2)) (i32.const 52)
)
(assert_return
  (invoke "break-br_table-nested-num" (i32.const -3)) (i32.const 52)
)

(assert_return (invoke "init-local-i32") (i32.const 0))
(assert_return (invoke "init-local-i64") (i64.const 0))
(assert_return (invoke "init-local-f32") (f32.const 0))
(assert_return (invoke "init-local-f64") (f64.const 0))


;; Invalid typing of locals

(assert_invalid
  (module (func $type-local-num-vs-num (result i64) (local i32) (get_local 0)))
  "type mismatch"
)
(assert_invalid
  (module (func $type-local-num-vs-num (local f32) (i32.eqz (get_local 0))))
  "type mismatch"
)
(assert_invalid
  (module (func $type-local-num-vs-num (local f64 i64) (f64.neg (get_local 1))))
  "type mismatch"
)


;; Invalid typing of parameters

(assert_invalid
  (module (func $type-param-num-vs-num (param i32) (result i64) (get_local 0)))
  "type mismatch"
)
(assert_invalid
  (module (func $type-param-num-vs-num (param f32) (i32.eqz (get_local 0))))
  "type mismatch"
)
(assert_invalid
  (module (func $type-param-num-vs-num (param f64 i64) (f64.neg (get_local 1))))
  "type mismatch"
)


;; Invalid typing of result

(assert_invalid
  (module (func $type-empty-i32 (result i32)))
  "type mismatch"
)
(assert_invalid
  (module (func $type-empty-i64 (result i64)))
  "type mismatch"
)
(assert_invalid
  (module (func $type-empty-f32 (result f32)))
  "type mismatch"
)
(assert_invalid
  (module (func $type-empty-f64 (result f64)))
  "type mismatch"
)

(assert_invalid
  (module (func $type-value-void-vs-num (result i32)
    (nop)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-value-num-vs-void
    (i32.const 0)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-value-num-vs-num (result i32)
    (f32.const 0)
  ))
  "type mismatch"
)

(; TODO(stack): Should these become legal?
(assert_invalid
  (module (func $type-value-void-vs-num-after-return (result i32)
    (return (i32.const 1)) (nop)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-value-num-vs-num-after-return (result i32)
    (return (i32.const 1)) (f32.const 0)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-value-void-vs-num-after-break (result i32)
    (br 0 (i32.const 1)) (nop)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-value-num-vs-num-after-break (result i32)
    (br 0 (i32.const 1)) (f32.const 0)
  ))
  "arity mismatch"
)
;)

(assert_invalid
  (module (func $type-return-last-void-vs-enpty
    (return (nop))
  ))
  "arity mismatch"
)
(assert_invalid
  (module (func $type-return-last-num-vs-enpty
    (return (i32.const 0))
  ))
  "arity mismatch"
)
(assert_invalid
  (module (func $type-return-last-empty-vs-num (result i32)
    (return)
  ))
  "arity mismatch"
)
(assert_invalid
  (module (func $type-return-last-void-vs-num (result i32)
    (return (nop))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-return-last-num-vs-num (result i32)
    (return (i64.const 0))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-return-void-vs-empty
    (return (nop))
  ))
  "arity mismatch"
)
(assert_invalid
  (module (func $type-return-num-vs-empty
    (return (i32.const 0))
  ))
  "arity mismatch"
)
(assert_invalid
  (module (func $type-return-empty-vs-num (result i32)
    (return) (i32.const 1)
  ))
  "arity mismatch"
)
(assert_invalid
  (module (func $type-return-void-vs-num (result i32)
    (return (nop)) (i32.const 1)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-return-num-vs-num (result i32)
    (return (i64.const 1)) (i32.const 1)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-return-first-num-vs-num (result i32)
    (return (i64.const 1)) (return (i32.const 1))
  ))
  "type mismatch"
)
(; TODO(stack): Should this become legal?
(assert_invalid
  (module (func $type-return-second-num-vs-num (result i32)
    (return (i32.const 1)) (return (f64.const 1))
  ))
  "type mismatch"
)
;)

(assert_invalid
  (module (func $type-break-last-void-vs-empty
    (br 0 (nop))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-last-num-vs-empty
    (br 0 (i32.const 0))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-last-empty-vs-num (result i32)
    (br 0)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-last-void-vs-num (result i32)
    (br 0 (nop))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-last-num-vs-num (result i32)
    (br 0 (f32.const 0))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-void-vs-empty
    (br 0 (i64.const 1))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-num-vs-empty
    (br 0 (i64.const 1))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-empty-vs-num (result i32)
    (br 0) (i32.const 1)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-void-vs-num (result i32)
    (br 0 (nop)) (i32.const 1)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-num-vs-num (result i32)
    (br 0 (i64.const 1)) (i32.const 1)
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-first-num-vs-num (result i32)
    (br 0 (i64.const 1)) (br 0 (i32.const 1))
  ))
  "type mismatch"
)
(; TODO(stack): Should this become legal?
(assert_invalid
  (module (func $type-break-second-num-vs-num (result i32)
    (br 0 (i32.const 1)) (br 0 (f64.const 1))
  ))
  "type mismatch"
)
;)

(assert_invalid
  (module (func $type-break-nested-empty-vs-num (result i32)
    (block (br 1)) (br 0 (i32.const 1))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-nested-void-vs-num (result i32)
    (block (br 1 (nop))) (br 0 (i32.const 1))
  ))
  "type mismatch"
)
(assert_invalid
  (module (func $type-break-nested-num-vs-num (result i32)
    (block (br 1 (i64.const 1))) (br 0 (i32.const 1))
  ))
  "type mismatch"
)
