function [lims, increment] = shrinkLimitsToNiceNumber(lims)
% shrink to closest nice number like 0.1, 0.2, 0.5, 1 * 10^#

    [lims, increment] = AutoAxisUtilities.closestNiceLimits(lims, [true, false], [false, true], lims(2) - lims(1));
   
    
end