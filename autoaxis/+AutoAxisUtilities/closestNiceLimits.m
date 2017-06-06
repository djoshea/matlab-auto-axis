function [vals, increment] = closestNiceLimits(vals, allowUp, allowDown, scale)
% rounds to closest nice number like 0.1, 0.2, 0.5, 1 * 10^#
% allowUp and allowDown are logical the same size as vals and indiciate
% whether roundingUp and roundingDown are permitted
%
% scales is optional, and sets the "relevant scale" of differences between
% vals and the closest nice numbers. If scale is 1000, then nice numbers
% have spacing 100 and look like 100, 200, 500, 1000, 2000, 5000, 10000, 
% so a mapping would be:
%   993 --> 500 or 1000
%   0.2 --> 0 or 100
%   23010 --> 23000 or 24000

    assert(isvector(vals), 'Values must be vector');
    
    if nargin < 2  || isempty(allowUp)
        allowUp = true(size(vals));
    elseif isscalar(allowUp)
        if allowUp
            allowUp = true(size(vals));
        else
            allowUp = false(size(vals));
        end
    end
    
    if nargin < 3 || isempty(allowDown)
        allowDown  = true(size(vals));
    elseif isscalar(allowDown)
        if allowDown
            allowDown = true(size(vals));
        else
            allowDown = false(size(vals));
        end
    end
    
    if nargin < 4
        if isscalar(vals)
            scale = vals;
        else
            scale = nanmax(vals) - nanmin(vals);
        end
    end
    
    increment = closestNiceIncrement(scale);

    vals( allowUp &  allowDown) = round(vals( allowUp &  allowDown) ./ increment) * increment;
    vals( allowUp & ~allowDown) = ceil( vals( allowUp & ~allowDown) ./ increment) * increment;
    vals(~allowUp &  allowDown) = floor(vals(~allowUp &  allowDown) ./ increment) * increment;
end


function increment = closestNiceIncrement(scale)
    scale = max(abs(scale));
    pow10 = floor(log10(scale));
    scale = scale ./ 10^pow10;
    niceNums = [1 2 5 10];
    
    % should be numel(vals) x numel(niceNums)
    diff = abs(scale - niceNums);
    [~, idxClosest] = min(diff);
    increment = niceNums(idxClosest) * 10^(pow10 - 1);
end
    
    