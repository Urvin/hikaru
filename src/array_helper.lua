module("array_helper", package.seeall)

function array_has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true;
        end;
    end;
    return false;
end

function array_sorted_keys(array, sort_function)
    local keys, len = {}, 0;
    for k,_ in pairs(array) do
        len = len + 1;
        keys[len] = k;
    end;
    table.sort(keys, sort_function);
    return keys;
end