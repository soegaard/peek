#lang racket/base

(require rackunit
         racket/file
         racket/runtime-path
         racket/string
         "../c.rkt"
         "../css.rkt"
         "../html.rkt"
         "../js.rkt"
         "../json.rkt"
         "../main.rkt"
         "../markdown.rkt"
         "../python.rkt"
         "../preview.rkt"
         "../yaml.rkt"
         "../racket.rkt"
         "../rhombus.rkt"
         "../shell.rkt"
         "../scribble.rkt"
         "../wat.rkt")

(define-runtime-path demo-markdown-path
  "fixtures/demo.md")
(define-runtime-path demo-c-path
  "fixtures/demo.c")
(define-runtime-path demo-json-path
  "fixtures/demo.json")
(define-runtime-path demo-yaml-path
  "fixtures/demo.yaml")
(define-runtime-path demo-yml-path
  "fixtures/demo.yml")
(define-runtime-path demo-python-path
  "fixtures/demo.py")
(define-runtime-path demo-shell-path
  "fixtures/demo.sh")
(define-runtime-path demo-racket-path
  "fixtures/demo.rkt")
(define-runtime-path demo-ss-path
  "fixtures/demo.ss")
(define-runtime-path demo-rktd-path
  "fixtures/demo.rktd")
(define-runtime-path demo-rhombus-path
  "fixtures/demo.rhm")
(define-runtime-path demo-scribble-path
  "fixtures/demo.scrbl")
(define-runtime-path demo-zsh-path
  "fixtures/demo.zsh")
(define-runtime-path demo-powershell-path
  "fixtures/demo.ps1")
(define-runtime-path demo-wat-path
  "fixtures/demo.wat")

