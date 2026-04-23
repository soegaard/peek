(module
  (;; WAT preview example. ;)
  (func $answer (result i32)
    i32.const 42)
  (func $double (param $x i32) (result i32)
    local.get $x
    i32.const 2
    i32.mul)
  (export "answer" (func $answer)))
