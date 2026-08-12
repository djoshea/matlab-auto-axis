% Demo for AutoAxis.plotboxpos when the axis's parent is a TiledChartLayout.
%
% plotboxpos used to convert the pixel plot box into the axis's units by parenting
% a temporary axes at that pixel position and reading it back. A TiledChartLayout
% refuses the requested position and lays the temp axes out as a new tile instead,
% so plotboxpos returned that tile's geometry.
%
% Everything AutoAxis draws is sized from plotboxpos via updateAxisScaling
%
%   ax.xDataToUnits = plotboxWidth / diff(xlim)
%
% so a wrong plot box rescales every decoration by the ratio of the bogus tile
% geometry to the true plot box. The dashed grey rectangle drawn on each axes
% outlines the data box in pure data units, which is frame independent and so is
% always placed correctly; judge the decorations against it.
%
%   CORRECT   on both panels the y tick bridge spans exactly the -4 to 4 ticks
%             alongside the dashed box, and the x scale bar sits just under it at a
%             length proportional to the box width
%   BROKEN    on the left (tiled) panel the bridge and scale bar are scaled by the
%             wrong factor and run well past the dashed box, while the right
%             (figure-parented) control still looks right
%
% The two panels are not expected to look identical to each other: a tiledlayout
% resizes the axes itself to satisfy the requested daspect, whereas a plain axes
% keeps its position and letterboxes the plot box inside it. The control is there to
% show that a figure-parented axes is unaffected by this change.

import AutoAxis.PositionType;
import AutoAxis.AnchorInfo;

figh = figure(1); clf; set(figh, 'Color', 'w', 'Visible', 'on');
figSizeScale([12 5]);

x = linspace(0, 10, 200);
y = 2*sin(2*pi*0.3*x);
xl = [0 10];
yl = [-6 6];

%% left: axes inside a tiledlayout that does not fill the figure

tl = tiledlayout(figh, 1, 1);
tl.OuterPosition = [0.02 0.02 0.46 0.96];
axTiled = nexttile(tl);
plot(axTiled, x, y, '-', 'LineWidth', 2, 'Color', [0.2 0.3 0.8]);
xlim(axTiled, xl); ylim(axTiled, yl);

% force DataAspectRatioMode manual so that the plot box is genuinely narrower than
% the axis position, which is what makes plotboxpos differ from Position at all
daspect(axTiled, [1 1.5 1]);
title(axTiled, 'in tiledlayout');

%% right: the same plot parented directly to the figure, as a control

axFig = axes(figh, 'OuterPosition', [0.52 0.02 0.46 0.96]);
plot(axFig, x, y, '-', 'LineWidth', 2, 'Color', [0.2 0.3 0.8]);
xlim(axFig, xl); ylim(axFig, yl);
daspect(axFig, [1 1.5 1]);
title(axFig, 'parented to figure (control)');

drawnow;

%% decorate both identically

auVec = AutoAxis.empty();
for axh = [axTiled axFig]
    % frame independent reference outline of the data box
    rectangle('Position', [xl(1) yl(1) diff(xl) diff(yl)], 'Parent', axh, ...
        'EdgeColor', [0.6 0.6 0.6], 'LineStyle', '--', ...
        'XLimInclude', false, 'YLimInclude', false);

    au = AutoAxis(axh);
    au.xUnits = 'ms';
    au.yUnits = 'mV';
    au.addTickBridge('y', 'tick', -4:2:4);
    au.addAutoScaleBarX();
    au.update();
    auVec(end+1) = au; %#ok<SAGROW>
end

drawnow;

%% report what plotboxpos returns now vs what the old temporary axes method returned

fprintf('\n');
reportPlotBoxPos('tiledlayout child', axTiled);
reportPlotBoxPos('figure child (control)', axFig);
fprintf(['\nFor the control the now/old rows must agree to all printed digits, and both\n' ...
         'xDataToUnits ratios must be 1.000: a figure-parented axis is unaffected.\n' ...
         'For the tiledlayout child they must differ, which is the whole point.\n' ...
         'The "Unable to set ''Position''" warnings above come from plotboxposViaTempAxes\n' ...
         'below, which keeps the old implementation alive only for this comparison.\n' ...
         'AutoAxis itself must never produce that warning.\n\n']);

function reportPlotBoxPos(name, h)
    fprintf('===== %s (parent %s) =====\n', name, class(get(h, 'Parent')));
    for u = ["centimeters" "normalized" "pixels"]
        set(h, 'Units', u);
        fprintf('  units=%-12s  Position = %s\n', u, mat2str(get(h, 'Position'), 6));
        fprintf('    plotboxpos (now) = %s\n', mat2str(AutoAxis.plotboxpos(h), 6));
        fprintf('    temp axes (old)  = %s\n', mat2str(plotboxposViaTempAxes(h), 6));
    end

    % the scaling that AutoAxis actually draws with, in cm per data unit
    set(h, 'Units', 'centimeters');
    now_ = AutoAxis.plotboxpos(h);
    old_ = plotboxposViaTempAxes(h);
    dx = diff(get(h, 'XLim'));
    dy = diff(get(h, 'YLim'));
    fprintf('  xDataToUnits now %.4f vs old %.4f   (ratio %.3f)\n', now_(3)/dx, old_(3)/dx, old_(3)/now_(3));
    fprintf('  yDataToUnits now %.4f vs old %.4f   (ratio %.3f)\n', now_(4)/dy, old_(4)/dy, old_(4)/now_(4));
    set(h, 'Units', 'normalized');
end

function pos = plotboxposViaTempAxes(h)
    % the previous implementation, kept here only so the demo can print a
    % was/now comparison
    currunit = get(h, 'Units');
    set(h, 'Units', 'pixels');
    axisPos = get(h, 'Position');
    set(h, 'Units', currunit);

    darismanual  = strcmpi(get(h, 'DataAspectRatioMode'), 'manual');
    pbarismanual = strcmpi(get(h, 'PlotBoxAspectRatioMode'), 'manual');
    if ~darismanual && ~pbarismanual
        pos = axisPos;
    else
        dx = diff(get(h, 'XLim'));
        dy = diff(get(h, 'YLim'));
        dar = get(h, 'DataAspectRatio');
        pbar = get(h, 'PlotBoxAspectRatio');
        if darismanual
            r = (dx/dar(1))/(dy/dar(2));
        else
            r = pbar(1)/pbar(2);
        end
        axisRatio = axisPos(3)/axisPos(4);
        if r > axisRatio
            pos(1) = axisPos(1);
            pos(3) = axisPos(3);
            pos(4) = axisPos(3)/r;
            pos(2) = (axisPos(4) - pos(4))/2 + axisPos(2);
        else
            pos(2) = axisPos(2);
            pos(4) = axisPos(4);
            pos(3) = axisPos(4) * r;
            pos(1) = (axisPos(3) - pos(3))/2 + axisPos(1);
        end
    end

    temp = axes('Units', 'Pixels', 'Position', pos, 'Visible', 'off', 'Parent', get(h, 'Parent'));
    set(temp, 'Units', currunit);
    pos = get(temp, 'Position');
    delete(temp);
end
