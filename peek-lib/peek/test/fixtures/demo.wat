;; demo module
(module
  (func $answer (result i32)
    i32.const 42)
  (export "answer" (func $answer))
  (; malformed-ish trailing sample for best-effort coloring ;)
)
