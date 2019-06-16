module("hikaru", package.seeall)


local config = require("hikaru_config");
local array_helper = require("array_helper");

-- ------------------------------------------------------------------------------------------------------------------ --
-- CONSTANTS
-- ------------------------------------------------------------------------------------------------------------------ --

local NO_ALPHA_FORMATS = {'JPG', 'JPEG', 'JP2', 'BMP'};


-- CAST flags
local CAST_RESIZE_TENSILE = 2;  -- Растяжение
local CAST_RESIZE_PRECISE = 4;  -- Вписывает в нужный размер по максимуму
local CAST_RESIZE_INVERSE = 8; -- Вписывает в нужный размер по минимуму

local CAST_TRIM = 16;              -- Обрезает поля изображения
local CAST_EXTENT = 32;            -- Устанавливает канву изрбражения нужного размера
local CAST_OPAGUE_BACKGROUND = 64; -- Установить непрозрачный задний фон

-- ------------------------------------------------------------------------------------------------------------------ --

local function ngx_exit_status(message , status)
    ngx.status = status;
    if message then
        ngx.header["X-HIKARU-Message"] = message;
    end;
    ngx.exit(0)
end

-- ------------------------------------------------------------------------------------------------------------------ --

-- security signature generator
local function generate_signature(salt, width, height, cast, name)
    return ngx.md5(salt .. width .. height .. cast .. name);
end;

-- ------------------------------------------------------------------------------------------------------------------ --

-- binary and for cast marker
local function is_cast(cast, check)
    local bit32 = require "bit32";
    return bit32.band(cast, check) ~= 0;
end;

-- ------------------------------------------------------------------------------------------------------------------ --

-- creates a storage path and filename path
-- eg 02/c4/02c425157ecd32f259548b33402ff6d3
function get_storage_path_filename(original_filename, part)
    part = part or "full";
    local digest = ngx.md5(original_filename);
    local path = string.sub(digest, 1, 2) .. "/" .. string.sub(digest, 3, 4);

    if part == "path" then
        return path;
    elseif part == "filename" then
        return digest;
    end

    return path .. "/" .. digest;
end;

-- ------------------------------------------------------------------------------------------------------------------ --

