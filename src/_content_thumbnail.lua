local hikaru = require("hikaru")
hikaru.thumbnail(
    ngx.var.signature,
    ngx.var.width,
    ngx.var.height,
    ngx.var.cast,
    ngx.var.name,
    ngx.var.ext
);