function [v] = remove_negs(v)
    v(v < 0) = 0;
end