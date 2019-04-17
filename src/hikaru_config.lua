module("hikaru_config", package.seeall)

-- secret salt for image thumbnailing
signature_salt = "not_safe";

-- fallback image compression quality
default_quality = 80;

-- image compression quality for each format, can be extended for any width+height sum
quality = {
    JPG = 80,
    JPEG = 80,
    PNG = 90,
    WEBP = {
        default = 80,
        ["1000"] = 90,
        ["1800"] = 85,
        ["2600"] = 80
    }
};