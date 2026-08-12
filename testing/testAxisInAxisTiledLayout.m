% Demo for AutoAxis.axisPosInNormalizedFigureUnits across container types.
%
% An axes that lives inside a TiledChartLayout (or a uipanel) reports its Position
% purely within that container's own box, with no trace of where the container sits
% in the figure. Moving the layout does not change the reported Position at all, and
% getpixelposition(h, true) does not compose through a layout ancestor either.
% axisPosInNormalizedFigureUnits therefore has to walk the container chain itself, so
% that positions of objects in different containers land in one common frame.
%
% This script draws a full figure host axes underneath everything, then outlines each
% inset axes on the host by round tripping through figure normalized units:
%
%   nf  = AutoAxis.axisPosInNormalizedFigureUnits(inset)
%   pos = AutoAxis.convertNormFigureUnitsToAxisDataUnits(host, nf)
%
%   CORRECT   each coloured rectangle sits exactly on its inset's plot box, and the
%             layout inset's rectangle follows the layout as it is stepped through
%             three placements at the end of the script
%   BROKEN    the rectangles land elsewhere in the figure (roughly where each inset
%             would be if its container filled the whole figure) and do not move when
%             the layout does
%
% The last section anchors the panel inset with AutoAxis, which exercises the write
% back path: the position has to be converted from the figure frame back into the
% panel's frame before being assigned to Position.

import AutoAxis.PositionType;
import AutoAxis.AnchorInfo;

figh = figure(2); clf; set(figh, 'Color', 'w', 'Visible', 'on');
figSizeScale([9 6]);

x = linspace(-5, 5, 100);

%% inset 1: axes inside a tiledlayout squeezed into the lower left
% note the layout has to be created before the host axes below, since tiledlayout
% deletes any axes already parented to the figure

tl = tiledlayout(figh, 1, 1);
tl.OuterPosition = [0.06 0.08 0.38 0.38];
axTiled = nexttile(tl);
plot(axTiled, x, sin(x), 'LineWidth', 1.5);
axTiled.Color = 'none';
title(axTiled, 'in tiledlayout');

%% inset 2: axes inside a uipanel in the upper right

pnl = uipanel(figh, 'Position', [0.56 0.56 0.38 0.38], 'BackgroundColor', 'w');
axPanel = axes(pnl);
plot(axPanel, x, cos(x), 'LineWidth', 1.5, 'Color', [0.85 0.33 0.1]);
title(axPanel, 'in uipanel');

%% host axes spanning the whole figure, in known data units

axHost = axes(figh, 'Position', [0 0 1 1], 'Color', 'none');
axHost.XLim = [0 100];
axHost.YLim = [0 100];
axHost.XTick = [];
axHost.YTick = [];
axHost.HitTest = false;
hold(axHost, 'on');

drawnow;

%% outline each inset on the host axes

hRectTiled = outlineOnHost(axHost, axTiled, [0 0.6 0], []);
hRectPanel = outlineOnHost(axHost, axPanel, [0.6 0 0.6], []);

fprintf('\ntiledlayout inset, figure normalized = %s\n', ...
    mat2str(AutoAxis.axisPosInNormalizedFigureUnits(axTiled), 5));
fprintf('uipanel     inset, figure normalized = %s\n', ...
    mat2str(AutoAxis.axisPosInNormalizedFigureUnits(axPanel), 5));

%% step the layout around; the green outline must follow it

placements = {[0.06 0.08 0.38 0.38], [0.30 0.30 0.38 0.38], [0.06 0.56 0.38 0.38]};
for iP = 1:numel(placements)
    tl.OuterPosition = placements{iP};
    drawnow;
    hRectTiled = outlineOnHost(axHost, axTiled, [0 0.6 0], hRectTiled);
    fprintf('layout OuterPosition %s -> inset figure normalized %s\n', ...
        mat2str(placements{iP}, 3), ...
        mat2str(AutoAxis.axisPosInNormalizedFigureUnits(axTiled), 5));
    pause(0.6);
end

%% write back path: anchor the panel inset to the host axes with AutoAxis
% AutoAxis positions the panel inset by writing its Position, which is interpreted in
% the panel's frame, so the figure normalized value has to be converted back down.
% If that conversion is missing the inset jumps by the panel's offset in the figure.

au = AutoAxis(axHost);
au.addAnchor(AnchorInfo(axPanel, PositionType.Right, axHost, PositionType.Right, 0.5, ...
    'anchor panel inset to right edge of host'));
au.update();
drawnow;

hRectPanel = outlineOnHost(axHost, axPanel, [0.6 0 0.6], hRectPanel); %#ok<NASGU>
fprintf(['\nAfter anchoring, the uipanel inset should sit flush against the right\n' ...
         'edge of the figure with a 0.5 cm gap, and its purple outline should still\n' ...
         'hug it exactly.\n\n']);

function h = outlineOnHost(axHost, axInset, color, h)
    % outline axInset's plot box on axHost, by way of figure normalized units
    nf = AutoAxis.axisPosInNormalizedFigureUnits(axInset);
    pos = AutoAxis.convertNormFigureUnitsToAxisDataUnits(axHost, nf);
    if ~isempty(h) && isvalid(h)
        delete(h);
    end
    h = rectangle('Position', pos, 'EdgeColor', color, 'LineWidth', 2, ...
        'Parent', axHost, 'XLimInclude', false, 'YLimInclude', false);
end