(define ansi-pattern
  #px"\u001b\\[[0-9;]*m")

(define (strip-ansi text)
  (regexp-replace* ansi-pattern text ""))

(check-equal? supported-file-types
              '(bash c css html js json jsx md powershell python rhombus rkt scrbl wat yaml zsh))

(check-equal? (preview-string "color: #fff;" #f
                              (make-preview-options #:type 'css
                                                    #:color-mode 'never))
              "color: #fff;")
(check-true
 (regexp-match? #px"\u001b\\["
                (preview-string "color: #fff;" #f
                                (make-preview-options #:type 'css
                                                      #:color-mode 'always))))

(check-true
 (regexp-match? #px"doctype"
                (render-html-preview
                 "<!doctype html><main id=\"app\">Hi &amp; bye<style>.x { color: #fff; }</style><script>const answer = 42;</script><!-- note --></main>")))
(check-true
 (regexp-match? #px"main"
                (render-c-preview "#include <stdio.h>\nint main(void) { return 0; }\n")))
(check-true
 (regexp-match? #px"peek"
                (render-json-preview "{\"name\": \"peek\", \"ok\": true, \"n\": 2}\n")))
(check-true
 (regexp-match? #px"anchor"
                (render-yaml-preview "---\nname: &anchor !tag value\n")))
(check-true
 (regexp-match? #px"answer"
                (render-python-preview "def answer(name):\n    return name\n")))
(check-true
 (regexp-match? #px"answer"
                (render-javascript-preview "const answer = 42;\nobj.run(answer);\n")))
(check-true
 (regexp-match? #px"Button"
                (render-javascript-preview "const el = <Button kind=\"primary\">Hello {name}</Button>;\n"
                                           #:jsx? #t)))
(check-true
 (regexp-match? #px"Title"
                (render-markdown-preview "# Title\n\nText\n")))
(check-true
 (regexp-match? #px"export"
                (render-shell-preview "#!/usr/bin/env bash\nexport PATH\n"
                                      #:shell 'bash)))
(check-true
 (regexp-match? #px"#lang"
                (render-racket-preview "#lang racket/base\n(define x 1)\n")))
(check-true
 (regexp-match? #px"title"
                (render-scribble-preview "@title{Hi}\n")))
(check-true
 (regexp-match? #px"module"
                (render-wat-preview "(module (func (result i32) (i32.const 42)))\n")))

(check-true
 (regexp-match? #px"\u001b\\["
                (preview-string "const answer = 42;\n"
                                "demo.js"
                                (make-preview-options #:color-mode 'always))))
(check-true
 (regexp-match? #px"\u001b\\["
                (preview-string "echo \"$HOME\"\n"
                                "script.bash"
                                (make-preview-options #:color-mode 'always))))
(check-true
 (let ([out (open-output-string)])
   (preview-port (open-input-string "#lang racket/base\n(define x 1)\n")
                 "program.rkt"
                 (make-preview-options #:color-mode 'always)
                 out)
   (regexp-match? #px"\u001b\\[" (get-output-string out))))
(check-equal?
 (let ([out (open-output-string)])
   (preview-port (open-input-string "$name = \"world\"\n")
                 "script.ps1"
                 (make-preview-options #:color-mode 'always)
                 out)
   (strip-ansi (get-output-string out)))
 "$name = \"world\"\n")

(check-equal?
 (let ([out (open-output-string)])
   (preview-port (open-input-string "<!doctype html><main id=\"app\">Hi</main>\n")
                 "index.html"
                 (make-preview-options #:color-mode 'always)
                 out)
   (strip-ansi (get-output-string out)))
 "<!doctype html><main id=\"app\">Hi</main>\n")

(check-equal?
 (strip-ansi (preview-file demo-c-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-c-path))
(check-equal?
 (strip-ansi (preview-file demo-shell-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-shell-path))
(check-equal?
 (strip-ansi (preview-file demo-json-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-json-path))
(check-equal?
 (strip-ansi (preview-file demo-yaml-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-yaml-path))
(check-equal?
 (strip-ansi (preview-file demo-yml-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-yml-path))
(check-equal?
 (strip-ansi (preview-file demo-ss-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-ss-path))
(check-equal?
 (strip-ansi (preview-file demo-rktd-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-rktd-path))
(check-equal?
 (strip-ansi (preview-file demo-python-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-python-path))
(check-equal?
 (strip-ansi (preview-file demo-zsh-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-zsh-path))
(check-equal?
 (strip-ansi (preview-file demo-powershell-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-powershell-path))
(check-true
 (regexp-match? #px"greet"
                (preview-file demo-racket-path
                              (make-preview-options #:color-mode 'always))))
(check-equal?
 (strip-ansi (preview-file demo-rhombus-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-rhombus-path))
(check-true
 (regexp-match? #px"Title"
                (preview-string "# Title\n\nText\n"
                                "README.md"
                                (make-preview-options #:color-mode 'always))))
(check-true
 (regexp-match? #px"Demo Document"
                (preview-file demo-markdown-path
                              (make-preview-options #:color-mode 'always))))
(check-equal?
 (strip-ansi (preview-string "#include <stdio.h>\nint main(void) { return 0; }\n"
                             #f
                             (make-preview-options #:type 'c
                                                   #:color-mode 'always)))
 "#include <stdio.h>\nint main(void) { return 0; }\n")
(check-equal?
 (strip-ansi (preview-string "#!/usr/bin/env bash\nexport PATH\n"
                             #f
                             (make-preview-options #:type 'bash
                                                   #:color-mode 'always)))
 "#!/usr/bin/env bash\nexport PATH\n")
(check-equal?
 (strip-ansi (preview-string "{\"name\": \"peek\", \"ok\": true, \"n\": 2}\n"
                             #f
                             (make-preview-options #:type 'json
                                                   #:color-mode 'always)))
 "{\"name\": \"peek\", \"ok\": true, \"n\": 2}\n")
(check-equal?
 (strip-ansi (preview-string "---\nname: &anchor !tag value\n"
                             #f
                             (make-preview-options #:type 'yaml
                                                   #:color-mode 'always)))
 "---\nname: &anchor !tag value\n")
(check-equal?
 (strip-ansi (preview-string "def answer(name):\n    return name\n"
                             #f
                             (make-preview-options #:type 'python
                                                   #:color-mode 'always)))
 "def answer(name):\n    return name\n")
(check-equal?
 (strip-ansi (preview-string "autoload -Uz compinit\n"
                             #f
                             (make-preview-options #:type 'zsh
                                                   #:color-mode 'always)))
 "autoload -Uz compinit\n")
(check-equal?
 (strip-ansi (preview-string "$name = \"world\"\n"
                             #f
                             (make-preview-options #:type 'powershell
                                                   #:color-mode 'always)))
 "$name = \"world\"\n")
(check-equal?
 (strip-ansi (preview-string "#lang rhombus\nfun greet(name): name\n"
                             #f
                             (make-preview-options #:type 'rhombus
                                                   #:color-mode 'always)))
 "#lang rhombus\nfun greet(name): name\n")
(check-true
 (regexp-match? #px"itemlist"
                (preview-file demo-scribble-path
                              (make-preview-options #:color-mode 'always))))
(check-true
 (regexp-match? #px"answer"
                (preview-file demo-wat-path
                              (make-preview-options #:color-mode 'always))))
