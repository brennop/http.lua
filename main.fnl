;; TODO: handle errors
(fn handle-get [uri]
  (with-open [file (io.open uri)]
    (file:read :a)))

(local tea (require :tea))

(tea:get "/" #"Hello World")
(tea:get "/:name" #"New")

(tea:start)
