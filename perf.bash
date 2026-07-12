bash -c 'luajit -jp=l-3si1m10 server.lua & pid=$!; hey -z 5s -c 200 http://localhost:3000; kill -INT "$pid"; wait "$pid"'
