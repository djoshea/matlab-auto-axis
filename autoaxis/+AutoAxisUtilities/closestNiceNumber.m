function niceClosest = closestNiceNumber(vals, direction)
% rounds to closest nice number like 0.1, 0.2, 0.5, 1 * 10^#
% direction can be 'up', 'down', or 'either'

    assert(isvector(vals), 'Values must be vector');
    vals = makecol(vals);
    
    if nargin < 2
        direction = 'either';
    end

    pow10 = floor(log10(vals));

    % scale the numbers to between 1 and 10;
    valsScaled = vals ./ 10.^pow10;

    niceNums = [1 2 5 10];

    % should be numel(vals) x numel(niceNums)
    diff = bsxfun(@minus, valsScaled, niceNums);

    switch direction
        case 'up'
            mask = diff < 0;
        case 'down'
            mask = diff > 0;
        case 'either'
            mask = true(size(diff));
        otherwise
            error('Direction must be up, down, or either');
    end

    diff(~mask) = Inf;
    [~, idxClosest] = min(abs(diff), [], 2);
    niceClosestScaled = niceNums(idxClosest)';

    niceClosest = niceClosestScaled .* 10.^pow10;
end