-- create image thumbnail and point nginx to it
function thumbnail(signature, width, height, cast, name, ext)
    -- check signature
    if signature ~= generate_signature(config.signature_salt, width, height, cast, name) then
        ngx_exit_status("Invalid signature", ngx.HTTP_FORBIDDEN);
    end

    local storage_path = get_storage_path_filename(name, "path");
    local storage_filename = get_storage_path_filename(name, "filename");
    local original_filename = ngx.var.hikaru_sources_path .. "/" .. get_storage_path_filename(name);
    local destination_path = ngx.var.hikaru_thumbnails_path .. "/" .. width .. 'x' .. height .. "/" .. cast .. "/" .. storage_path;
    local destination_filename = destination_path .. "/" .. storage_filename .. "." .. ext;

    -- check if original file exists
    local file = io.open(original_filename);
    if not file then
        ngx_exit_status("Original file not found", ngx.HTTP_NOT_FOUND);
    end
    file:close();

    -- create cache dirs recursively
    os.execute( "mkdir -p " .. destination_path);

    -- implement ImageMagick
    local imagick = require "imagick"

    -- open image file
    local image, error = imagick.open(original_filename);
    if error ~= nil then
        ngx_exit_status(error, ngx.HTTP_INTERNAL_SERVER_ERROR);
    end

    -- strip image info
    image:strip();

    local original_format = string.upper(image:get_format());
    local destination_format = string.upper(ext);
    local i_cast = tonumber(cast);

    -- coalesce multiframe source
    if original_format == "GIF" then
        image:coalesce();
    end

    -- opague background if needed
    if is_cast(i_cast, CAST_OPAGUE_BACKGROUND) or (image:has_alphachannel() and array_helper.array_has_value(NO_ALPHA_FORMATS, destination_format)) then
        local bgimage = imagick.open_pseudo(image:width(), image:height(), "canvas:white");
        bgimage:composite(image, 0, 0, imagick.composite_op["AlphaCompositeOp"]);
        image:deconstruct();
        image = bgimage;
    end

    -- trim image if needed
    if is_cast(i_cast, CAST_TRIM) then
        image:trim(0);
    end

    -- resize image
    local force_extent = false;
    local i_width = tonumber(width);
    local i_height = tonumber(height);

    if i_width > 0 or i_height > 0 then
        local resize_flag = "-";

        if i_width == 0 then
            resize_flag = "!";
            i_width = math.floor(image:width() * i_height / image:height());
        elseif height == 0 then
            resize_flag = "!";
            i_height = math.floor(image:height() * i_width / image:width());
        else
            if is_cast(i_cast, CAST_RESIZE_TENSILE) then
                -- ignore aspect ratio
                resize_flag = "!";
            elseif is_cast(i_cast, CAST_RESIZE_PRECISE) then
                -- use higher dimension
                resize_flag = "^";
            elseif is_cast(i_cast, CAST_RESIZE_INVERSE) then
                -- use lower dimension
                resize_flag = "";
            else
                force_extent = true;
            end
        end

        if resize_flag ~= "-" then
            image:smart_resize(i_width .. 'x' .. i_height .. resize_flag);
        end
    else
        i_width = image:width();
        i_height = image:height();
    end

    -- new canvas size
    if force_extent or is_cast(i_cast, CAST_EXTENT) then
        image:set_gravity(imagick.gravity["CenterGravity"]);
        image:extent(i_width, i_height);
    end

    -- choose quality
    local quality = config.default_quality;
    if config.quality[ext] ~= nil then
        if type(config.quality[ext]) ~= "table" then
            quality = tonumber(config.quality[ext]);
        else
            if config.quality[ext]["default"] ~= nil then
                quality = config.quality[ext]["default"];
            end

            local whsum = image:width() + image:height();

            for _,k in pairs(array_helper.array_sorted_keys(config.quality[ext])) do
                local whs = tonumber(k);

                if whs ~= nil and whsum < whs then
                    quality = tonumber(config.quality[ext][k]);
                    break
                end
            end
        end
    end
    if quality <= 0 then
        quality = config.default_quality;
    end

    -- save image
    if original_format == "GIF" and (destination_format == "GIF" or destination_format == "WEBP") then
        -- ImageMagick lib cannot save animated webp now
        if destination_format == "WEBP" then
            local temp_destination_filename = destination_filename .. '.gif';

            image:write_all(temp_destination_filename, true)

            os.execute( "gif2webp " .. temp_destination_filename .. " -o " .. destination_filename .. " -q " .. quality);
            os.remove(temp_destination_filename);
        else
            image:write_all(destination_filename, true)
        end
    else
        image:write(destination_filename)
    end

    -- read generated file and show it user via standart nginx
    ngx.exec("@hikaru_after_resize")
end;

-- ------------------------------------------------------------------------------------------------------------------ --

-- upload image into storage
-- works with nginx body file
function upload(name)

    local storage_path = get_storage_path_filename(name, "path");
    local storage_filename = get_storage_path_filename(name, "filename");
    local destination_path = ngx.var.hikaru_sources_path .. "/" .. storage_path;
    local destination_filename = destination_path .. "/" .. storage_filename;

    -- check if destination file exists
    local file = io.open(destination_filename);
    if file then
        file:close();
        ngx_exit_status("File already exists", ngx.HTTP_FORBIDDEN)
    end

    -- read request body
    ngx.req.read_body()

    -- as nginx config, request body locates only in file
    local body_filename = ngx.req.get_body_file();
    if not body_filename then
        ngx_exit_status("Body file not found", ngx.HTTP_INTERNAL_SERVER_ERROR);
    end;

    -- create dirs recursively
    os.execute( "mkdir -p " .. destination_path);

    -- copy file contents into destination using os
    os.execute("cp " .. body_filename .. " " .. destination_filename);

    -- successfull completion with 201 status
    ngx_exit_status(nil, ngx.HTTP_CREATED)
end;

-- ------------------------------------------------------------------------------------------------------------------ --

-- remove source file and all thumbnails
function remove(name)
    local storage_path = get_storage_path_filename(name, "path");
    local storage_filename = get_storage_path_filename(name, "filename");

    -- delete source image
    os.execute("rm -f " .. ngx.var.hikaru_sources_path .. "/" .. storage_path .. "/" .. storage_filename);

    -- delete all cached thumbnails
    os.execute("find " .. ngx.var.hikaru_thumbnails_path .. " -name " .. storage_filename .. ".* -delete");

    -- successfull completion with 200 status
    ngx_exit_status(nil, ngx.HTTP_OK)
end;
