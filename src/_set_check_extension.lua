-- prepare extension
local ext = string.lower(ngx.var.ext);

-- check if client accepts webp
if ext ~= "webp" and string.find(ngx.var.http_accept, "webp") then
    -- force webp thumbnail
    ngx.header["Vary"] = "Accept";
    ext = "webp";
end;

return ext;