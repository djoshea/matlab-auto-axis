function [lims, increment] = expandLimitsToNiceNumber(lims)
% expands to closest nice number like 0.1, 0.2, 0.5, 1 * 10^#

    [lims, increment] = AutoAxisUtilities.closestNiceLimits(lims, [false, true], [true, false], lims(2) - lims(1));
   
    
end