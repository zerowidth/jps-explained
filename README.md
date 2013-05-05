# Jump Point Search Explained

There here mess o' coffeescript is for a blog post on
[zerowidth.com](http://zerowidth.com) explaining how JPS works. The
code ain't pretty, but I tried to make certain pieces reusable for both static
and interactive diagrams.

`index.html` contains draft versions of most of the diagrams I ended up using.

I wouldn't suggest dropping this wholesale into your own javascript project, as
the search algorithm implementation was designed with visualization in mind, not
efficiency. Also there's some pretty tight coupling between all the objects
here. However, I hope it can serve as a reference, especially the
`JumpPointSuccessors` bit. For another take, this time in questionable clojure
code, see my [hansel project](https://github.com/zerowidth/hansel). If you need
a real javascript pathfinding library, see
[PathFinding.js](https://github.com/qiao/PathFinding.js).

This code is symlinked into my jekyll blog (currently private) for inclusion in
the final post.

To run this thing:

```sh
npm install
coffee app.coffee
```

and open [http://localhost:3000](http://localhost:3000).

Released under the MIT license.
