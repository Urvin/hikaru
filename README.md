# Hikaru thumbnail server

[Nginx][nginx] / LUA / [ImageMagick][imagemagick] - based seo-friendly lightweight thumbnail server

## Requirements
* [Openresty][openresty] or [Nginx][nginx] with compiled nginx-lua module
* [Lua IMagick][lua-imagick] library
* bit32 lua library

## Installation
- Install common tools
```bash
# nginx with lua
sudo apt-get install nginx-extras

# lua-imagick requirements
sudo apt-get install libluajit-5.1-dev
sudo apt-get install cmake
sudo apt-get install g++
sudo apt-get install imagemagick
sudo apt-get install libmagickwand-dev

# own requirements
sudo apt-get install luarocks
sudo luarocks install bit32
```
- Build Lua Imagick as [described][lua-imagick] in it's readme
- Update settings src/hikaru_config.lua
- Configure src/nginx.conf as you need
- Add Hikaru part into your nginx server config
```bash
sudo ls -s /path/to/hikaru/nginx.conf /etc/nginx/sites-enabled/hikaru
```

## Usage
### Upload image
Make a PUT request with body containing image data to /upload/your_image_name
Server responses a 201/Created status in success

Via curl:
```bash
curl -i http://hikaru.local/upload/test_image --upload-file /path/to/local/image.jpg
```

### Get thumbnail
**Define your image width and height**
If you want to get an image with 200px width and no matter height, set height to 0. Thumbnailer will calculate it using original image aspect ratio. The same works with width.
If you set to 0 both params, the source width and height will be used.

**Define cast flag**
The resulting cast flag should be an integer, obtained via bitwise OR among available cast flags.

**Calculate security signature**
Signature is a md5 hash of concatenated stings of salt, width, height, cast, filename without extension
```bash
# salt = secretsalt
# with = 100
# height = 200
# cast = 8
#filename = test_image.jpg
echo -n secretsalt1002008test_image | md5sum
```
**Define desired thumbnail format**
Note that Hikaru sends WEBP format to browser accepting image/webp regardless your extension.

**Combine parts of your URL**
Request /signature/widthxheight/cast/filename.extension one
```bash
wget http://hikaru.local/07b58ae7ccbd896f85c39a5cd4eb06ec/100x150/4/test_image.jpg
```
### Cast flags
- _CAST_RESIZE_TENSILE = 2_ - stretch image directly into defined width and height ignoring aspect ratio
- _CAST_RESIZE_PRECISE = 4_ - keep aspect-ratio, use higher dimension
- _CAST_RESIZE_INVERSE = 8_ - keep aspect-ratio, use lower dimension
- _CAST_TRIM = 16_ - remove any edges that are exactly the same color as the corner pixels
- _CAST_EXTENT = 32_ - set output canvas exactly defined width and height after image resize
- _CAST_OPAGUE_BACKGROUND = 64_ - set image white opaque background

### Remove image
Make a DELETE request to /remove/your_image_name. Hikaru removes both source and thumbnail files.
Server responses a 200/Ok status in success.

Via curl:
```bash
curl -i http://hikaru.local/remove/test_image
```

### Robots.txt
Hikaru provides valid seo-friendly robots.txt
 ```bash
curl http://hikaru.local/robots.txt
 ```

## Clients
- [Phikaru][phikaru] PHP client

## Author
Yuriy Gorbachev <yuriy@gorbachev.rocks>

## License
This module is licensed under the [GLWTPL][license] license.

[nginx]:<http://nginx.org>
[imagemagick]:<https://www.imagemagick.org>
[lua-imagick]:<https://github.com/isage/lua-imagick>
[openresty]:<https://openresty.org>
[license]:<https://github.com/me-shaon/GLWTPL>
[phikaru]:<https://github.com/Urvin/phikaru>