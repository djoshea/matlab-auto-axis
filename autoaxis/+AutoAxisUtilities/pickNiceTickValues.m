function ticks = pickNiceTickValues(lims, numTicksApprox)
% expands lims to nice round numbers using expandLimitsToNiceNumber and
% then generates ticks using a nice round increment that achieves about
% numTicksApprox. 
    
    if ~exist('numTicksApprox', 'var')
        [lims, increment] = AutoAxisUtilities.shrinkLimitsToNiceNumber(lims);
        ticks = lims(1):increment:lims(2);
    elseif numTicksApprox == 2
        lims = AutoAxisUtilities.shrinkLimitsToNiceNumber(lims);
        ticks = lims;
    else
        increment = AutoAxisUtilities.closestNiceNumber((lims(2) - lims(1)) / numTicksApprox);
        first = ceil(lims(1) / increment) * increment;
        last = floor(lims(2) / increment) * increment;
        ticks = first:increment:last;
    end
end