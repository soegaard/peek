#lang racket/base

(require rackunit
         racket/file
         racket/runtime-path
         racket/string
         "../common-style.rkt"
         "../c.rkt"
         "../css.rkt"
         "../delimited.rkt"
         "../html.rkt"
         "../js.rkt"
         "../json.rkt"
         "../main.rkt"
         "../markdown.rkt"
         "../plist.rkt"
         "../pascal.rkt"
         "../python.rkt"
         "../rust.rkt"
         "../cpp.rkt"
         "../objc.rkt"
         "../makefile.rkt"
         "../latex.rkt"
         "../tex.rkt"
         "../swift.rkt"
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
(define-runtime-path demo-cpp-path
  "fixtures/demo.cpp")
(define-runtime-path demo-cpp-header-path
  "fixtures/demo.hpp")
(define-runtime-path demo-objc-path
  "fixtures/demo.m")
(define-runtime-path demo-makefile-path
  "fixtures/demo.mk")
(define-runtime-path demo-latex-path
  "fixtures/demo.cls")
(define-runtime-path demo-tex-path
  "fixtures/demo.tex")
(define-runtime-path demo-sty-path
  "fixtures/demo.sty")
(define-runtime-path demo-csv-path
  "fixtures/demo.csv")
(define-runtime-path demo-json-path
  "fixtures/demo.json")
(define-runtime-path demo-plist-path
  "fixtures/demo.plist")
(define-runtime-path demo-pascal-path
  "fixtures/demo.pas")
(define-runtime-path demo-yaml-path
  "fixtures/demo.yaml")
(define-runtime-path demo-yml-path
  "fixtures/demo.yml")
(define-runtime-path demo-python-path
  "fixtures/demo.py")
(define-runtime-path demo-rust-path
  "fixtures/demo.rs")
(define-runtime-path demo-swift-path
  "fixtures/demo.swift")
(define-runtime-path demo-shell-path
  "fixtures/demo.sh")
(define-runtime-path demo-tsv-path
  "fixtures/demo.tsv")
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

(define plist-sample
  (string-append
   "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
   "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "
   "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
   "<plist version=\"1.0\">\n"
   "  <dict>\n"
   "    <key>Name</key>\n"
   "    <string>peek</string>\n"
   "    <key>Enabled</key>\n"
   "    <true/>\n"
   "  </dict>\n"
   "</plist>\n"))

(check-equal? supported-file-types
              '(bash c cpp css csv html js json jsx latex makefile md objc pascal plist powershell python rhombus rkt rust scrbl swift tex tsv wat yaml zsh))

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
 (regexp-match? #px"vector"
                (render-cpp-preview "#include <vector>\n#define ANSWER 42\n")))
(check-true
 (regexp-match? #px"interface"
                (render-objc-preview "#import <Foundation/Foundation.h>\n@interface Foo : NSObject\n@end\n")))
(define makefile-shell-sample
  (string-append
   "APP = scribble-tools\n"
   ".PHONY: docs test\n"
   "docs:\n"
   "\traco scribble +m --html --dest html scribblings/scribble-tools.scrbl\n"
   "\n"
   "test:\n"
   "\t$(CC) -o app main.o util.o\n"
   "\ttest -n \"$HOME\" && raco test private/lang-code.rkt\n"))

(check-true
 (regexp-match? #px"include"
                (render-makefile-preview "CC := gcc\nall: main.o\n\t$(CC) -o app main.o\ninclude local.mk\n")))
(check-equal?
 (strip-ansi (render-makefile-preview makefile-shell-sample))
 makefile-shell-sample)
(check-true
 (regexp-match? #px"\u001b\\[[0-9;]*mtest\u001b\\[0m"
                (render-makefile-preview makefile-shell-sample)))
(check-true
 (regexp-match? #px"\u001b\\[[0-9;]*m--dest\u001b\\[0m"
                (render-makefile-preview makefile-shell-sample)))
(check-true
 (regexp-match? #px"\u001b\\[[0-9;]*m\\$\\(CC\\)\u001b\\[0m"
                (render-makefile-preview makefile-shell-sample)))
(check-equal?
 (strip-ansi (render-tex-preview "\\section{Hi}\nText\n"))
 "\\section{Hi}\nText\n")
(check-equal?
 (strip-ansi (render-latex-preview "\\begin{itemize}\n\\item One\n\\end{itemize}\n"))
 "\\begin{itemize}\n\\item One\n\\end{itemize}\n")
(check-equal?
 (strip-ansi (preview-string "\\section{Hi}\n"
                              #f
                              (make-preview-options #:type 'tex
                                                    #:color-mode 'always)))
 "\\section{Hi}\n")
(check-equal?
 (strip-ansi (preview-string "\\begin{itemize}\n\\item One\n\\end{itemize}\n"
                              #f
                              (make-preview-options #:type 'latex
                                                    #:color-mode 'always)))
 "\\begin{itemize}\n\\item One\n\\end{itemize}\n")
(check-true
 (regexp-match? #px"peek"
                (render-json-preview "{\"name\": \"peek\", \"ok\": true, \"n\": 2}\n")))
(check-true
 (regexp-match? #px"peek"
                (render-plist-preview plist-sample)))
(check-true
 (regexp-match? #px"Demo"
                (render-pascal-preview "program Demo;\nbegin\nend.\n")))
(check-true
 (regexp-match? #px"London"
                (render-csv-preview "name,age,city\nAda,37,London\n")))
(check-true
 (regexp-match? #px"anchor"
                (render-yaml-preview "---\nname: &anchor !tag value\n")))
(check-true
 (regexp-match? #px"answer"
                (render-python-preview "def answer(name):\n    return name\n")))
(check-true
 (regexp-match? #px"greet"
                (render-rust-preview "/// Demo\nfn greet(name: &str) -> String {\n    format!(\"hello, {name}\")\n}\n")))
(check-true
 (regexp-match? #px"greet"
                (render-swift-preview "import Foundation\nfunc greet() { print(\"hi\") }\n")))
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
(check-equal?
 (strip-ansi (render-markdown-preview "```swift\nimport Foundation\nlet value = 42\n```\n"))
 "```swift\nimport Foundation\nlet value = 42\n```\n")
(check-equal?
 (strip-ansi (render-markdown-preview "```tex\n\\section{Hi}\n```\n"))
 "```tex\n\\section{Hi}\n```\n")
(check-equal?
 (strip-ansi (render-markdown-preview "```latex\n\\begin{itemize}\n```\n"))
 "```latex\n\\begin{itemize}\n```\n")
(check-equal?
 (strip-ansi (render-markdown-preview "```cpp\n#include <vector>\n```\n"))
 "```cpp\n#include <vector>\n```\n")
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
 (strip-ansi (preview-file demo-tex-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-tex-path))
(check-equal?
 (strip-ansi (preview-file demo-latex-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-latex-path))
(check-equal?
 (strip-ansi (preview-file demo-sty-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-sty-path))

(check-equal?
 (strip-ansi (preview-file demo-c-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-c-path))
(check-equal?
 (strip-ansi (preview-file demo-cpp-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-cpp-path))
(check-equal?
 (strip-ansi (preview-file demo-cpp-header-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-cpp-header-path))
(check-equal?
 (strip-ansi (preview-file demo-objc-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-objc-path))
(check-equal?
 (strip-ansi (preview-file demo-makefile-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-makefile-path))
(check-equal?
 (strip-ansi (preview-file demo-csv-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-csv-path))
(check-equal?
 (strip-ansi (preview-file demo-shell-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-shell-path))
(check-equal?
 (strip-ansi (preview-file demo-json-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-json-path))
(check-equal?
 (strip-ansi (preview-file demo-plist-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-plist-path))
(check-equal?
 (strip-ansi (preview-file demo-pascal-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-pascal-path))
(check-equal?
 (strip-ansi (preview-string plist-sample
                             #f
                             (make-preview-options #:type 'plist
                                                   #:color-mode 'always)))
 plist-sample)
(check-equal?
 (strip-ansi (preview-string "program Demo;\nvar &do: Integer;\nbegin\n  writeln('hi');\nend.\n"
                             #f
                             (make-preview-options #:type 'pascal
                                                   #:color-mode 'always)))
 "program Demo;\nvar &do: Integer;\nbegin\n  writeln('hi');\nend.\n")
(check-equal?
 (let ([out (open-output-string)])
   (preview-port (open-input-string plist-sample)
                 "demo.plist"
                 (make-preview-options #:color-mode 'always)
                 out)
   (strip-ansi (get-output-string out)))
 plist-sample)
(check-equal?
 (let ([out (open-output-string)])
   (preview-port (open-input-string "program Demo;\nvar &do: Integer;\nbegin\n  writeln('hi');\nend.\n")
                 "demo.pas"
                 (make-preview-options #:color-mode 'always)
                 out)
   (strip-ansi (get-output-string out)))
 "program Demo;\nvar &do: Integer;\nbegin\n  writeln('hi');\nend.\n")
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
 (strip-ansi (preview-file demo-rust-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-rust-path))
(check-equal?
 (strip-ansi (preview-file demo-swift-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-swift-path))
(check-equal?
 (strip-ansi (preview-file demo-zsh-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-zsh-path))
(check-equal?
 (strip-ansi (preview-file demo-powershell-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-powershell-path))
(check-equal?
 (strip-ansi (preview-file demo-tsv-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-tsv-path))
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
 (strip-ansi (preview-string "#include <vector>\n#define ANSWER 42\n"
                             #f
                             (make-preview-options #:type 'cpp
                                                   #:color-mode 'always)))
 "#include <vector>\n#define ANSWER 42\n")
(check-equal?
 (strip-ansi (preview-string "#import <Foundation/Foundation.h>\n@interface Foo : NSObject\n@end\n"
                             #f
                             (make-preview-options #:type 'objc
                                                   #:color-mode 'always)))
 "#import <Foundation/Foundation.h>\n@interface Foo : NSObject\n@end\n")
(check-equal?
 (strip-ansi (preview-string "CC := gcc\nall: main.o\n\t$(CC) -o app main.o\ninclude local.mk\n"
                             #f
                             (make-preview-options #:type 'makefile
                                                   #:color-mode 'always)))
 "CC := gcc\nall: main.o\n\t$(CC) -o app main.o\ninclude local.mk\n")
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
 (strip-ansi (preview-string "name,age,city\nAda,37,London\n"
                             #f
                             (make-preview-options #:type 'csv
                                                   #:color-mode 'always)))
 "name,age,city\nAda,37,London\n")
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
 (strip-ansi (preview-string "/// Demo\nfn greet(name: &str) -> String {\n    format!(\"hello, {name}\")\n}\n"
                             #f
                             (make-preview-options #:type 'rust
                                                   #:color-mode 'always)))
 "/// Demo\nfn greet(name: &str) -> String {\n    format!(\"hello, {name}\")\n}\n")
(check-equal?
 (strip-ansi (preview-string "import Foundation\nfunc greet() { print(\"hi\") }\n"
                             #f
                             (make-preview-options #:type 'swift
                                                   #:color-mode 'always)))
 "import Foundation\nfunc greet() { print(\"hi\") }\n")
(check-equal?
 (strip-ansi (preview-string "autoload -Uz compinit\n"
                             #f
                             (make-preview-options #:type 'zsh
                                                   #:color-mode 'always)))
 "autoload -Uz compinit\n")
(check-equal?
 (strip-ansi (preview-string "name\tage\tcity\nAda\t37\tLondon\n"
                             #f
                             (make-preview-options #:type 'tsv
                                                   #:color-mode 'always)))
 "name\tage\tcity\nAda\t37\tLondon\n")
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
