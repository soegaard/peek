#lang racket/base

(require rackunit
         file/tar
         file/zip
         racket/bytes
         racket/file
         racket/list
         racket/runtime-path
         racket/string
         racket/system
         "../archive.rkt"
         "../binary.rkt"
         "../common-style.rkt"
         "../c.rkt"
         "../css.rkt"
         "../delimited.rkt"
         "../git-diff.rkt"
         "../go.rkt"
         "../html.rkt"
         "../java.rkt"
         "../js.rkt"
         "../json.rkt"
         "../haskell.rkt"
         "../main.rkt"
         "../markdown.rkt"
         "../mathematica.rkt"
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
(define-runtime-path demo-go-path
  "fixtures/demo.go")
(define-runtime-path demo-java-path
  "fixtures/demo.java")
(define-runtime-path demo-json-path
  "fixtures/demo.json")
(define-runtime-path demo-mathematica-path
  "fixtures/demo.wl")
(define-runtime-path demo-haskell-path
  "fixtures/demo.hs")
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

(define (string-open-paren-index text)
  (for/or ([ch (in-string text)]
           [i (in-naturals)])
    (and (char=? ch #\()
         i)))

(define binary-sample
  (bytes 0 1 2 3 16 32 65 66 67 255))

(define (call-with-temp-binary-file bytes proc)
  (define path
    (make-temporary-file "peek-binary~a"))
  (call-with-output-file path
    (lambda (out)
      (write-bytes bytes out))
    #:exists 'truncate/replace
    #:mode 'binary)
  (dynamic-wind
    void
    (lambda () (proc path))
    (lambda ()
      (when (file-exists? path)
        (delete-file path)))))

(define (call-with-temp-directory proc)
  (define dir
    (make-temporary-file "peek-archive~a" 'directory))
  (dynamic-wind
    void
    (lambda () (proc dir))
    (lambda ()
      (when (directory-exists? dir)
        (delete-directory/files dir)))))

(define git-executable
  (find-executable-path "git"))

;; call-with-temp-git-repo : (path? -> any/c) -> any/c
;;   Create a small temporary Git repository for diff-preview tests.
(define (call-with-temp-git-repo proc)
  (call-with-temp-directory
   (lambda (dir)
     (when git-executable
       (parameterize ([current-directory dir])
         (check-true (system* git-executable "init" "-q"))
         (check-true (system* git-executable "config" "user.email" "peek@example.com"))
         (check-true (system* git-executable "config" "user.name" "peek test"))
         (proc dir))))))

(define (call-with-temp-archive-files proc)
  (call-with-temp-directory
   (lambda (dir)
     (define source-dir
       (build-path dir "source"))
     (define zip-path
       (build-path dir "demo.zip"))
     (define tar-path
       (build-path dir "demo.tar"))
     (define tgz-path
       (build-path dir "demo.tgz"))
     (make-directory* (build-path source-dir "src"))
     (call-with-output-file (build-path source-dir "README.md")
       (lambda (out)
         (display "# demo\n" out))
       #:exists 'truncate/replace)
     (call-with-output-file (build-path source-dir "src" "main.rkt")
       (lambda (out)
         (display "#lang racket/base\n" out)
         (display "(displayln \"peek\")\n" out))
       #:exists 'truncate/replace)
     (call-with-output-file (build-path source-dir "src" "note.txt")
       (lambda (out)
         (display "ok\n" out))
       #:exists 'truncate/replace)
     (parameterize ([current-directory source-dir])
       (zip zip-path "README.md" "src")
       (tar tar-path "README.md" "src")
       (tar-gzip tgz-path "README.md" "src"))
     (proc zip-path tar-path tgz-path))))

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
    "    <string>&amp;</string>\n"
    "  </dict>\n"
    "</plist>\n"))

(check-equal? supported-file-types
              '(archive bash binary c cpp css csv go haskell html java js json jsx latex makefile mathematica md objc pascal plist powershell python rhombus rkt rust scrbl swift tex tsv wat yaml zsh))

(let ([out (open-output-string)])
  (preview-path-port demo-racket-path
                     (make-preview-options #:color-mode 'always)
                     out)
  (check-true (regexp-match? ansi-pattern
                             (get-output-string out))))

(let ([out (open-output-string)])
  (preview-path-port demo-mathematica-path
                     (make-preview-options #:color-mode 'always)
                     out)
  (check-true (regexp-match? ansi-pattern
                             (get-output-string out))))

(call-with-temp-directory
 (lambda (dir)
   (define source-dir
     (build-path dir "folder"))
   (make-directory* source-dir)
   (make-directory* (build-path source-dir "alpha"))
   (define out
     (open-output-string))
   (preview-path-port source-dir
                      (make-preview-options #:color-mode 'always)
                      out)
   (check-true (regexp-match? #px"alpha/"
                              (strip-ansi (get-output-string out))))))

(call-with-temp-directory
 (lambda (dir)
   (define path
     (build-path dir "heuristic.m"))
   (call-with-output-file path
     (lambda (out)
       (display "BeginPackage[\"Demo`\"]\n" out)
       (display "Needs[\"CodeParser`\"]\n" out)
       (display "f[x_] := x\n" out))
     #:exists 'truncate/replace)
   (check-equal? (preview-file path
                               (make-preview-options #:color-mode 'always))
                 (render-mathematica-preview (file->string path)))))

(call-with-temp-directory
 (lambda (dir)
   (define path
     (build-path dir "heuristic.m"))
   (call-with-output-file path
     (lambda (out)
       (display "#!/usr/bin/env wolframscript\n" out)
       (display "Needs[\"MUnit`\"]\n" out)
       (display "f[x_] := x\n" out))
     #:exists 'truncate/replace)
   (check-equal? (preview-file path
                               (make-preview-options #:color-mode 'always))
                 (render-mathematica-preview (file->string path)))))

(call-with-temp-directory
 (lambda (dir)
   (define path
     (build-path dir "heuristic.m"))
   (call-with-output-file path
     (lambda (out)
       (display "#import <Foundation/Foundation.h>\n" out)
       (display "@implementation Foo\n" out)
       (display "@end\n" out))
     #:exists 'truncate/replace)
   (check-equal? (preview-file path
                               (make-preview-options #:color-mode 'always))
                 (render-objc-preview (file->string path)))))

(call-with-temp-directory
 (lambda (dir)
   (define path
     (build-path dir "heuristic.m"))
   (call-with-output-file path
     (lambda (out)
       (display "foo[x_] := x\n" out)
       (display "bar = 1\n" out))
     #:exists 'truncate/replace)
   (check-equal? (preview-file path
                               (make-preview-options #:color-mode 'always))
                 (render-mathematica-preview (file->string path)))))

(call-with-temp-directory
 (lambda (dir)
   (define source-dir
     (build-path dir "folder"))
   (make-directory* source-dir)
   (make-directory* (build-path source-dir "alpha"))
   (make-directory* (build-path source-dir "beta"))
   (call-with-output-file (build-path source-dir "tiny.txt")
     (lambda (out)
       (display "x" out))
     #:exists 'truncate/replace)
   (call-with-output-file (build-path source-dir "longer-name.txt")
     (lambda (out)
       (display "hello" out))
     #:exists 'truncate/replace)
   (make-file-or-directory-link (build-path source-dir "tiny.txt")
                                (build-path source-dir "tiny-link"))
   (define directory-preview
     (strip-ansi (preview-file source-dir
                               (make-preview-options #:color-mode 'always))))
   (check-true (regexp-match? #px"beta/\n\ntiny-link" directory-preview))
   (define directory-lines
     (filter (lambda (line)
               (not (string=? line "")))
             (string-split directory-preview "\n")))
   (check-equal? (take directory-lines 2)
                 '("alpha/" "beta/"))
   (check-true (regexp-match? #px"tiny-link +-> " directory-preview))
   (define file-lines
     (filter (lambda (line)
               (regexp-match? #px"\\( *[0-9]+ bytes\\)" line))
             directory-lines))
   (check-equal? (length file-lines) 2)
   (define bytes-columns
     (map (lambda (line)
            (regexp-match-positions #px" bytes\\)" line))
          file-lines))
   (define bytes-start-columns
     (map caar bytes-columns))
   (check-equal? (car bytes-start-columns)
                 (cadr bytes-start-columns))
   (define digit-columns
     (map (lambda (line)
            (regexp-match-positions #px"[0-9]+ bytes\\)" line))
          file-lines))
   (define digit-start-columns
     (map caar digit-columns))
   (check-equal? (car digit-start-columns)
                 (cadr digit-start-columns))
   (define size-preview
     (strip-ansi (preview-file source-dir
                               (make-preview-options #:color-mode 'always
                                                     #:directory-sort 'size))))
   (define size-lines
     (filter (lambda (line)
               (not (string=? line "")))
             (string-split size-preview "\n")))
   (define tiny-index
     (index-of size-lines "tiny.txt        (1 bytes)"))
   (define longer-index
     (index-of size-lines "longer-name.txt (5 bytes)"))
   (check-true (exact-nonnegative-integer? tiny-index))
   (check-true (exact-nonnegative-integer? longer-index))
   (check-true (< longer-index tiny-index))
   (call-with-output-file (build-path source-dir "notes.md")
     (lambda (out)
       (display "notes" out))
     #:exists 'truncate/replace)
   (call-with-output-file (build-path source-dir "module.rkt")
     (lambda (out)
       (display "#lang racket/base" out))
     #:exists 'truncate/replace)
   (define kind-preview
     (strip-ansi (preview-file source-dir
                               (make-preview-options #:color-mode 'always
                                                     #:directory-sort 'kind))))
   (check-true (regexp-match? #px"notes\\.md +\\( 5 bytes\\)\n\nmodule\\.rkt"
                              kind-preview))
   (define kind-lines
     (filter (lambda (line)
               (not (string=? line "")))
             (string-split kind-preview "\n")))
   (define md-index
     (index-of kind-lines "notes.md        ( 5 bytes)"))
   (define rkt-index
     (index-of kind-lines "module.rkt      (17 bytes)"))
   (define txt-index
     (index-of kind-lines "longer-name.txt ( 5 bytes)"))
   (check-true (exact-nonnegative-integer? md-index))
   (check-true (exact-nonnegative-integer? rkt-index))
   (check-true (exact-nonnegative-integer? txt-index))
   (check-true (< md-index rkt-index))
   (check-true (< rkt-index txt-index))))

(call-with-temp-archive-files
 (lambda (zip-path tar-path tgz-path)
   (define tar-preview
     (strip-ansi (preview-file tar-path
                               (make-preview-options #:color-mode 'always))))
   (check-true (regexp-match? #px"demo\\.zip"
                              (strip-ansi (preview-file zip-path
                                                        (make-preview-options #:color-mode 'always)))))
   (check-true (regexp-match? #px"README\\.md"
                              (strip-ansi (preview-file zip-path
                                                        (make-preview-options #:color-mode 'always)))))
   (check-true (regexp-match? #px"src/"
                              (strip-ansi (preview-file zip-path
                                                        (make-preview-options #:color-mode 'always)))))
   (check-true (regexp-match? #px"1 director"
                              (strip-ansi (preview-file zip-path
                                                        (make-preview-options #:color-mode 'always)))))
   (check-true (regexp-match? #px"main\\.rkt" tar-preview))
   (check-true (regexp-match? #px"note\\.txt" tar-preview))
   (check-true (regexp-match? #px"main\\.rkt"
                              (strip-ansi (preview-file tgz-path
                                                        (make-preview-options #:color-mode 'always)))))
   (define tar-file-lines
     (filter (lambda (line)
               (regexp-match? #px"(main\\.rkt|note\\.txt).+\\( *[0-9]+ bytes\\)" line))
             (string-split tar-preview "\n")))
   (check-equal? (length tar-file-lines) 2)
   (define bytes-columns
     (map (lambda (line)
            (or (regexp-match-positions #px" bytes\\)" line)
                -1))
          tar-file-lines))
   (define bytes-start-columns
     (map (lambda (match-or-false)
            (if (pair? match-or-false)
                (caar match-or-false)
                -1))
          bytes-columns))
   (check-true (andmap exact-nonnegative-integer? bytes-start-columns))
   (check-equal? (car bytes-start-columns)
                 (cadr bytes-start-columns))
   (check-true (regexp-match? #px"demo\\.zip"
                              (or (render-archive-preview (file->bytes zip-path)
                                                          #:path zip-path
                                                          #:color? #f)
                                  "")))
   (check-true (regexp-match? #px"README\\.md"
                              (let ([out (open-output-string)])
                                (preview-port (open-input-bytes (file->bytes zip-path))
                                              zip-path
                                              (make-preview-options #:color-mode 'always)
                                              out)
                                (strip-ansi (get-output-string out)))))))

(check-true (regexp-match? #px"00000000"
                           (render-binary-preview binary-sample)))
(check-true (regexp-match? #px"01000001"
                           (strip-ansi (render-binary-preview binary-sample
                                                            #:bits? #t))))
(check-true (regexp-match? #px"41 42 .*43"
                           (strip-ansi (render-binary-preview binary-sample))))
(check-equal? (strip-ansi (render-binary-preview (string->bytes/utf-8 "abc")
                                                 #:bits? #t
                                                 #:color? #f))
              "00000000  01100001 01100010 01100011                             |abc   |\n")
(check-equal? (strip-ansi (preview-string "abc"
                                         #f
                                         (make-preview-options #:type 'binary
                                                               #:binary-mode 'hex
                                                               #:color-mode 'never)))
              "00000000  61 62 63                                          |abc             |\n")
(check-true (regexp-match? #px"00000000  00000000 00000001"
                           (strip-ansi (call-with-temp-binary-file
                                        binary-sample
                                        (lambda (path)
                                          (preview-file path
                                                        (make-preview-options #:binary-mode 'bits
                                                                              #:color-mode 'always)))))))
(check-true (regexp-match? #px"255;255;255"
                           (render-binary-preview binary-sample
                                                  #:search-bytes (list (bytes 65 66 67)
                                                                       (bytes 196)))))
(check-true (regexp-match? #px"255;255;255"
                           (render-binary-preview (string->bytes/utf-8 "look π!")
                                                  #:search-bytes (list (string->bytes/utf-8 "π")))))
(check-true (regexp-match? #px"00000000"
                           (let ([out (open-output-string)])
                             (preview-port (open-input-bytes binary-sample)
                                           #f
                                           (make-preview-options #:type 'binary
                                                                 #:binary-mode 'hex
                                                                 #:color-mode 'always)
                                           out)
                             (get-output-string out))))
(check-equal? (let ([out (open-output-string)])
                (preview-port (open-input-bytes (string->bytes/utf-8 "hello\n"))
                              #f
                              (make-preview-options #:color-mode 'always)
                              out)
                (get-output-string out))
              "hello\n")
(check-true (regexp-match? #px"00000000"
                           (call-with-temp-binary-file
                            binary-sample
                            (lambda (path)
                              (preview-file path
                                            (make-preview-options #:color-mode 'always))))))
(check-equal? (call-with-temp-binary-file
               (string->bytes/utf-8 "hello\n")
               (lambda (path)
                 (preview-file path
                               (make-preview-options #:color-mode 'always))))
              "hello\n")

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
   "docs: | generated\n"
   "generated:\n"
   "\traco scribble +m --html --dest html scribblings/scribble-tools.scrbl\n"
   "\n"
   "test:\n"
   "\t$(CC) -o app main.o util.o\n"
   "\ttest -n \"$HOME\" && raco test private/lang-code.rkt\n"))

(define shell-operator-sample
  (string-append
   "#!/usr/bin/env bash\n"
   "printf $'line\\n' | cat\n"
   "printf '%s\\n' \"$HOME\" | sed 's/x/y/' && echo done > out.txt\n"
   "cat <<'EOF'\n"
   "line\n"
   "EOF\n"))

(define tex-structure-sample
  (string-append
   "$$x$$ \\(y\\) \\[z\\]\n"
   "\\'e \\; \\par\n"
   "#1 ## #\n"
   "{x}[y]\n"))

(define latex-structure-sample
  (string-append
   "\\begin{itemize}\n"
   "\\item One\n"
   "\\verb|x+y|\n"
   "\\end{itemize}\n"
   "A\\\\\n"))

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
(check-true
 (string-contains? (render-makefile-preview makefile-shell-sample)
                   (string-append ansi-delimiter "|" ansi-reset)))
(check-equal?
 (strip-ansi (render-shell-preview shell-operator-sample
                                   #:shell 'bash))
 shell-operator-sample)
(check-true
 (string-contains? (render-shell-preview shell-operator-sample
                                         #:shell 'bash)
                   (string-append ansi-delimiter "|" ansi-reset)))
(check-true
 (string-contains? (render-shell-preview shell-operator-sample
                                         #:shell 'bash)
                   (string-append ansi-literal "$'line\\n'" ansi-reset)))
(check-true
 (string-contains? (render-shell-preview shell-operator-sample
                                         #:shell 'bash)
                   (string-append ansi-delimiter "&&" ansi-reset)))
(check-true
 (string-contains? (render-shell-preview shell-operator-sample
                                         #:shell 'bash)
                   (string-append ansi-delimiter "<<" ansi-reset)))
(check-equal?
 (strip-ansi (render-tex-preview "\\section{Hi}\nText\n"))
 "\\section{Hi}\nText\n")
(check-equal?
 (strip-ansi (render-latex-preview "\\begin{itemize}\n\\item One\n\\end{itemize}\n"))
 "\\begin{itemize}\n\\item One\n\\end{itemize}\n")
(check-equal?
 (strip-ansi (render-tex-preview tex-structure-sample))
 tex-structure-sample)
(check-true
 (string-contains? (render-tex-preview tex-structure-sample)
                   (string-append ansi-delimiter "$$" ansi-reset)))
(check-true
 (string-contains? (render-tex-preview tex-structure-sample)
                   (string-append ansi-keyword "\\'" ansi-reset)))
(check-true
 (string-contains? (render-tex-preview tex-structure-sample)
                   (string-append ansi-keyword "\\par" ansi-reset)))
(check-equal?
 (strip-ansi (render-latex-preview latex-structure-sample))
 latex-structure-sample)
(check-true
 (string-contains? (render-latex-preview latex-structure-sample)
                   (string-append ansi-identifier "itemize" ansi-reset)))
(check-true
 (string-contains? (render-latex-preview latex-structure-sample)
                   (string-append ansi-literal "|x+y|" ansi-reset)))
(check-true
 (string-contains? (render-latex-preview latex-structure-sample)
                   (string-append ansi-keyword "\\\\" ansi-reset)))
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
(check-equal?
 (strip-ansi (render-go-preview "package main\n// Demo\nfunc main() {\n    println(\"hello\")\n}\n"))
 "package main\n// Demo\nfunc main() {\n    println(\"hello\")\n}\n")
(check-equal?
 (strip-ansi (render-haskell-preview "{-# LANGUAGE OverloadedStrings #-}\nmodule Demo where\nmain = putStrLn \"hello\"\n"))
 "{-# LANGUAGE OverloadedStrings #-}\nmodule Demo where\nmain = putStrLn \"hello\"\n")
(check-true
 (regexp-match? #px"peek"
                (render-plist-preview plist-sample)))
(check-true
 (string-contains? (render-plist-preview plist-sample)
                   (string-append ansi-literal "&amp;" ansi-reset)))
(define java-sample
  (string-append
   "package demo;\n"
   "\n"
   "import java.util.List;\n"
   "\n"
   "/** docs */\n"
   "@Deprecated\n"
   "public class Example {\n"
   "  public static void main(String[] args) {\n"
   "    boolean ok = true;\n"
   "    Object nothing = null;\n"
   "    String text = \"\"\"\n"
   "hello\n"
   "\"\"\";\n"
   "    char c = 'x';\n"
   "    int n = 42;\n"
   "  }\n"
   "}\n"))

(check-equal?
 (strip-ansi (render-java-preview java-sample))
 java-sample)
(check-true
 (regexp-match? #px"\u001b\\["
                (render-java-preview java-sample)))
(check-equal?
 (strip-ansi (preview-string java-sample
                             #f
                             (make-preview-options #:type 'java
                                                   #:color-mode 'always)))
 java-sample)
(check-equal?
 (strip-ansi (preview-file demo-java-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-java-path))
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
(check-equal?
 (strip-ansi (preview-string "package main\n// Demo\nfunc main() {\n    println(\"hello\")\n}\n"
                             #f
                             (make-preview-options #:type 'go
                                                   #:color-mode 'always)))
 "package main\n// Demo\nfunc main() {\n    println(\"hello\")\n}\n")
(check-equal?
 (strip-ansi (preview-string "{-# LANGUAGE OverloadedStrings #-}\nmodule Demo where\nmain = putStrLn \"hello\"\n"
                             #f
                             (make-preview-options #:type 'haskell
                                                   #:color-mode 'always)))
 "{-# LANGUAGE OverloadedStrings #-}\nmodule Demo where\nmain = putStrLn \"hello\"\n")
(check-true
 (regexp-match? #px"answer"
                (render-javascript-preview "const answer = 42;\nobj.run(answer);\n")))
(check-true
 (regexp-match? #px"\u001b\\["
                (render-javascript-preview "const message = `hello, ${name}!`;\n")))
(check-true
 (regexp-match? #px"Button"
                (render-javascript-preview "const el = <Button kind=\"primary\">Hello {name}</Button>;\n"
                                           #:jsx? #t)))
(check-true
 (regexp-match? #px"Title"
                (render-markdown-preview "# Title\n\nText\n")))
(define markdown-heading-sample
  "# One\n## Two\n### Three\n#### Four\n")
(define markdown-section-sample
  (string-append
   "# One\n"
   "Alpha\n"
   "## Two\n"
   "Beta\n"
   "# Three\n"
   "Gamma\n"))
(check-equal?
 (strip-ansi (render-markdown-preview markdown-heading-sample))
 markdown-heading-sample)
(define markdown-heading-rendered
  (render-markdown-preview markdown-heading-sample))
(define markdown-heading-rendered-pretty
  (render-markdown-preview markdown-heading-sample
                           #:pretty? #t))
(define markdown-heading-styles
  (for/list ([heading (in-list '("One" "Two" "Three" "Four"))])
    (define match
      (regexp-match (regexp (format "(\u001b\\[[0-9;]*m)~a\u001b\\[0m"
                                    heading))
                    markdown-heading-rendered))
    (and match
         (cadr match))))
(define markdown-heading-styles-pretty
  (for/list ([heading (in-list '("One" "Two" "Three" "Four"))])
    (define match
      (regexp-match (regexp (format "(\u001b\\[[0-9;]*m)~a\u001b\\[0m"
                                    heading))
                    markdown-heading-rendered-pretty))
    (and match
         (cadr match))))
(check-true (andmap string? markdown-heading-styles))
(check-equal? (length (remove-duplicates markdown-heading-styles))
              4)
(check-true (andmap string? markdown-heading-styles-pretty))
(check-equal? markdown-heading-styles-pretty
              markdown-heading-styles)
(check-equal?
 (strip-ansi markdown-heading-rendered-pretty)
 "One\nTwo\nThree\nFour\n")
(check-equal?
 (extract-markdown-section markdown-section-sample "One")
 "# One\nAlpha\n## Two\nBeta\n")
(check-equal?
 (extract-markdown-section markdown-section-sample "two")
 "## Two\nBeta\n")
(check-equal?
 (extract-markdown-section markdown-section-sample "thr")
 "# Three\nGamma\n")
(check-equal?
 (extract-markdown-section
  (string-append
   "## 1. Problem\n"
   "Alpha\n"
   "### 1.2 Problems with naive lowering\n"
   "Beta\n")
  "problem")
 "## 1. Problem\nAlpha\n### 1.2 Problems with naive lowering\nBeta\n")
(check-equal?
 (parse-git-diff-hunks
  (string-append
   "diff --git a/demo.rkt b/demo.rkt\n"
   "@@ -3,0 +3,2 @@\n"
   "@@ -10,2 +12 @@\n"
   "@@ -20 +21,0 @@\n"))
 (list (git-diff-hunk 3 2)
       (git-diff-hunk 12 1)
       (git-diff-hunk 21 0)))
(check-equal?
 (expand-git-diff-hunks (list (git-diff-hunk 5 2)
                              (git-diff-hunk 8 1)
                              (git-diff-hunk 20 0))
                        30
                        2)
 (list (git-diff-slice 5 3 10)
       (git-diff-slice 20 18 22)))
(check-equal?
 (parse-git-diff-render-hunks
 (string-append
   "diff --git a/demo.rkt b/demo.rkt\n"
   "@@ -2,3 +2,3 @@\n"
   " (define (greet name)\n"
   "-  (string-append \"hello, \" name))\n"
   "+  (string-append \"hello, \" person))\n"
   " (define untouched 1)\n"))
 (list (git-diff-render-hunk
        2
        3
        2
        3
        2
        (list (git-diff-line 'context 2 2 "(define (greet name)")
              (git-diff-line 'removed 3 #f "  (string-append \"hello, \" name))")
              (git-diff-line 'added #f 3 "  (string-append \"hello, \" person))")
              (git-diff-line 'context 4 4 "(define untouched 1)")))))
(check-exn
 exn:fail:user?
 (lambda ()
   (extract-markdown-section markdown-section-sample "Missing")))
(check-equal?
 (strip-ansi (render-markdown-preview "Use `x` and `y`.\n"
                                      #:pretty? #t))
 "Use x and y.\n")
(check-true
 (string-contains? (render-markdown-preview "Use `x` and `y`.\n"
                                            #:pretty? #t)
                   (string-append ansi-literal "x" ansi-reset)))
(check-equal?
 (strip-ansi (render-markdown-preview "[link](dest)\n"
                                      #:pretty? #t))
 "link dest\n")
(check-equal?
 (strip-ansi (render-markdown-preview "![alt](img.png)\n"
                                      #:pretty? #t))
 "alt img.png\n")
(check-equal?
 (strip-ansi (render-markdown-preview "<https://example.com>\n"
                                      #:pretty? #t))
 "https://example.com\n")
(check-equal?
 (strip-ansi (render-markdown-preview "[link](https://example.com \"title\")\n"
                                      #:pretty? #t))
 "link https://example.com — title\n")
(check-true
 (string-contains? (render-markdown-preview "[link](https://example.com \"title\")\n"
                                            #:pretty? #t)
                   (string-append ansi-comment " https://example.com" ansi-reset)))
(check-true
 (string-contains? (render-markdown-preview "[link](https://example.com \"title\")\n"
                                            #:pretty? #t)
                   (string-append ansi-comment " — title" ansi-reset)))
(check-equal?
 (strip-ansi (render-markdown-preview "*em* and **bold** and ~~gone~~\n"
                                      #:pretty? #t))
 "em and bold and gone\n")
(check-equal?
 (strip-ansi (render-markdown-preview "- [ ] todo\n- [x] done\n"
                                      #:pretty? #t))
 "- ☐ todo\n- ☒ done\n")
(check-true
 (string-contains? (render-markdown-preview "- [ ] todo\n"
                                            #:pretty? #t)
                   (string-append ansi-comment "-" ansi-reset)))
(check-equal?
 (strip-ansi (render-markdown-preview "> quote\n"
                                      #:pretty? #t))
 "│ quote\n")
(check-true
 (string-contains? (render-markdown-preview "> quote\n"
                                            #:pretty? #t)
                   (string-append ansi-comment "│ " ansi-reset)))
(check-equal?
 (strip-ansi (render-markdown-preview "---\n"
                                      #:pretty? #t))
 "───\n")
(check-equal?
 (strip-ansi (render-markdown-preview "```racket\n(define x 1)\n```\n"
                                      #:pretty? #t))
 "racket\n(define x 1)\n\n")
(check-equal?
 (strip-ansi (render-markdown-preview "```text\nplain\n```\n"
                                      #:pretty? #t))
 "plain\n\n")
(check-equal?
 (strip-ansi (render-markdown-preview "```text\nplain\n```\n"))
 "```text\nplain\n```\n")
(check-equal?
 (strip-ansi (render-markdown-preview
              (string-append
               "| Name | Role | Score |\n"
               "| :--- | :--: | ---: |\n"
               "| Ada | dev | 37 |\n"
               "| Grace Hopper | lead | 5 |\n")
              #:pretty? #t))
 (string-append
  "| Name         | Role | Score |\n"
  "| :----------- | :--: | ----: |\n"
  "| Ada          | dev  |    37 |\n"
  "| Grace Hopper | lead |     5 |\n"))
(check-equal?
 (strip-ansi (render-markdown-preview
              (string-append
               "| Name | Role | Score |\n"
               "| :--- | :--: | ---: |\n"
               "| Ada | dev | 37 |\n"
               "| Grace Hopper | lead | 5 |\n")))
 (string-append
  "| Name | Role | Score |\n"
  "| :--- | :--: | ---: |\n"
  "| Ada | dev | 37 |\n"
  "| Grace Hopper | lead | 5 |\n"))
(check-equal?
 (strip-ansi (render-markdown-preview "**bold**\n"))
 "**bold**\n")
(check-true
 (string-contains? (render-markdown-preview "**bold**\n")
                   (string-append ansi-keyword "bold" ansi-reset)))
(check-true
 (regexp-match? (regexp (regexp-quote ansi-keyword))
                (render-markdown-preview "```racket\n#lang racket/base\n```\n")))

(define (render-port->string render-proc source)
  (define out (open-output-string))
  (render-proc (open-input-string source) out)
  (get-output-string out))

(define racket-vocabulary-sample
  (string-append
   "(define (group-by-length words)\n"
   "  (for/fold ([ht (hash)]) ([word (in-list words)])\n"
   "    (hash-update ht (string-length word) add1 0)))\n"
   "(define-flow x 1)\n"
   "(let-flow x 1)\n"
   "(for/custom ([x xs]) x)\n"))

(check-equal?
 (strip-ansi (render-racket-preview racket-vocabulary-sample))
 racket-vocabulary-sample)
(check-true
 (regexp-match? (regexp (regexp-quote ansi-keyword))
                (render-racket-preview racket-vocabulary-sample)))
(check-true
 (regexp-match? (regexp (regexp-quote ansi-builtin))
                (render-racket-preview racket-vocabulary-sample)))
(check-equal?
 (strip-ansi (render-port->string render-racket-preview-port
                                  racket-vocabulary-sample))
 racket-vocabulary-sample)
(check-true
 (regexp-match? (regexp (regexp-quote ansi-keyword))
                (render-port->string render-racket-preview-port
                                     racket-vocabulary-sample)))
(check-true
 (regexp-match? (regexp (regexp-quote ansi-builtin))
                (render-port->string render-racket-preview-port
                                     racket-vocabulary-sample)))
(check-equal?
 (strip-ansi (render-scribble-preview
              "@racket[define hash-update string-length define-flow let-flow for/custom]\n"))
 "@racket[define hash-update string-length define-flow let-flow for/custom]\n")
(check-true
 (regexp-match? (regexp (regexp-quote ansi-keyword))
                (render-scribble-preview
                 "@racket[define hash-update string-length define-flow let-flow for/custom]\n")))
(check-true
 (regexp-match? (regexp (regexp-quote ansi-builtin))
                (render-scribble-preview
                 "@racket[define hash-update string-length define-flow let-flow for/custom]\n")))
(check-equal?
 (strip-ansi (render-port->string render-scribble-preview-port
                                  "@racket[define hash-update string-length define-flow let-flow for/custom]\n"))
 "@racket[define hash-update string-length define-flow let-flow for/custom]\n")
(check-true
 (regexp-match? (regexp (regexp-quote ansi-keyword))
                (render-port->string render-scribble-preview-port
                                     "@racket[define hash-update string-length define-flow let-flow for/custom]\n")))
(check-true
 (regexp-match? (regexp (regexp-quote ansi-builtin))
                (render-port->string render-scribble-preview-port
                                     "@racket[define hash-update string-length define-flow let-flow for/custom]\n")))
(define markdown-racket-vocabulary-sample
  (string-append
   "```racket\n"
   "(define (group-by-length words)\n"
   "  (for/fold ([ht (hash)]) ([word (in-list words)])\n"
   "    (hash-update ht (string-length word) add1 0)))\n"
   "(define-flow x 1)\n"
   "(let/custom ([x xs]) x)\n"
   "(for/custom ([x xs]) x)\n"
   "```\n"))

(check-equal?
 (strip-ansi (render-markdown-preview markdown-racket-vocabulary-sample))
 markdown-racket-vocabulary-sample)
(check-true
 (regexp-match? (regexp (regexp-quote ansi-keyword))
                (render-markdown-preview markdown-racket-vocabulary-sample)))
(check-true
 (regexp-match? (regexp (regexp-quote ansi-builtin))
                (render-markdown-preview markdown-racket-vocabulary-sample)))
(check-equal?
 (strip-ansi (render-port->string render-markdown-preview-port
                                  markdown-racket-vocabulary-sample))
 markdown-racket-vocabulary-sample)
(check-equal?
 (strip-ansi (render-port->string (lambda (in out)
                                    (render-markdown-preview-port in
                                                                  out
                                                                  #:pretty? #t))
                                  "Use `x` and `y`.\n"))
 "Use x and y.\n")
(check-equal?
 (strip-ansi (render-port->string (lambda (in out)
                                    (render-markdown-preview-port in
                                                                  out
                                                                  #:pretty? #t))
                                  "[link](dest)\n"))
 "link dest\n")
(check-equal?
 (strip-ansi (render-port->string render-markdown-preview-port
                                  "**bold**\n"))
 "**bold**\n")
(check-true
 (string-contains? (render-port->string render-markdown-preview-port
                                        "**bold**\n")
                   (string-append ansi-keyword "bold" ansi-reset)))
(check-true
 (regexp-match? (regexp (regexp-quote ansi-keyword))
                (render-port->string render-markdown-preview-port
                                     markdown-racket-vocabulary-sample)))
(check-true
 (regexp-match? (regexp (regexp-quote ansi-builtin))
                (render-port->string render-markdown-preview-port
                                     markdown-racket-vocabulary-sample)))
(check-true
 (regexp-match? (regexp (regexp-quote ansi-keyword))
                (render-shell-preview "grep --ignore-case pattern file\n"
                                      #:shell 'bash)))
(define markdown-embedded-samples
  (list
   (string-append "```c\n#include <stdio.h>\n```\n")
   (string-append "```json\n{\"name\": \"peek\"}\n```\n")
   (string-append "```pascal\nprogram Demo;\nbegin\nend.\n```\n")
   (string-append "```python\ndef answer(name):\n    return name\n```\n")
   (string-append "```rust\nfn greet() {}\n```\n")
   (string-append "```shell\nprintf '%s\\n' \"$HOME\"\n```\n")
   (string-append "```yaml\nname: peek\n```\n")
   (string-append "```csv\nname,age\nAda,37\n```\n")
   (string-append "```tsv\nname\tage\nAda\t37\n```\n")))
(for ([sample (in-list markdown-embedded-samples)])
  (check-equal?
   (strip-ansi (render-markdown-preview sample))
   sample))
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
(check-equal?
 (strip-ansi (render-markdown-preview "```go\npackage main\nfunc main() {}\n```\n"))
 "```go\npackage main\nfunc main() {}\n```\n")
(check-equal?
 (strip-ansi (render-markdown-preview "```java\nclass Demo {}\n```\n"))
 "```java\nclass Demo {}\n```\n")
(check-equal?
 (strip-ansi (render-markdown-preview "```haskell\nmain = putStrLn \"hello\"\n```\n"))
 "```haskell\nmain = putStrLn \"hello\"\n```\n")
(check-equal?
 (strip-ansi (preview-file demo-haskell-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-haskell-path))
(check-equal?
 (strip-ansi (preview-file demo-go-path
                           (make-preview-options #:color-mode 'always)))
 (file->string demo-go-path))
(check-true
 (regexp-match? #px"export"
                (render-shell-preview "#!/usr/bin/env bash\nexport PATH\n"
                                      #:shell 'bash)))
(check-true
 (regexp-match? (regexp (regexp-quote ansi-keyword))
                (render-markdown-preview "```racket\n#lang racket/base\n```\n")))
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
   (preview-port (open-input-string ".card { color: #2f7ea0; }\n")
                 "example.css"
                 (make-preview-options #:color-mode 'always
                                       #:swatches? #f)
                 out)
   (regexp-match? #px"\u001b\\[" (get-output-string out))))
(check-equal?
 (let ([out (open-output-string)])
   (preview-port (open-input-string ".card { color: #2f7ea0; }\n")
                 "example.css"
                 (make-preview-options #:color-mode 'always
                                       #:swatches? #f)
                 out)
   (strip-ansi (get-output-string out)))
 ".card { color: #2f7ea0; }\n")
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
   (preview-port (open-input-string "alpha\nbeta\n")
                 #f
                 (make-preview-options #:color-mode 'never
                                       #:line-numbers? #t)
                 out)
   (get-output-string out))
 "     1\talpha\n     2\tbeta\n")

(check-equal?
 (let ([out (open-output-string)])
   (preview-port (open-input-string "alpha\nbeta\ngamma\n")
                 #f
                 (make-preview-options #:color-mode 'never
                                       #:grep-patterns (list #rx"et"))
                 out)
   (get-output-string out))
 "alpha\n> beta\ngamma\n")

(call-with-temp-directory
 (lambda (dir)
   (define numbered-path
     (build-path dir "numbered.rkt"))
   (call-with-output-file numbered-path
     (lambda (out)
       (display "a\nb\nc\nd\ne\n" out))
     #:exists 'truncate/replace)
   (define out
     (open-output-string))
   (preview-path-port numbered-path
                      (make-preview-options #:color-mode 'never
                                            #:line-numbers? #t)
                      out)
   (check-equal? (get-output-string out)
                 " 1\ta\n 2\tb\n 3\tc\n 4\td\n 5\te\n")))

(call-with-temp-directory
 (lambda (dir)
   (define grep-path
     (build-path dir "grep.rkt"))
   (call-with-output-file grep-path
     (lambda (out)
       (display "alpha\nbeta\ngamma\n" out))
     #:exists 'truncate/replace)
   (define out
     (open-output-string))
   (preview-path-port grep-path
                      (make-preview-options #:color-mode 'never
                                            #:grep-patterns (list #rx"mm")
                                            #:line-numbers? #t)
                      out)
   (check-equal? (get-output-string out)
                 " 1\talpha\n 2\tbeta\n 3\t> gamma\n")))

(call-with-temp-git-repo
 (lambda (dir)
   (define source-path
     (build-path dir "demo.rkt"))
   (call-with-output-file source-path
     (lambda (out)
       (display "#lang racket/base\n" out)
       (display "(define (greet name)\n" out)
       (display "  (string-append \"hello, \" name))\n" out)
       (display "(define untouched 1)\n" out))
     #:exists 'truncate/replace)
   (parameterize ([current-directory dir])
     (check-true (system* git-executable "add" "demo.rkt"))
     (check-true (system* git-executable "commit" "-q" "-m" "initial")))
   (call-with-output-file source-path
     (lambda (out)
       (display "#lang racket/base\n" out)
       (display "(define (greet person)\n" out)
       (display "  (string-append \"hello, \" person))\n" out)
       (display "(define added 2)\n" out))
     #:exists 'truncate/replace)
   (define colored-rendered
     (preview-file source-path
                   (make-preview-options #:color-mode 'always
                                         #:diff? #t)))
   (define rendered
     (strip-ansi colored-rendered))
   (check-true (regexp-match? #px"^diff .*demo\\.rkt\n\n@@ -1,4 \\+1,4 @@"
                              rendered))
   (check-true (regexp-match? #px"@@ -1,4 \\+1,4 @@"
                              rendered))
   (check-true (string-contains? colored-rendered
                                 (string-append ansi-malformed "- " ansi-reset)))
   (check-true (string-contains? colored-rendered
                                 (string-append ansi-comment "+ " ansi-reset)))
   (check-true (regexp-match? #px"person"
                              rendered))
   (check-true (regexp-match? #px"added"
                              rendered))
   (check-true (regexp-match? #px"- \\(define untouched 1\\)"
                              rendered))
   (check-false (regexp-match? #px"no changed hunks"
                               rendered))
   (define numbered
     (strip-ansi (preview-file source-path
                               (make-preview-options #:color-mode 'always
                                                     #:diff? #t
                                                     #:line-numbers? #t))))
   (check-true (string-contains? numbered
                                 (string-append
                                  "Example: @@ -1,4 +1,4 @@ means:\n"
                                  "old file lines 1..4 (4 lines)\n"
                                  "new file lines 1..4 (4 lines)\n")))
   (check-true (regexp-match? #px"^diff .*demo\\.rkt\n\nExample: @@ -1,4 \\+1,4 @@ means:\nold file lines 1\\.\\.4 \\(4 lines\\)\nnew file lines 1\\.\\.4 \\(4 lines\\)\n\n@@ -1,4 \\+1,4 @@\n  1\t#lang racket/base\n- 2\t\\(define \\(greet name\\)"
                              numbered))
   (check-true (string-contains? numbered
                                 "- 4\t(define untouched 1)\n"))
   (check-true (string-contains? numbered
                                 "+ 3\t  (string-append \"hello, \" person))\n"))
   (check-true (string-contains? numbered
                                 "+ 4\t(define added 2)\n"))))

(call-with-temp-git-repo
 (lambda (dir)
   (define source-path
     (build-path dir "clean.rkt"))
   (call-with-output-file source-path
     (lambda (out)
       (display "#lang racket/base\n(define x 1)\n" out))
     #:exists 'truncate/replace)
   (parameterize ([current-directory dir])
     (check-true (system* git-executable "add" "clean.rkt"))
     (check-true (system* git-executable "commit" "-q" "-m" "clean")))
   (check-equal?
    (strip-ansi (preview-file source-path
                              (make-preview-options #:color-mode 'always
                                                    #:diff? #t)))
    (format "No changed hunks in ~a.\n"
            source-path))))

(call-with-temp-git-repo
 (lambda (dir)
   (define source-path
     (build-path dir "demo.html"))
   (call-with-output-file source-path
     (lambda (out)
       (display "<body>\n" out)
       (display "  <script>\n" out)
       (display "  const value = 1;\n" out)
       (display "  </script>\n" out)
       (display "</body>\n" out))
     #:exists 'truncate/replace)
   (parameterize ([current-directory dir])
     (check-true (system* git-executable "add" "demo.html"))
     (check-true (system* git-executable "commit" "-q" "-m" "initial")))
   (call-with-output-file source-path
     (lambda (out)
       (display "<body>\n" out)
       (display "  <script>\n" out)
       (display "  const value = 2;\n" out)
       (display "  </script>\n" out)
       (display "</body>\n" out))
     #:exists 'truncate/replace)
   (define rendered
     (preview-file source-path
                   (make-preview-options #:color-mode 'always
                                         #:diff? #t)))
   (check-true (regexp-match? #px"\u001b\\[" rendered))
   (check-true (regexp-match? #px"const" (strip-ansi rendered)))
   (check-true (regexp-match? #px"\u001b\\[[0-9;]*mconst" rendered))))

(check-equal?
 (let ([out (open-output-string)])
   (preview-port (open-input-string "<!doctype html><main id=\"app\">Hi</main>\n")
                 "index.html"
                 (make-preview-options #:color-mode 'always)
                 out)
   (strip-ansi (get-output-string out)))
 "<!doctype html><main id=\"app\">Hi</main>\n")

(check-equal?
 (let ([out (open-output-string)])
   (preview-port (open-input-string markdown-section-sample)
                 "example.md"
                 (make-preview-options #:color-mode 'never
                                       #:section "Three")
                 out)
   (get-output-string out))
 "# Three\nGamma\n")

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
(check-true
 (regexp-match? #px"\u001b\\["
                (preview-file demo-pascal-path
                              (make-preview-options #:color-mode 'always))))
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
(check-true
 (regexp-match? #px"\u001b\\["
                (preview-file demo-rust-path
                              (make-preview-options #:color-mode 'always))))
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
(check-equal?
 (strip-ansi (preview-string "Use `x` and `y`.\n"
                             "README.md"
                             (make-preview-options #:color-mode 'always
                                                   #:pretty? #t)))
 "Use x and y.\n")
(check-equal?
 (strip-ansi (preview-string "![alt](img.png)\n"
                             "README.md"
                             (make-preview-options #:color-mode 'always
                                                   #:pretty? #t)))
 "alt img.png\n")
(check-equal?
 (strip-ansi (preview-string "```racket\n(letrec ([x e])\n  body)\n```\n"
                             "README.md"
                             (make-preview-options #:color-mode 'always
                                                   #:pretty? #t)))
 "racket\n(letrec ([x e])\n  body)\n\n")
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
