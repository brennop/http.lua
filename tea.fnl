(local socket (require :socket))

(local server (socket.bind "*" 8080))

(local tea {:handlers {:get {}}})

(global prettyprint
        (fn [x]
          (print ((. (require :fennel) :view) x))))

(fn find [tbl matcher]
  (accumulate [result nil key value (pairs tbl)]
    (match [result (matcher key)]
      [nil _] [key value]
      [nil nil] nil
      [[_key _value] b]
      (if (> (length (matcher _key)) (matcher b)) [_key _value] [key value]))))

(fn first [[value & _]]
  value)
(fn find-handler [tbl matcher]
  (-> (doto (icollect [key value (pairs tbl)]
              (match (matcher key)
                matched [value (length matched)]))
        (table.sort (fn [[_ a] [_ b]]
                      (> a b))))
      (first)
      (first)))

(fn line-iter [client]
  (fn [_ control]
    (let [(line err) (client:receive)]
      (if err (error err)
          (= line "") nil
          line))))

(fn parse-headers [lines]
  (collect [_ line (ipairs lines)]
    (line:match "([%a-]+)%s*:%s*(%g+)")))

(fn parse-request [lines]
  (let [[reqline & rest] lines
        (method uri version) (reqline:match "(%u+)%s([%p%w]+)%s(HTTP/1.1)")
        headers (parse-headers rest)]
    {: method : uri : version : headers}))

; (fn read-request [client header]
;   (let [(body err) (client:receive (. header :headers :Content-Length))]
;     (if err (error err) (assoc header :body body))))

;; TODO: map status to strings
(fn get-status [status]
  :OK)

;; TODO: add headers
(fn serialize [status data]
  (table.concat [(table.concat [:HTTP/1.1 status (get-status status)] " ")
                 ""
                 ""
                 data
                 ""] "\r\n"))

(fn tea.handle-get [self req]
  (let [{: method : uri} req]
    (match (find self.handlers.get #(uri:match $))
      handler (serialize 200 (handler req (uri:match)))
      nil "HTTP/1.1 404 Not Found\r\n")))

(fn tea.handle-request [self req]
  (let [{: method} req]
    (match method
      :GET (self:handle-get req)
      _ "HTTP/1.1 405 Method Not Allowed\r\n")))

(fn tea.get [self path handler]
  (tset self :handlers :get path handler))

(fn tea.start [self]
  (while true
    (let [client (server:accept)
          _ (client:settimeout 10)
          lines (icollect [line (line-iter client)]
                  line)
          request (parse-request lines) ; request (read-request client header)
          response (self:handle-request request)]
      (client:send response)
      (client:close))))

tea
