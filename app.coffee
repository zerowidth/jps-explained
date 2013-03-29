express = require "express"
coffeescript = require "connect-coffee-script"

app = express()

app.use express.logger()
app.use coffeescript src: "lib", dest: "public/compiled", prefix: "/compiled", force: true
app.use express.static "public"
app.get "/", (req, res) ->
  res.sendfile "public/index.html"

app.listen 3000
console.log "http://localhost:3000"

