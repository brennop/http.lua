(local http (require :http))

(fn read-file [filename]
  (with-open [file (io.open filename)]
    (file:read :a)))

(http.get "/" #"Hello World")
(http.get "/(%g+).md" (fn [req name]
                    (match (pcall read-file (.. name ".md"))
                      (true content) {:status 200 :body content}
                      (false _) {:status 404 :body ""})))

(http.listen 8080)
