(local socket (require :socket))

(local server (socket.bind "*" 8080))

(fn copy [tbl]
  (collect [k v (pairs tbl)]
    (if (= (type v) :table) (copy v) v)))

(fn assoc [tbl k v]
  (let [new (copy tbl)]
    (tset new k v)
    new))

(global prettyprint
        (fn [x]
          (print ((. (require :fennel) :view) x))))

(fn line-iter [client]
  (fn [_ control]
    (let [(line err) (client:receive)]
      (if err (error err)
          (= line "") nil
          line))))

(local header-patt "([%a-]+)%s*:%s*(%g+)")
(fn parse-headers [lines]
  (collect [_ line (ipairs lines)]
    (line:match header-patt)))

(local reqline-patt "(%u+)%s([%p%w]+)%s(HTTP/1.1)")
(fn parse-request [lines]
  (let [[reqline & rest] lines
        (method uri version) (reqline:match reqline-patt)
        headers (parse-headers rest)]
    {: method : uri : version : headers}))

(fn read-request [client header]
  (let [(body err) (client:receive (. header :headers :Content-Length))]
    (if err (error err) (assoc header :body body))))

(fn handle-request [req]
  (let [{: method : uri} req]
    (match method
      :GET "HTTP/1.1 200 OK\r\nHello World\r\n"
      _ "HTTP/1.1 405 Method Not Allowed\r\n")))

(fn start []
  (while true
    (let [client (server:accept)
          _ (client:settimeout 10)
          lines (icollect [line (line-iter client)]
                  line)
          request (parse-request lines)
          ; request (read-request client header)
          response (handle-request request)]
      (client:send response)
      (client:close))))

(start)
