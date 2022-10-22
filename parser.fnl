(local lpeg (require :lpeg))
(local {: P : S : C : Cg : Ct : Cf : Cc} lpeg)
(lpeg.locale lpeg)

(local sp lpeg.space)
(local ws (^ lpeg.space 0))

(local cr (P "\r"))
(local lf (P "\n"))
(local crlf (* cr lf))

(local method (Cg (P :GET) :method))
(local uri (Cg (^ (+ lpeg.alpha (S "./?=[]%")) 1) :uri))
(local version (Cg (P :HTTP/1.1) :version))

(local header-key (Cg (^ (+ lpeg.alpha (S "-")) 1) :key))
(local header-value (Cg (^ (+ lpeg.alpha lpeg.digit (S " ,.;:!?")) 1) :value))

(local header (Ct (* header-key ws ":" ws header-value crlf)))
(local headers (Cf (* (Cc {}) (^ header 0))
                   (fn [acc {: key : value}]
                     (tset acc key value)
                     acc)))

(local reqline (Ct (* method sp uri sp version crlf)))

(local request (Ct (* reqline headers crlf)))

{:parse (fn [data]
          (request:match data))}
