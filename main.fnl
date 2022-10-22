(local socket (require :socket))

(local server (socket.bind "*" 8080))

(fn line-iter [client]
  (fn []
    (let [(line err) (client:receive)]
      (if err nil
          (= line "") nil
          line))))

(local reqline-patt "(%u+)%s([%p%w]+)%s(HTTP/1.1)")
(fn parse-request [lines]
  (let [[reqline & rest] lines
        (method uri version) (reqline:match reqline-patt)]
    (print method)))

(while true
  (let [client (server:accept)
        lines (icollect [line (line-iter client)]
                line)]
    (parse-request lines)
    (client:send "HTTP/1.1 200 OK\r\n")
    (client:close)))
