express = require "express"
app = express()

app.use express.logger()
app.use express.static "public"
app.get "/", (req, res) ->
  res.sendfile "public/index.html"

app.listen 3000
console.log "http://localhost:3000"

