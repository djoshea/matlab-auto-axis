classdef AutoAxis < handle & matlab.mixin.Copyable
% Class for redrawing axis annotations and aligning them according to 
% relative to each other using paper units. Automatically updates this
% placement whenever the axis is panned, zoomed, etc.
% 
% Try ax = AutoAxis.replace(gca) to get started.
%
% Author: Dan O'Shea, {my first name} AT djoshea.com (c) 2014
%
% NOTE: This class graciously utilizes code from the following authors:
%
% Malcolm Lidierth: For the isMultipleCall utility to prevent callback
%   re-entrancy
%   http://undocumentedmatlab.com/blog/controlling-callback-re-entrancy/
%

    properties(Dependent) % Utility properties that read/write through 
        axisPaddingLeft
        axisPaddingBottom
        axisPaddingRight
        axisPaddingTop
        
        % gap between axis limits (Position) and OuterPosition of axes [left bottom right top] 
        axisMargin % [left bottom right top] 
        
        axisMarginLeft
        axisMarginBottom
        axisMarginRight
        axisMarginTop 
        
        % note that these are only used when addXLabelAnchoredToAxis is
        % used to anchor the label directly to the axis, not to the
        % decorations on that side of the axis.
        axisLabelOffsetLeft
        axisLabelOffsetBottom
        axisLabelOffsetTop
        axisLabelOffsetRight
        
        % these are used when addXLabel or addYLabel are used to anchor the
        % x and y labels off of the known decorations on that side of the
        % axis, rather than the axes themselves. This is more typical of
        % the way Matlab positions the labels, but reduces the likelihood
        % of getting consistent positioning among axes
        decorationLabelOffsetLeft
        decorationLabelOffsetBottom
        decorationLabelOffsetTop
        decorationLabelOffsetRight
    end

    % specify default aspects of layout and appearance
    properties
        % units used by all properties and anchor measurements
        % set this before creating any anchors
        units = 'centimeters';
        
        backgroundColor
        
        hideBuiltinAxes = true;
        
        % ticks and tick labels
        tickColor
        tickLength % AutoAxis_TickLength
        tickLineWidth % AutoAxis_TickLineWidth; % not in centimeters, this is stroke width
        tickFontColor
        tickFontSize
        
        % size of marker diameter
        markerWidth % AutoAxis_MarkerWidth [2*2.54/72]
        markerHeight % AutoAxis_MarkerHeight [0.1]
        markerCurvature % % AutoAxis_MarkerCurvature ; % 0 is rectangle, 1 is circle / oval, or can specify [x y] curvature
        
        % interval thickness. Note that intervals should be thinner than
        % the marker diameter for the vertical alignment to work correctly 
        % Note that interval location and label location is determined by
        % markerDiameter
        intervalThickness % AutoAxis_IntervalThickness [0.08];

        interval_vcenterWithMarkers logical = true;
        interval_addSpaceForScaleBar logical = true;
        
        % this controls both the gap between tick lines and tick labels,
        % and between tick labels and axis label offset
        tickLabelOffset % AutoAxis_TickLabelOffset [0.1] cm
        
        markerLabelOffset % AutoAxis_MarkerLabelOffset [0.1]; % cm
        
        % axis x/y labels
        labelFontSize
        labelFontColor
        
        % plot title
        titleFontSize
        titleFontColor
        titleFontWeight string = "bold";
        titleAlignOuter logical = true;
        
        subtitleFontSize
        subtitleFontColor
        subtitleFontWeight string = "normal";
        subtitleAlignOuter logical = true;
        
        % scale bar 
        scaleBarThickness % AutoAxis_ScaleBarThickness [0.1] % cm
        xUnits = '';
        yUnits = '';
        
        scaleBarLenX
        scaleBarLenY
        
        scaleBarHideLabelX = false;
        scaleBarHideLabelY = false;
        
        scaleBarScaleFactorX = 1;
        scaleBarScaleFactorY = 1;
        
        scaleBarLabelOffset 

        keepAutoScaleBarsEqual = false;
        scaleBarColor
        scaleBarFontColor
        scaleBarFontSize
        
        debug = false;
        
        gridBackground = [0.92 0.92 0.95]; % copying Seaborn
        gridColor = 'w';
        minorGridColor = [0.96 0.96 0.96];
        
        anchorXLabelToAxis = false;
        anchorYLabelToAxis = false;
        
        yLabelVerticalOffset = 0;
        xLabelHorizontalOffset = 0;
        
        autoAxisXExtendToLimits = false;
        autoAxisYExtendToLimits = false;
        
        autoAxisYManualPositionX = NaN;
        autoAxisXManualPositionY = NaN;

        autoScaleBarX_forceAlignWithOther = false;
        autoScaleBarY_forceAlignWithOther = false;
    end
    
    % internal properties, mainly accessed through left/right/top/bottom
    % accessors
    properties(Hidden)
        % left: room for y-axis
        % bottom: room for x-axis
        % right: room for y-scale bar and label
        % top: room for title
        
        % spacing between axes and any ticks, lines, marks along each axis
        axisPadding % [left bottom right top] 
     
        % when x or y label is anchored to the axis directly, these offsets
        % are used. This will be the case if addXLabelAnchoredToAxis is
        % used.
        axisLabelOffset = [0.55 0.55 0.55 0.55]; % cm
        
        % when x or y label is anchored to the outer edge of the axis
        % decorations, e.g. belowX or leftY, these smaller offsets are
        % used. This will be the case if addXLabelAnchoredToDecorations is
        % used
        decorationLabelOffset = [0.1 0.05 0.1 0.1]; % cm
    end
    
    % internal properties
    properties(SetAccess=protected)
        enabled = true;
        enableUpdate = true; % used to prevent unncessary updates mid-adding things to the plot
        
        axisMargin_I % holds data for axis margin
        requiresReconfigure = true;
        installedCallbacks = false;
        hListeners = [];
        currentlyRepositioningAxes = false;
        
        hClaListener = [];
    end
        
    properties(Hidden, SetAccess=protected)
        axh % axis handle to which I am attached (client axis)
        
        usingOverlay = false;
        axhDraw % axis handle into which I am drawing (private axis, though may be the same as axh when usingOverlay is false)
        
        anchorInfo (:, 1) AutoAxis.AnchorInfo % array of AutoAxisAnchorInfo objects that I enforce on update()
        
        % contains a copy of the anchors in anchor info where all handle collection and property value references are looked up 
        % see .derefAnchorInfo
        anchorInfoDeref (:, 1) AutoAxis.AnchorInfo
        
        refreshNeeded = true;
        
        % map graphics to LocationCurrent objects
        mapLocationHandles
        mapLocationCurrent
        
        collections (1, 1) struct % struct which contains named collections of handles
        anchorCollections (1, 1) struct % struct which contains named collections of anchors
        
        nextTagId = 0; % integer indicating the next free index to use when generating tags for handles
        
        % maps handles --> tag strings
        handleTagObjects
        handleTagStrings
        
        tagOverlayAxis = ''; % tag used for the overlay axis
        
        % these hold on to specific special objects that have been added
        % to the plot
        autoAxisX
        autoAxisY
        autoScaleBarX
        autoScaleBarY
        
        % monitor the state of the other scale bar whne the anchors were added to see if we should update 
        autoScaleBarX_anchorsAlignedWithY (1, 1) logical = false;
        autoScaleBarY_anchorsAlignedWithX (1, 1) logical = false;
        
        hTitle
        hXLabel
        hYLabel
        
        lastXLim
        lastYLim
    end

    properties(Hidden, SetAccess=protected)
        xDataToUnits
        yDataToUnits
        
        xDataToPoints
        yDataToPoints
        
        xDataToPixels
        yDataToPixels

        axPositionNormUnits
        axOuterPositionNormUnits
        
        xAutoTicks
        xAutoMinorTicks
        xAutoTickLabels
        yAutoTicks
        yAutoMinorTicks
        yAutoTickLabels
        
        xExponent
        yExponent
        htYExponent
        htXExponent
        showXExponent = false;
        showYExponent = false;
        
        % holds onto any specific overrides for these axes
        xAutoAxisInfo = struct();
        yAutoAxisInfo = struct();

        % for tiled axes with multiple limits, this guides the creation of
        % the tick bridges and grid lines
        xAutoBridgeInfo
        yAutoBridgeInfo
        xAutoBridge = {};
        yAutoBridge = {};
    end
    
    properties(Dependent)
        figh
        xAutoMajor
        xAutoMinor
        yAutoMajor
        yAutoMinor
        
        xReverse % true/false if xDir is reverse
        yReverse % true/false if yDir is reverse
    end
    
    methods % Constructor
        function ax = AutoAxis(axh, varargin)
            if nargin < 1 || isempty(axh)
                axh = gca;
            end
            
            ax = AutoAxis.createOrRecoverInstance(ax, axh, varargin{:});
        end
        
        function enable(ax)
            ax.enabled = true;
        end
        
        function disable(ax)
            ax.enabled = false;
        end
    end
    
    methods % Implementations for dependent properties above
        function figh = get.figh(ax)
            figh = AutoAxis.getParentFigure(ax.axh);
        end
        
        function set.axisPadding(ax, v)
            if numel(v) == 1
                ax.axisPadding = [v v v v];
            elseif numel(v) == 2 % assume horz, vert
                ax.axisPadding = [AutoAxisUtilities.makerow(v), AutoAxisUtilities.makerow(v)];
            else
                ax.axisPadding = AutoAxisUtilities.makerow(v);
            end
        end
                        
        function v = get.axisPaddingLeft(ax)
            v = ax.axisPadding(1);
        end
        
        function set.axisPaddingLeft(ax, v)
            ax.axisPadding(1) = v;
        end
        
        function v = get.axisPaddingBottom(ax)
            v = ax.axisPadding(2);
        end
        
        function set.axisPaddingBottom(ax, v)
            ax.axisPadding(2) = v;
        end
        
        function v = get.axisPaddingRight(ax)
            v = ax.axisPadding(3);
        end
        
        function set.axisPaddingRight(ax, v)
            ax.axisPadding(3) = v;
        end
        
        function v = get.axisPaddingTop(ax)
            v = ax.axisPadding(4);
        end
        
        function set.axisPaddingTop(ax, v)
            ax.axisPadding(4) = v;
        end
        
        function v = get.axisPadding(ax)
            v = ax.axisPadding;
            if isempty(v)
                v = AutoAxis.getenvVec('AutoAxis_DefaultPadding', [0.1 0.1 0.1 0.1]);
            end
        end 
        
        function set.axisMargin(ax, v)
            if numel(v) == 0
                ax.axisMargin_I = [];
            elseif numel(v) == 1
                ax.axisMargin_I = [v v v v];
            elseif numel(v) == 2 % assume horz, vert
                ax.axisMargin_I = [AutoAxisUtilities.makerow(v), AutoAxisUtilities.makerow(v)];
            else
                ax.axisMargin_I = AutoAxisUtilities.makerow(v);
            end
        end
        
        function v = get.axisMargin(ax)
            if isempty(ax.axisMargin_I)
                v = ax.getAxisMarginDefaults();
            else
                v = ax.axisMargin_I;
            end
        end
             
        function m = getAxisMarginDefaults(ax)
            % compute reasonable auto margins based on axis font size
            
            sz = get(ax.axh, 'FontSize') / 72 * 2.54;
            szTop = sz * get(ax.axh, 'TitleFontSizeMultiplier');
            szLabel = sz * get(ax.axh, 'LabelFontSizeMultiplier') * 1.3;
            % left bottom right top
            m = [3*szLabel 3*szLabel 1.5*szLabel 1.5*szTop];
            
            % override with environment var if different
            m = AutoAxis.getenvVec('AutoAxis_DefaultMargins', m);
        end
        
        function v = get.axisMarginLeft(ax)
            v = ax.axisMargin(1);
        end
        
        function set.axisMarginLeft(ax, v)
            ax.axisMargin(1) = v;
        end
        
        function v = get.axisMarginBottom(ax)
            v = ax.axisMargin(2);
        end
        
        function set.axisMarginBottom(ax, v)
            ax.axisMargin(2) = v;
        end
        
        function v = get.axisMarginRight(ax)
            v = ax.axisMargin(3);
        end
        
        function set.axisMarginRight(ax, v)
            ax.axisMargin(3) = v;
        end
        
        function v = get.axisMarginTop(ax)
            v = ax.axisMargin(4);
        end
        
        function set.axisMarginTop(ax, v)
            ax.axisMargin(4) = v;
        end
        
        function set.axisLabelOffset(ax, v)
            if numel(v) == 1
                ax.axisLabelOffset = [v v v v];
            elseif numel(v) == 2 % assume horz, vert
                ax.axisLabelOffset = [AutoAxisUtilities.makerow(v), AutoAxisUtilities.makerow(v)];
            elseif numel(v) == 4
                ax.axisLabelOffset = AutoAxisUtilities.makerow(v);
            else
                error('axisLabelOffset must be scalar, 2 elements, or 4 elements');
            end
        end
        
        function v = get.axisLabelOffsetLeft(ax)
            v = ax.axisLabelOffset(1);
        end
        
        function set.axisLabelOffsetLeft(ax, v)
            ax.axisLabelOffset(1) = v;
        end
        
        function v = get.axisLabelOffsetBottom(ax)
            v = ax.axisLabelOffset(2);
        end
        
        function set.axisLabelOffsetBottom(ax, v)
            ax.axisLabelOffset(2) = v;
        end
        
        function v = get.axisLabelOffsetRight(ax)
            v = ax.axisLabelOffset(3);
        end
        
        function set.axisLabelOffsetRight(ax, v)
            ax.axisLabelOffset(3) = v;
        end
        
        function v = get.axisLabelOffsetTop(ax)
            v = ax.axisLabelOffset(4);
        end
        
        function set.axisLabelOffsetTop(ax, v)
            ax.axisLabelOffset(4) = v;
        end
        
        function set.decorationLabelOffset(ax, v)
            if numel(v) == 1
                ax.decorationLabelOffset = [v v v v];
            elseif numel(v) == 2 % assume horz, vert
                ax.decorationLabelOffset = [AutoAxisUtilities.makerow(v), AutoAxisUtilities.makerow(v)];
            elseif numel(v) == 4
                ax.decorationLabelOffset = AutoAxisUtilities.makerow(v);
            else
                error('decorationLabelOffset must be scalar, 2 elements, or 4 elements');
            end
        end
        
        function v = get.decorationLabelOffsetLeft(ax)
            v = ax.decorationLabelOffset(1);
        end
        
        function set.decorationLabelOffsetLeft(ax, v)
            ax.decorationLabelOffset(1) = v;
        end
        
        function v = get.decorationLabelOffsetBottom(ax)
            v = ax.decorationLabelOffset(2);
        end
        
        function set.decorationLabelOffsetBottom(ax, v)
            ax.decorationLabelOffset(2) = v;
        end
        
        function v = get.decorationLabelOffsetRight(ax)
            v = ax.decorationLabelOffset(3);
        end
        
        function set.decorationLabelOffsetRight(ax, v)
            ax.decorationLabelOffset(3) = v;
        end
        
        function v = get.decorationLabelOffsetTop(ax)
            v = ax.decorationLabelOffset(4);
        end
        
        function set.decorationLabelOffsetTop(ax, v)
            ax.decorationLabelOffset(4) = v;
        end
        
        function v = get.xAutoMajor(ax)
            if isempty(ax.xAutoTicks)
                v = NaN;
            else
                v = ax.xAutoTicks(end) - ax.xAutoTicks(end-1);
            end
        end
        
        function v = get.yAutoMajor(ax)
            if isempty(ax.yAutoTicks)
                v = NaN;
            else
                v = ax.yAutoTicks(end) - ax.yAutoTicks(end-1);
            end
        end
        
        function v = get.xAutoMinor(ax)
            if isempty(ax.xAutoMinorTicks)
                v = NaN;
            else
                v = ax.xAutoMinorTicks(end) - ax.xAutoMinorTicks(end-1);
            end
        end
        
        function v = get.yAutoMinor(ax)
            if isempty(ax.yAutoMinorTicks)
                v = NaN;
            else
                v = ax.yAutoMinorTicks(end) - ax.yAutoMinorTicks(end-1);
            end
        end
    end
    
    
    methods(Static) % Static utils and figure specific functions
        function hideInLegend(h)
            % prevent object h from appearing in legend by default
            for i = 1:numel(h)
                try
                    ann = get(h(i), 'Annotation');
                    leg = get(ann, 'LegendInformation');
                    set(leg, 'IconDisplayStyle', 'off');
                catch
                end
            end
        end
        
        function figureCallback(figh, varargin)
            if AutoAxis.isMultipleCall(), return, end
            AutoAxis.updateFigure(figh);
        end
        
%         function figureDeferredCallback(figh, varargin)
%             figData = get(figh, 'UserData');
%             hTimer = [];
%             if isstruct(figData) && isfield(figData, 'hTimer') 
%                 hTimer = figData.hTimer;
%             end
%             if ~isempty(hTimer) && isa(hTimer, 'timer')
%                 % stop the timer to delay it's triggering
%                 stop(hTimer);
%             else
%                 % create the timer
%                 hTimer = timer('StartDelay', 0.1, 'TimerFcn', @(varargin) AutoAxis.figureCallback(figh));
%                 if ~isstruct(figData), figData = struct(); end
%                 figData.hTimer = hTimer;
%                 set(figh, 'UserData', figData);
%             end
%             
%             % start it soon
%             tStart = now + 0.1 / (60^2*24);
%             startat(hTimer, tStart);
%         end
        
        function flag = isMultipleCall()
            % determine whether callback is being called within itself
            flag = false; 
            % Get the stack
            s = dbstack();
            if numel(s) <= 2
                % Stack too short for a multiple call
                return
            end

            % How many calls to the calling function are in the stack?
            names = {s(:).name};
            TF = strcmp(s(2).name,names);
            count = sum(TF);
            if count>1
                % More than 1
                flag = true; 
            end
        end
        
        function hvec = allocateHandleVector(num)
            if verLessThan('matlab','8.4.0')
                hvec = nan(num, 1);
            else
                hvec = gobjects(num, 1);
            end
        end
        
        function hn = getNullHandle()
            if verLessThan('matlab','8.4.0')
                hn = NaN;
            else
                hn = matlab.graphics.GraphicsPlaceholder();
            end
        end
        
        function tag = generateFigureUniqueTag(figh, prefix)
            if nargin < 2
                prefix = 'autoAxis';
            end
            while true
                validChars = ['a':'z', 'A':'Z', '0':'9'];
                tag = sprintf('%s_%s', prefix, randsample(validChars, 20));
                if nargin >= 1
                    obj = findall(figh, 'Tag', tag);
                    if isempty(obj)
                        return;
                    end
                else
                    return;
                end
            end  
        end
        
        function enableFigure(figh)
            % call auto axis update for every managed axis in a figure
            if nargin < 1
                figh = gcf;
            end
            
            axCell = AutoAxis.recoverForFigure(figh);
            for i = 1:numel(axCell)
                axCell{i}.enable();
            end
        end
        
        function disableFigure(figh)
            % call auto axis update for every managed axis in a figure
            if nargin < 1
                figh = gcf;
            end
            
            axCell = AutoAxis.recoverForFigure(figh);
            for i = 1:numel(axCell)
                axCell{i}.disable();
            end
        end
        
        function updateFigure(figh)
            % call auto axis update for every managed axis in a figure
            if nargin < 1
                figh = gcf;
            end
            
            axCell = AutoAxis.recoverForFigure(figh);
            for i = 1:numel(axCell)
                axCell{i}.update();
            end
        end
        
        function updateIfInstalled(axh)
            % supports either axis or figure handle
            if nargin < 1
                axh = gca;
            end
            if isa(axh, 'matlab.graphics.axis.Axes')
                au = AutoAxis.recoverForAxis(axh);
                if ~isempty(au)
                    au.update();
    %                 au.installCallbacks();
                end
            elseif isa(axh, 'matlab.ui.Figure')
                AutoAxis.updateFigure(axh);
            end
        end
        
        function fig = getParentFigure(axh)
            % if the object is a figure or figure descendent, return the
            % figure. Otherwise return [].
            fig = axh;
            while ~isempty(fig) && ~isa(fig, 'matlab.ui.Figure') % ~strcmp('figure', get(fig,'type'))
              fig = get(fig,'Parent');
            end
        end
        
%         function p = getPanelForFigure(figh)
%             % return a handle to the panel object associated with figure
%             % figh or [] if not associated with a panel
%             try
%                 p = panel.recover(figh);
%             catch
%                 p = [];
%             end
% %             if isempty(p)
% %                 p = panel.recover(figh);
% %             end
%         end
        
        function axCell = recoverForFigure(figh)
            % recover the AutoAxis instances associated with all axes in
            % figure handle figh
            if nargin < 1, figh = gcf; end
            hAxes = findall(figh, 'Type', 'axes');
            axCell = cell(numel(hAxes), 1);
            for i = 1:numel(hAxes)
                axCell{i} = AutoAxis.recoverForAxis(hAxes(i));
            end
            
            axCell = axCell(~cellfun(@isempty, axCell));
        end
        
        function ax = recoverForAxis(axh)
            % recover the AutoAxis instance associated with the axis handle
            if nargin < 1, axh = gca; end
            ax = getappdata(axh, 'AutoAxisInstance');
            if ~isempty(ax) && ~isvalid(ax)
                rmappdata(axh, 'AutoAxisInstance');
                ax = [];
            end
        end
        
        function ax = createOrRecoverInstance(ax, axh, varargin)
            % if an instance is stored in this axis' UserData.autoAxis
            % then return the existing instance, otherwise create a new one
            % and install it
            
            axTest = AutoAxis.recoverForAxis(axh);
            if isempty(axTest)
                % not installed, create new
                ax.initializeNewInstance(axh);
                ax.installInstanceForAxis(axh, varargin{:});
            else
                % return the existing instance
                ax = axTest;
            end
        end
        
        function claCallback(axh, varargin)
            % reset the autoaxis associated with this axis if the axis is
            % cleared
            ax = AutoAxis.recoverForAxis(axh);
            if ~isempty(ax)
%                 disp('deleting auto axis');
                ax.uninstall();
            end
        end
    end
    
    methods(Static) % Loading from disk
        function ax = loadobj(ax)
            % defer reconfiguring until we have our figure set as parent
            ax.hListeners = addlistener(ax.axh, {'Parent'}, 'PostSet', @(varargin) ax.reconfigurePostLoad);
        end
    end
    
    methods % Installation, uninstallation, callbacks, tagging, collections
        function ax = saveobj(ax)
            if ax.installedCallbacks
                ax.uninstallCallbacksForSave();
            end
             
             ax.pruneStoredHandles();
             ax.requiresReconfigure = true;
             
             % on a timer, reinstall my callbacks since the listeners have
             % been detached for the save
             timer('StartDelay', 1, 'TimerFcn', @(varargin) ax.installCallbacks());
        end
        
        function initializeNewInstance(ax, axh)
            ax.axh = axh;
            
            % this flag is used for save/load reconfiguration
            ax.requiresReconfigure = false;
            
            % initialize handle tagging (for load/copy
            % auto-reconfiguration)
            ax.handleTagObjects = AutoAxis.allocateHandleVector(0);
            ax.handleTagStrings = {};
            ax.nextTagId = 1;
            
            % determine whether we're drawing into an overlay axis
            % or directly into this axis
            figh = AutoAxis.getParentFigure(ax.axh);
            if strcmp(get(figh, 'Renderer'), 'OpenGL')
                % create the overlay axis
                ax.usingOverlay = true;
                
                % create the overlay axis on top, without changing current
                % axes
                oldCA = gca; % cache gca
                ax.axhDraw = axes('Position', [0 0 1 1], 'Parent', figh);
                axis(ax.axhDraw, axis(ax.axh));
                axes(oldCA); % restore old gca
                
                % tag overlay axis with a random figure-unique string so
                % that we can recover it later (don't use tagHandle here, 
                % which is for the contents of axhDraw which don't need to
                % be figure unique). Don't overwrite the tag if it exists
                % to play nice with tagging by MultiAxis.
                tag = get(ax.axhDraw, 'Tag');
                if isempty(tag)
                    ax.tagOverlayAxis = AutoAxis.generateFigureUniqueTag(figh, 'autoAxisOverlay');
                    set(ax.axhDraw, 'Tag', ax.tagOverlayAxis);
                else
                    ax.tagOverlayAxis = tag;
                end
                hold(ax.axhDraw, 'on');
                
                ax.updateOverlayAxisPositioning();
            else
                ax.usingOverlay = false;
                ax.axhDraw = ax.axh;
            end
            
            %ax.hMap = containers.Map('KeyType', 'char', 'ValueType', 'any'); % allow handle arrays too
            ax.anchorInfo = AutoAxis.AnchorInfo.empty(0,1);
            ax.anchorInfoDeref = [];
            ax.collections = struct();
            
            ax.restoreDefaults();

            ax.mapLocationHandles = AutoAxis.allocateHandleVector(0);
            ax.mapLocationCurrent = {};
        end
        
        function restoreDefaults(ax)
            ax.axh.FontSize = get(groot, 'DefaultAxesFontSize');
            set(ax.axh, 'DefaultTextColor', get(groot, 'DefaultTextColor'));
            set(ax.axh, 'DefaultLineColor', get(groot, 'DefaultLineColor'));
            
            scale = getenv('FIGURE_SIZE_SCALE');
            if isempty(scale)
                scale = 1;
            else
                scale = str2double(scale);
            end
            
            % we assume that these are already scaled by FIGURE_SIZE_SCALE
            sz = get(ax.axh, 'FontSize');
            tc = get(ax.axh, 'DefaultTextColor');
            lc = get(ax.axh, 'DefaultLineColor');
            
            % these should match AutoAxisDefaults.reset() values
            szDiffTick = AutoAxis.getenvNum('AutoAxis_SmallFontSizeDelta', 1) * scale;
            ax.tickLength = AutoAxis.getenvNum('AutoAxis_TickLength', 0.05) * scale;
            ax.tickLineWidth = AutoAxis.getenvNum('AutoAxis_TickLineWidth', 0.5) * scale; % not in centimeters, this is stroke width
            ax.markerWidth = AutoAxis.getenvNum('AutoAxis_MarkerWidth', 2*2.54/72) * scale;
            ax.markerHeight = AutoAxis.getenvNum('AutoAxis_MarkerHeight', 0.12) * scale;
            ax.markerCurvature = AutoAxis.getenvNum('AutoAxis_MarkerCurvature', 0); % 0 is rectangle, 1 is circle / oval, or can specify [x y] curvature
            ax.intervalThickness = AutoAxis.getenvNum('AutoAxis_IntervalThickness', 0.12)* scale;
            ax.scaleBarThickness = AutoAxis.getenvNum('AutoAxis_ScaleBarThickness', 0.08)* scale; % scale bars should be thinner than intervals since they sit on top
            ax.tickLabelOffset  = AutoAxis.getenvNum('AutoAxis_TickLabelOffset', 0.1)* scale;
            ax.scaleBarLabelOffset  = AutoAxis.getenvNum('AutoAxis_ScaleBarLabelOffset', 0.02)* scale;
            ax.markerLabelOffset = AutoAxis.getenvNum('AutoAxis_MarkerLabelOffset', 0.1)* scale; % cm
            
            ax.backgroundColor = get(0, 'DefaultAxesColor');
            
            ax.tickColor = lc;
            ax.tickFontSize = sz - szDiffTick;
            ax.tickFontColor = tc;
            ax.labelFontColor = tc;
            ax.labelFontSize = sz;
            ax.titleFontSize = sz;
            ax.titleFontColor = tc;
            ax.scaleBarColor = lc;
            ax.scaleBarFontSize = sz - szDiffTick;
            ax.scaleBarFontColor = tc;
            
            ax.axisMargin = [];
            ax.axisPadding = [];
        end
             
        function installInstanceForAxis(ax, axh, varargin)
            p =inputParser();
            p.addParameter('installCallbacks', true, @islogical);
            p.parse(varargin{:});
            
            setappdata(axh, 'AutoAxisInstance', ax);   
%             ax.addTitle();
%             ax.addXLabelAnchoredToAxis();
%             ax.addYLabelAnchoredToAxis();
            if p.Results.installCallbacks
                ax.installCallbacks();
            end
            ax.installClaListener();
        end
        
        function installCallbacks(ax)
            figh = AutoAxis.getParentFigure(ax.axh);
           
            % these work faster than listening on xlim and ylim, but can
            % not update depending on how the axis limits are set
            if isa(ax.axh, 'matlab.graphics.axis.Axes') 
                set(zoom(ax.axh),'ActionPreCallback',@ax.prePanZoomCallback);
                set(zoom(ax.axh),'ActionPostCallback',@ax.postPanZoomCallback);
            end
            
            set(pan(figh),'ActionPreCallback',@ax.prePanZoomCallback);
            set(pan(figh),'ActionPostCallback',@ax.postPanZoomCallback);

            % updates entire figure at once
            set(figh, 'ResizeFcn', @(varargin) AutoAxis.figureCallback(figh));
            
            if ~isempty(ax.hListeners)
                delete(ax.hListeners);
                ax.hListeners = [];
            end
            
            % listeners need to be cached so that we can delete them before
            % saving.
            hl(1) = addlistener(ax.axh, {'XDir', 'YDir'}, 'PostSet', @ax.axisCallback);
            hl(2) = addlistener(ax.axh, {'XLim', 'YLim'}, 'PostSet', @ax.axisIfLimsChangedCallback);
            if isa(ax.axh, 'matlab.graphics.axis.Axes') 
                hl(3) = addlistener(ax.axh, {'XGrid', 'YGrid', 'XMinorGrid', 'YMinorGrid'}, 'PostSet', @ax.axisCallback);
            end
%             hl(3) = addlistener(ax.axh, {'Parent'}, 'PostSet',
%             @(varargin) ax.installCallbacks); % has issues with
%             AxesLayoutManager and zooming
            ax.hListeners = hl;
            
%             p = AutoAxis.getPanelForFigure(figh);
%             if ~isempty(p)
%             p.setCallback(@(varargin) AutoAxis.figureCallback(figh));
%             end
            
            ax.installedCallbacks = true;
            
            %set(figh, 'ResizeFcn', @(varargin) disp('resize'));
            %addlistener(ax.axh, 'Position', 'PostSet', @(varargin) disp('axis size'));
            %addlistener(figh, 'Position', 'PostSet', @ax.figureCallback);
        end
        
        function uninstallCallbacks(ax)
            % remove all callbacks except cla listener
            
            figh = AutoAxis.getParentFigure(ax.axh);
           
            % these work faster than listening on xlim and ylim, but can
            % not update depending on how the axis limits are set
            set(zoom(ax.axh),'ActionPreCallback',[]);
            set(pan(figh),'ActionPreCallback',[]);
            set(zoom(ax.axh),'ActionPostCallback',[]);
            set(pan(figh),'ActionPostCallback',[]);
            
            set(figh, 'ResizeFcn', []);
            
%             p = AutoAxis.getPanelForFigure(figh);
%             if ~isempty(p)
%                 p.setCallback([]);
%             end
            
            % delete axis limit and direction property listeners
            if ~isempty(ax.hListeners)
                delete(ax.hListeners);
                ax.hListeners = [];
            end

            ax.installedCallbacks = false;
        end
        
        function uninstallCallbacksForSave(ax)
            % delete axis limit and direction property listeners
            if ~isempty(ax.hListeners)
                delete(ax.hListeners);
                ax.hListeners = [];
            end
            ax.uninstallClaListener();
        end
        
        function installCallbacksOnLoad(ax)
            % listeners need to be cached so that we can delete them before
            % saving.
            hl(1) = addlistener(ax.axh, {'XDir', 'YDir'}, 'PostSet', @ax.axisCallback);
            hl(2) = addlistener(ax.axh, {'XLim', 'YLim'}, 'PostSet', @ax.axisIfLimsChangedCallback);
            ax.hListeners = hl;
            ax.installClaListener();
        end
        
        function installClaListener(ax)
            % reset this instance if the axis is cleared
            ax.hClaListener = event.listener(ax.axh, 'Cla', @AutoAxis.claCallback);
        end
        
        function uninstallClaListener(ax)
            if ~isempty(ax.hClaListener)
                delete(ax.hClaListener);
                ax.hClaListener = [];
            end
        end
        
        function isActive = checkCallbacksActive(ax)
            % look in the callbacks to see if the callbacks are still
            % installed
            hax = get(zoom(ax.axh),'ActionPostCallback');
            figh = AutoAxis.getParentFigure(ax.axh);
            hfig = get(figh, 'ResizeFcn');
            isActive = ~isempty(hax) && ~isempty(hfig);
        end
        
        function uninstall(ax)
            try
                ax.uninstallCallbacks();
                ax.uninstallClaListener();
                ax.restoreBuiltinAxes();
            catch
            end
            try
                rmappdata(ax.axh, 'AutoAxisInstance');
            catch
            end
        end
        
        function restoreBuiltinAxes(ax)
            sz = get(ax.axh, 'FontSize');
            % set big first
            ax.axh.XRuler.FontSize = sz;
            ax.axh.YRuler.FontSize = sz;
            axis(ax.axh, 'on');
            ax.hideBuiltinAxes = false;
        end
        
        function showMatlabAxes(ax)
            ax.restoreBuiltinAxes();
        end
        
        function hideMatlabAxes(ax)
            ax.hideBuiltinAxes = true;
        end
        
        function tf = checkLimsChanged(ax)
            tf = ~isequal(get(ax.axh, 'XLim'), ax.lastXLim) || ...
                ~isequal(get(ax.axh, 'YLim'), ax.lastYLim);
%             
%             if tf
%                 xl = get(ax.axh, 'XLim');
%                 yl = get(ax.axh, 'YLim');
%                 fprintf('Change [%.1f %.1f / %.1f %.1f] to [%.1f %.1f / %.1f %.1f]\n', ...
%                     ax.lastXLim(1), ax.lastXLim(2), ax.lastYLim(1), ax.lastYLim(1), ...
%                     xl(1), xl(2), yl(1), yl(2));
%             else
%                 fprintf('No Change [%.1f %.1f / %.1f %.1f]\n', ax.lastXLim(1), ax.lastXLim(2), ax.lastYLim(1), ax.lastYLim(1));
%             end
        end
        
        function prePanZoomCallback(ax, varargin)
            % first, due to weird issues with panning, make sure we have
            % the right auto axis for this update
            if numel(varargin) >= 2 && isstruct(varargin{2}) && isfield(varargin{2}, 'Axes')
                 axh = varargin{2}.Axes;
                 if ax.axh ~= axh
                     % try finding an AutoAxis for the axh that was passed in
                     ax = AutoAxis.recoverForAxis(axh);
                     if isempty(ax)
                         return;
                     end
                 end
            end
            ax.currentlyRepositioningAxes = true;
%             disp('Deleting listeners');
            delete(ax.hListeners);
            ax.hListeners = [];
        end
        
        function postPanZoomCallback(ax, varargin)
            % first, due to weird issues with panning, make sure we have
            % the right auto axis for this update
            if numel(varargin) >= 2 && isstruct(varargin{2}) && isfield(varargin{2}, 'Axes')
                 axh = varargin{2}.Axes;
                 if ax.axh ~= axh
                     % try finding an AutoAxis for the axh that was passed in
                     ax = AutoAxis.recoverForAxis(axh);
                     if isempty(ax)
                         return;
                     end
                 end
            end
            ax.currentlyRepositioningAxes = false;
            ax.axisCallback(varargin{:});
%             disp('Readding listeners');
            ax.installCallbacks();
        end 
        
        function axisIfLimsChangedCallback(ax, varargin)
            % similar to axis callback, but skips update if the limits
            % haven't changed since the last update
            if ax.isMultipleCall(), return, end
            
            if ax.currentlyRepositioningAxes
                % suppress updates when panning / zooming
                return;
            end
            
            % here we get clever. when panning or zooming, LocSetLimits is
            % used to set XLim, then YLim, which leads to two updates. We
            % check whether we're being called via LocSetLimits and then
            % don't update if we're setting the XLim, only letting the YLim
            % update pass through. This cuts our update time in half
            if numel(varargin) >= 1 && isa(varargin{1}, 'matlab.graphics.internal.GraphicsMetaProperty') 
                if strcmp(varargin{1}.Name, 'XLim')
                    %disp('X Update');
                    
                    % setting XLim, skip if in LocSetLimits
                    st = dbstack();
                    if ismember('LocSetLimits', {st.name})
                        %disp('Skipping X Update');
                        return;
                    end
                elseif strcmp(varargin{1}.Name, 'YLim')
                    %disp('Y Update');
                end
                
                
            end

            if ax.checkLimsChanged()
                ax.axisCallback();
            end
        end
        
        function axisCallback(ax, varargin)
            if ax.isMultipleCall(), return, end
            
             if numel(varargin) >= 2 && isstruct(varargin{2}) && isfield(varargin{2}, 'Axes')
                 axh = varargin{2}.Axes;
                 if ax.axh ~= axh
                     % try finding an AutoAxis for the axh that was passed in
                     axOther = AutoAxis.recoverForAxis(axh);
                     if ~isempty(axOther)
                         axOther.update();
                     else
                         % axis handle mismatch, happens sometimes if we save/load
                         % a figure. might need to remap handle pointers,
                         % though this should have happened automatically
                         % during load already
                         warning('AutoAxis axis callback triggered for different axis which has no AutoAxis itself.');
                         return;
%                          ax.axh = axh;
%                          ax.reconfigurePostLoad();
                     end
                 end
             end
             if ~isempty(ax.axh)
                 ax.update();
             end
        end
%         
        function reconfigurePostLoad(ax)
            % don't need to do this anymore in 2014b+: handles will be
            % recreated as is so they don't need to be remapped from their
            % tags anymore. the main purpose of this function is just to
            % install the callbacks again
            
            % old documentation
            % when loading from .fig files, all of the handles for the
            % graphics objects will have changed. go through each
            % referenced handle, look up its tag, and then replace the
            % reference with the new handle number.
            
            % loop through all of the tags we've stored, and build a map
            % from old handle to new handle
            
            % first find the overlay axis
            figh = AutoAxis.getParentFigure(ax.axh);
            if isempty(figh)
                return;
            end
            if ~isempty(ax.tagOverlayAxis)
                ax.axhDraw = findall(figh, 'Tag', ax.tagOverlayAxis, 'Type', 'axis');
                if isempty(ax.axhDraw)
%                     ax.uninstall();
                    error('Could not locate overlay axis. Uninstalling');
                end
            end
            
%             % build map old handle -> new handle
%             oldH = ax.handleTagObjects;
%             newH = oldH;
%             tags = ax.handleTagStrings;
%             for iH = 1:numel(oldH)
%                 % special case when searching for the axis itself
%                 if strcmp(ax.axhDraw.Tag, tags{iH})
%                     continue;
%                 end
%                 hNew = findall(ax.axhDraw, 'Tag', tags{iH});
%                 if isempty(hNew)
%                     warning('Could not recover tagged handle');
%                     hNew = AutoAxis.getNullHandle();
%                 end
%                 
%                 newH(iH) = hNew(1);
%             end
%             
%             % go through anchors and replace old handles with new handles
%             for iA = 1:numel(ax.anchorInfo)
%                 if ~ischar(ax.anchorInfo(iA).ha)
%                     ax.anchorInfo(iA).ha = updateHVec(ax.anchorInfo(iA).ha, oldH, newH);
%                 end
%                 if ~ischar(ax.anchorInfo(iA).h)
%                     ax.anchorInfo(iA).h  = updateHVec(ax.anchorInfo(iA).h, oldH, newH);
%                 end
%             end
%             
%             % go through collections and relace old handles with new
%             % handles
%             cNames = fieldnames(ax.collections);
%             for iC = 1:numel(cNames)
%                 ax.collections.(cNames{iC}) = updateHVec(ax.collections.(cNames{iC}), oldH, newH);
%             end
            
            % last, reinstall callbacks if they were installed originally
            if ax.installedCallbacks
                ax.installCallbacks();
            end
            
            ax.requiresReconfigure = false;
            
%             function new = updateHVec(old, oldH, newH)
%                 new = old;
%                 if ~ishandle(old)
%                     return;
%                 end
%                 for iOld = 1:numel(old)
%                     [tf, idx] = ismember(old(iOld), oldH);
%                     if tf
%                         new(iOld) = newH(idx);
%                     else
%                         new(iOld) = AutoAxis.getNullHandle();
%                     end
%                 end
%             end    
        end
        
        function tags = tagHandle(ax, hvec)
            % for each handle in vector hvec, set 'Tag'
            % on that handle to be something unique, and add this handle and
            % its tag to the .handleTag lookup table. 
            % This is used by recoverTaggedHandles
            % to repopulate stored handles upon figure loading or copying
            
            tags = cell(numel(hvec), 1);
            for iH = 1:numel(hvec)
                if isa(hvec(iH), 'matlab.graphics.GraphicsPlaceholder')
                    continue;
                end
                tags{iH} = ax.lookupHandleTag(hvec(iH));
                if isempty(tags{iH})
                    % doesn't already exist in map
                    tag = get(hvec(iH), 'Tag');
                    if isempty(tag)
                        tag = sprintf('autoAxis_%d', ax.nextTagId);
                    end
                    tags{iH} = tag;
                    ax.nextTagId = ax.nextTagId + 1;
                    ax.handleTagObjects(end+1) = hvec(iH);
                    ax.handleTagStrings{end+1} = tags{iH};
                end
                
                
                set(hvec(iH), 'Tag', tags{iH});
            end
        end
        
        function tag = lookupHandleTag(ax, h)
            [tf, idx] = ismember(h, ax.handleTagObjects);
            if tf
                tag = ax.handleTagStrings{idx(1)};
            else
                tag = '';
            end
        end
        
        function pruneStoredHandles(ax)
            % remove any invalid handles from my collections and tag lists
            
            % remove from tag cache
            mask = AutoAxis.isvalidSafe(ax.handleTagObjects);
            ax.handleTagObjects = ax.handleTagObjects(mask);
            ax.handleTagStrings = ax.handleTagStrings(mask);
            names = ax.listHandleCollections();
            
            % remove invalid handles from all handle collections
            for i = 1:numel(names)
                hvec = ax.collections.(names{i});
                ax.collections.(names{i}) = AutoAxis.filterValid(hvec);
            end
        end
        
        function addHandlesToCollection(ax, name, hvec)
            % add handles in hvec to the list ax.(name), updating all
            % anchors that involve that handle
            
            name = AutoAxisUtilities.makerow(name);
            if ~isfield(ax.collections, name)
                oldHvec = [];
            else
                oldHvec = ax.collections.(name);
            end

            newHvec = AutoAxisUtilities.makecol(union(oldHvec, hvec, 'stable'));
            
            % install the new collection
            ax.collections.(name) = newHvec;
            
            % make sure the handles are tagged
            ax.tagHandle(hvec);
            
            ax.refreshNeeded = true;
        end
        
        function names = listHandleCollections(ax)
            % return a list of all handle collection properties
            names = fieldnames(ax.collections);
        end
        
        function h = getHandlesInCollection(ax, names)
            % names is char or cellstr of collection name(s)
            if ischar(names)
                names = {names};
            end
            hc = cell(numel(names), 1);
            for i = 1:numel(names)
                name = AutoAxisUtilities.makerow(names{i});
                if isfield(ax.collections, name)
                    hc{i} = ax.collections.(name);
                elseif isfield(ax, name)
                    hc{i} = ax.(name);
                else
                    hc{i} = AutoAxis.allocateHandleVector(0);
                end
            end
            h = cat(1, hc{:});
        end
        
        function addAnchorToCollection(ax, name, hvec)
            % anchor collections have no function, just used for logically grouping anchors for easy removal / editing
            name = AutoAxisUtilities.makerow(name);
            if ~isfield(ax.anchorCollections, name)
                oldHvec = [];
            else
                oldHvec = ax.anchorCollections.(name);
            end

            newHvec = AutoAxisUtilities.makecol(union(oldHvec, hvec, 'stable'));
            
            % install the new collection
            ax.anchorCollections.(name) = newHvec;
        end
        
        function deleteAnchorCollection(ax, names)
            names = string(names);
            for i = 1:numel(names)
                name  = names(i);
                if name ~= "" && isfield(ax.anchorCollections, name)
                    ax.deleteAnchors(ax.anchorCollections.(name));
                end
            end
        end
        
        function names = listAnchorCollections(ax)
            % return a list of all handle collection properties
            names = fieldnames(ax.anchorCollections);
        end
        
        function h = getAnchorsInCollection(ax, names)
            % names is char or cellstr of collection name(s)
            names = string(names);
            hc = cell(numel(names), 1);
            for i = 1:numel(names)
                name = AutoAxisUtilities.makerow(names{i});
                if isfield(ax.anchorCollections, name)
                    hc{i} = ax.anchorCollections.(name);
                else
                    hc{i} = AutoAxis.AnchorInfo.empty(0, 1);
                end
            end
            h = cat(1, hc{:});
        end

        function removeHandles(ax, hvec, varargin)
            % remove handles from all handle collections and from each
            % anchor that refers to it. Prunes anchors that become empty
            % after pruning.
            if isempty(hvec)
                return;
            end
            
            p = inputParser();
            p.addParameter('whereReference', true, @islogical);
            p.addParameter('whereAnchor', true, @islogical);
            p.parse(varargin{:});
            whereReference = p.Results.whereReference;
            whereAnchor = p.Results.whereAnchor;
            
            % remove from tag list
            mask = AutoAxisUtilities.truevec(numel(ax.handleTagObjects));
            for iH = 1:numel(hvec)
                mask(hvec(iH) == ax.handleTagObjects) = false;
            end
            ax.handleTagObjects = ax.handleTagObjects(mask);
            ax.handleTagStrings = ax.handleTagStrings(mask);
            
            names = ax.listHandleCollections();
            
            % remove from all handle collections
            for i = 1:numel(names)
                ax.collections.(names{i}) = AutoAxis.setdiffHandles(ax.collections.(names{i}), hvec);
            end
            
            % remove from all anchors
            remove = false(numel(ax.anchorInfo), 1);
            for i = 1:numel(ax.anchorInfo)
                ai = ax.anchorInfo(i);
                if whereReference && ai.isHandleH % char would be collection reference, ignore
                    ai.h = AutoAxis.setdiffHandles(ai.h, hvec);
                    if isempty(ai.h), remove(i) = true; end
                end
                if whereAnchor && ai.isHandleHa % char would be collection reference, ignore
                    ai.ha = AutoAxis.setdiffHandles(ai.ha, hvec);
                    if isempty(ai.ha), remove(i) = true; end
                end
            end
            
            % filter the anchors for ones that still have some handles in
            % them
            ax.anchorInfo = ax.anchorInfo(~remove);
        end
    end
    
    methods(Static) % Static user-facing utilities
        function ax = replace(axh)
            % automatically replace title, axis labels, and ticks

            if nargin < 1
                axh = gca;
            end

            ax = AutoAxis(axh);
%             axis(axh, 'off');
            ax.addAutoAxisX();
            ax.addAutoAxisY();
            ax.addTitle();
            ax.update();
            ax.installCallbacks();
        end
        
        function ax = replaceGrid(axh)
            % automatically replace title, axis labels, and ticks

            if nargin < 1
                axh = gca;
            end

            ax = AutoAxis(axh);
%             axis(axh, 'off');
            ax.addAutoAxisX();
            ax.addAutoAxisY();
            ax.addTitle();
            ax.gridOn();
            ax.update();
            ax.installCallbacks();
        end
        
        function ax = replaceScaleBars(varargin)
            % automatically replace title, axis labels, and ticks

            p = inputParser();
            p.addOptional('axh', gca, @ishandle);
            p.addOptional('xUnits', '', @isstringlike);
            p.addOptional('yUnits', '', @isstringlike);
            p.addParameter('xLength', [], @isscalar);
            p.addParameter('yLength', [], @isscalar);
            p.addParameter('xScaleFactor', 1, @isscalar);
            p.addParameter('yScaleFactor', 1, @isscalar);
            p.addParameter('axes', 'xy', @isstringlike);
            p.parse(varargin{:});

            ax = AutoAxis(p.Results.axh);
            %axis(p.Results.axh, 'off');

            if ismember('x', p.Results.axes)
                ax.addAutoScaleBarX('units', p.Results.xUnits, 'scaleFactor', p.Results.xScaleFactor, 'length', p.Results.xLength);
            end
            if ismember('y', p.Results.axes)
                ax.addAutoScaleBarY('units', p.Results.yUnits, 'scaleFactor', p.Results.yScaleFactor, 'length', p.Results.yLength);
            end
            ax.addTitle();
            
            ax.axisMarginLeft = 0.1; % reduce the axis margin left since there won't be tickss
%             ax.axisMarginBottom = 1;
            ax.update();
            ax.installCallbacks();
        end
        
        function num = getenvNum(name, default)
            val = getenv(name);
            if isempty(val)
                num = default;
            else
                num = str2double(val);
                if isnan(num)
                    warning('AutoAxis:EnvironmentVariableInvalid', 'Environment variable %s invalid', name);
                    num = default;
                end
            end
        end
        
        function vec = getenvVec(name, default)
            val = getenv(name);
            if isempty(val)
                vec = default;
            else
                vec = str2vector(val);
                if isnan(vec)
                    warning('AutoAxis:EnvironmentVariableInvalid', 'Environment variable %s invalid', name);
                    vec = default;
                end
            end
        end
        
        function vec = setenvVec(name, vec)
           str = vec2str(vec);
           setenv(name, str);
        end
        
        function vec = setenvNum(name, value)
            vec = AutoAxis.getenvVec(name);
            str = num2str(value);
            setenv(name, str);
        end
    end

    methods % Pre-configured annotations and widgets to the axis
        function reset(ax)
        	ax.removeAutoAxisX();
            ax.removeAutoAxisY();
            ax.removeAutoScaleBarX();
            ax.removeAutoScaleBarY();
            
            % delete all generated content
            if isfield(ax.collections, 'generated')
                generated = ax.collections.generated;
                ax.removeHandles(generated);
                delete(AutoAxis.filterValid(generated));
            end
            
            % and update to prune anchors
            ax.update();
        end

        function gridOn(ax, mode, varargin)
            p = inputParser();
            p.addParameter('xMinor', false, @islogical);
            p.addParameter('yMinor', false, @islogical);
            p.parse(varargin{:});
            if nargin < 2
                mode = 'xy';
            end
            
            switch mode
                case 'x'
                    ax.axh.XGrid = 'on';
                    ax.axh.YGrid = 'off';

                case 'y'
                    ax.axh.XGrid = 'off';
                    ax.axh.YGrid = 'on';

                case {'both', 'xy'}
                    ax.axh.XGrid = 'on';
                    ax.axh.YGrid = 'on';

                otherwise
                    error('Mode must be x, y, or xy');
            end

            if p.Results.xMinor
                ax.axh.XMinorGrid = 'on';
            else
                ax.axh.XMinorGrid = 'off';
            end
            if p.Results.yMinor
                ax.axh.YMinorGrid = 'on';
            else
                ax.axh.YMinorGrid = 'off';
            end
            
            ax.backgroundColor = ax.gridBackground;
        end
        
        function gridOff(ax)
            ax.axh.XGrid = 'off';
            ax.axh.YGrid = 'off';
            ax.axh.XMinorGrid = 'off';
            ax.axh.YMinorGrid = 'off';
        end
        
        function deleteHandlesInCollection(ax, name)
            % delete all generated content
            if isfield(ax.collections, name)
                generated = ax.collections.(name);
                if ~isempty(generated)
                    ax.removeHandles(generated);
                    delete(AutoAxis.filterValid(generated));
                    ax.collections.(name) = [];
                end
            end
        end
        
        function clearX(ax)
            ax.removeAutoAxisX();
            ax.removeAutoScaleBarX();
            
            % delete all generated content
            ax.deleteHandlesInCollection('belowX');
            ax.deleteHandlesInCollection('aboveX');
            ax.xlabel('');
            
            % and update to prune anchors
            ax.update();
        end
        
        function clearAboveX(ax)
            % delete all generated content
            ax.deleteHandlesInCollection('aboveX');
            
            % and update to prune anchors
            ax.update();
        end
        
        function clearBelowX(ax)
            % delete all generated content
            ax.deleteHandlesInCollection('belowX');    
            
            % and update to prune anchors
            ax.update();
        end
        
        function clearY(ax)
            ax.removeAutoAxisY();
            ax.removeAutoScaleBarY();
            
            % delete all generated content
            ax.deleteHandlesInCollection('leftY')
            ax.deleteHandlesInCollection('rightY');
            ax.ylabel('');
            
            % and update to prune anchors
            ax.update();
        end
        
        function clearLeftY(ax)
            % delete all generated content
            ax.deleteHandlesInCollection('leftY')
            
            % and update to prune anchors
            ax.update();
        end
        
        function clearRightY(ax)
            % delete all generated content
            ax.deleteHandlesInCollection('rightY')
            
            % and update to prune anchors
            ax.update();
        end
        
        function addXLabelAnchoredToAxis(ax, xlabel, varargin)
            if nargin < 2
                xlabel = get(get(ax.axh, 'XLabel'), 'String');
            end
            ax.addXLabel(xlabel, varargin{:}, 'anchorToAxis', true);
        end
        
        function addXLabelAnchoredToDecorations(ax, xlabel, varargin)
            if nargin < 2
                xlabel = get(get(ax.axh, 'XLabel'), 'String');
            end
            ax.addXLabel(xlabel, varargin{:}, 'anchorToAxis', false);
        end
        
        function addXLabel(ax, varargin)
            % anchors and formats the existing x label
            
            p = inputParser();
            p.addOptional('xlabel', '', @isstringlike);
            p.addParameter('useNativeLabel', true, @islogical); % if false, we add a text box
            p.addParameter('lineSpacing', 'tickLabelOffset');
            p.addParameter('anchorToAxis', ax.anchorXLabelToAxis, @islogical);
            p.parse(varargin{:});
            
            ax.anchorXLabelToAxis = p.Results.anchorToAxis;
            
            % remove any existing anchors with XLabel
            ax.removeHandles(get(ax.axh, 'XLabel'), whereAnchor=false);
            
            import AutoAxis.PositionType;
            useNativeLabel = p.Results.useNativeLabel;

            if useNativeLabel
                if ~isempty(p.Results.xlabel)
                    xlabel(ax.axh, p.Results.xlabel);
                end
                hlabel = get(ax.axh, 'XLabel');
                set(hlabel, 'Visible', 'on', ...
                    'FontSize', ax.labelFontSize, ...
                    'Margin', 0.1, ...
                    'Color', ax.labelFontColor, ...
                    'HorizontalAlign', 'center', ...
                    'VerticalAlign', 'top');
            else
                label = string(p.Results.xlabel);
                hlabel = gobjects(numel(label), 1);
                for iL = 1:numel(label)
                    hlabel(iL) = text(0, 0, label(iL), XLimInclude=false, YLimInclude=false, ...
                        FontSize=ax.labelFontSize, Margin=0.1, Color=ax.labelFontColor, ...
                        HorizontalAlign='center', VerticalAlign='top');
                end
                if numel(label) > 1
                    % need multiple text boxes, and to add anchoring
                    ax.anchorAsStack(hlabel, stacking="vertical", spacing=p.Results.lineSpacing);
                end
            end
            if ax.debug
                set(hlabel, 'EdgeColor', 'r');
            end
            
            if strcmp(ax.axh.XAxisLocation, 'bottom')
                if p.Results.anchorToAxis
                    % anchor directly below axis
                    ai = AutoAxis.AnchorInfo(hlabel, PositionType.Top, ...
                        ax.axh, PositionType.Bottom, 'axisLabelOffsetBottom', ...
                        'xlabel below axis');
                else
                    % anchor below the belowX objects
                    ai = AutoAxis.AnchorInfo(hlabel, PositionType.Top, ...
                        'belowX', PositionType.Bottom, 'decorationLabelOffsetBottom', ...
                        'xlabel below belowX');
                end
            else
                % axis on top
                if p.Results.anchorToAxis
                    % anchor directly below axis
                    ai = AutoAxis.AnchorInfo(hlabel, PositionType.Bottom, ...
                        ax.axh, PositionType.Top, 'axisLabelOffsetTop', ...
                        'xlabel above axis');
                else
                    % anchor below the belowX objects
                    ai = AutoAxis.AnchorInfo(hlabel, PositionType.Bottom, ...
                        'aboveX', PositionType.Top, 'decorationLabelOffsetTop', ...
                        'xlabel above aboveX');
                end
            end
            ax.addAnchor(ai);
            
            % and in the middle of the x axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.HCenter, ...
                ax.axh, PositionType.HCenter, 'xLabelHorizontalOffset', 'xLabel centered on x axis');
            ax.addAnchor(ai);
            ax.hXLabel = hlabel;
        end
        
        function xlabel(ax, varargin)
            if nargin == 2
                str = varargin{1};
            else
                str = sprintf(varargin{:});
            end
            xlabel(ax.axh, str);
        end
        
        function addYLabelAnchoredToAxis(ax, ylabel, varargin)
            if nargin < 2
                ylabel = get(get(ax.axh, 'YLabel'), 'String');
            end
            ax.addYLabel(ylabel, varargin{:}, 'anchorToAxis', true);
        end
        
        function addYLabelAnchoredToDecorations(ax, ylabel, varargin)
            if nargin < 2
                ylabel = get(get(ax.axh, 'YLabel'), 'String');
            end
            ax.addYLabel(ylabel, varargin{:}, 'anchorToAxis', false);
        end
        
        function addYLabel(ax, varargin)
            % anchors and formats the existing y label
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addOptional('ylabel', '', @isstringlike);
            p.addParameter('useNativeLabel', true, @islogical);
            p.addParameter('lineSpacing', 'tickLabelOffset');
            p.addParameter('anchorToAxis', ax.anchorYLabelToAxis, @islogical);
            p.parse(varargin{:});
            
            ax.anchorYLabelToAxis = p.Results.anchorToAxis;
            
            % remove any existing anchors with XLabel
            ax.removeHandles(get(ax.axh, 'YLabel'), whereAnchor=false);
            
            useNativeLabel = p.Results.useNativeLabel;

            if useNativeLabel
                if ~isempty(p.Results.ylabel)
                    ylabel(ax.axh, p.Results.ylabel);
                end
                hlabel = get(ax.axh, 'YLabel');
                set(hlabel, 'Visible', 'on', ...
                    'FontSize', ax.labelFontSize, ...
                    'Margin', 0.1, ...
                    'Color', ax.labelFontColor, ...
                    'HorizontalAlign', 'center', ...
                    'VerticalAlign', 'top');
            else
                label = string(p.Results.ylabel);
                hlabel = gobjects(numel(label), 1);
                for iL = 1:numel(label)
                    hlabel(iL) = text(0, 0, label(iL), XLimInclude=false, YLimInclude=false, ...
                        Rotation=90, FontSize=ax.labelFontSize, Margin=0.1, Color=ax.labelFontColor, ...
                        HorizontalAlign='center', VerticalAlign='bottom');
                end
                if numel(label) > 1
                    % need multiple text boxes, and to add anchoring
                    ax.anchorAsStack(hlabel, stacking="horizontal", spacing=p.Results.lineSpacing);
                end
            end

            if ax.debug
                set(hlabel, 'EdgeColor', 'r');
            end

            if strcmp(ax.axh.YAxisLocation, 'left')
                % left side
                if p.Results.anchorToAxis
                    % anchor directly left of axis
                    ai = AutoAxis.AnchorInfo(hlabel, PositionType.Right, ...
                        ax.axh, PositionType.Left, 'axisLabelOffsetLeft', ...
                        'ylabel left of axis');
                else
                    % anchor left of the leftY objects
                    ai = AutoAxis.AnchorInfo(hlabel, PositionType.Right, ...
                        'leftY', PositionType.Left, 'decorationLabelOffsetLeft', ...
                        'ylabel left of leftY');
                end
            else
                % right side
                if p.Results.anchorToAxis
                    % anchor directly right of axis
                    ai = AutoAxis.AnchorInfo(hlabel, PositionType.Left, ...
                        ax.axh, PositionType.Right, 'axisLabelOffsetRight', ...
                        'ylabel right of axis');
                else
                    % anchor right of the rightY objects
                    ai = AutoAxis.AnchorInfo(hlabel, PositionType.Left, ...
                        'rightY', PositionType.Right, 'decorationLabelOffsetRight', ...
                        'ylabel right of rightY');
                end
            end
            
            ax.addAnchor(ai);
            
            % and in the middle of the y axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.VCenter, ...
                ax.axh, PositionType.VCenter, 'yLabelVerticalOffset', 'yLabel centered on y axis');
            ax.addAnchor(ai);
            
            ax.hYLabel = hlabel;
        end
        
        function ylabel(ax, varargin)
            if nargin == 2
                str = varargin{1};
            else
                str = sprintf(varargin{:});
            end
            %ylabel(ax.axh, str);
            ax.addYLabel(str);
        end
        
        function addAutoAxisX(ax, varargin)
            p = inputParser();
            p.addParameter('label', '', @isstringlike);
            p.addParameter('extendToLimits', ax.autoAxisXExtendToLimits, @islogical);
            p.addParameter('persistUnmatchedArgs', true, @islogical); % allows update() to call without extra args
            p.parse(varargin{:});
            ax.autoAxisXExtendToLimits = p.Results.extendToLimits;
            if p.Results.persistUnmatchedArgs
                ax.yAutoAxisInfo = p.Unmatched;
            end
            
            import AutoAxis.PositionType;
            if ~isempty(ax.autoAxisX)
                % delete the old axes
                try delete(ax.autoAxisX.h); catch, end
                remove = ax.autoAxisX.h;
            else
                remove = [];
            end
           
            hlist = ax.addTickBridge('x', ...
                'useAutoAxisCollections', true, ...
                'addAnchors', true, ...
                'otherSide', strcmp(ax.axh.XAxisLocation, 'top'), ...
                'extendToLimits', ax.autoAxisXExtendToLimits, ...
                'manualPositionOrthogonalAxis', ax.autoAxisXManualPositionY, ax.xAutoAxisInfo);
            ax.autoAxisX.h = hlist;
            
            % remove after the new ones are added by addTickBridge
            % so that anchors aren't deleted
            ax.removeHandles(remove);
            
            ax.addXLabel(p.Results.label);
        end
        
        function removeAutoAxisX(ax, varargin)
            import AutoAxis.PositionType;
            if ~isempty(ax.autoAxisX)
                % delete the old axes
                try delete(ax.autoAxisX.h); catch, end
                ax.removeHandles(ax.autoAxisX.h);
                ax.autoAxisX = [];
            end
        end
        
        function addAutoAxisY(ax, varargin)
            p = inputParser();
            p.addParameter('label', '', @isstringlike);
            p.addParameter('extendToLimits', ax.autoAxisYExtendToLimits, @islogical);
            p.addParameter('persistUnmatchedArgs', true, @islogical); % allows update() to call without extra args
            p.KeepUnmatched = true;
            p.parse(varargin{:});
            ax.autoAxisYExtendToLimits = p.Results.extendToLimits;
            if p.Results.persistUnmatchedArgs
                ax.yAutoAxisInfo = p.Unmatched;
            end
            
            import AutoAxis.PositionType;
            if ~isempty(ax.autoAxisY)
                % delete the old objects
                try
                    delete(ax.autoAxisY.h);
                catch
                end
                
                % remove from handle collection
                remove = ax.autoAxisY.h;
            else
                remove = [];
            end
            
%             firstTime = true;
            
            hlist = ax.addTickBridge('y', ...
                'useAutoAxisCollections', true, ...
                'addAnchors', true, ...
                'otherSide', strcmp(ax.axh.YAxisLocation, 'right'), ...
                'extendToLimits', ax.autoAxisYExtendToLimits, ...
                'manualPositionOrthogonalAxis', ax.autoAxisYManualPositionX, ax.yAutoAxisInfo);
            ax.autoAxisY.h = hlist;
            
            % remove after the new ones are added by addTickBridge
            % so that anchors aren't deleted
            ax.removeHandles(remove);
            ax.addYLabel(p.Results.label);
        end
        
        function removeAutoAxisY(ax, varargin)
            import AutoAxis.PositionType;
            if ~isempty(ax.autoAxisY)
                % delete the old axes
                try delete(ax.autoAxisY.h); catch, end
                ax.removeHandles(ax.autoAxisY.h);
                ax.autoAxisY = [];
            end
        end
        
        function addAutoBridgeX(ax, varargin)
            p = inputParser;
            p.addParameter('drawBridge', true, @islogical); % if false, just sets the grid lines and blanks spaces between
            p.addParameter('zero', 0, @isscalar); % location on axis of 0
            p.addParameter('start', 0, @isscalar); % location relative to zero of start
            p.addParameter('stop', 0, @isscalar); % location relative to zero of stop
            p.addParameter('zeroLabel', '0', @isstringlike); % label associated with 0
            p.addParameter('autoTicks', true, @islogical); % use autoticks, false means just start stop and zero
            p.addParameter('hideGridAfter', true, @islogical); % automatically mask grid to the right of
            p.addParameter('extendToLimits', 'auto', @(x) true); % automatically mask grid to the right of
            p.addParameter('tickLabelOffset', []);
            p.addParameter('bridgeLabelOffset', []);
            p.parse(varargin{:});
            
            info = p.Results;
            assert(info.start <= info.stop);
            if isempty(ax.xAutoBridgeInfo)
                ax.xAutoBridgeInfo = info;
            else
                if any([ax.xAutoBridgeInfo.zero] >= info.zero)
                    warning('Deleting existing auto bridges on x axis');
                    ax.clearAutoBridgeX();
                    ax.xAutoBridgeInfo = info;
                else
                    ax.xAutoBridgeInfo(end+1, 1) = info;
                end
            end
        end
        
        function addAutoBridgeY(ax, varargin)
            p = inputParser;
            p.addParameter('drawBridge', true, @islogical); % if false, just sets the grid lines and blanks spaces between
            p.addParameter('zero', 0, @isscalar); % location on axis of 0
            p.addParameter('start', 0, @isscalar); % location relative to zero of start
            p.addParameter('stop', 0, @isscalar); % location relative to zero of stop
            p.addParameter('zeroLabel', '0', @isstringlike); % label associated with 0
            p.addParameter('autoTicks', true, @islogical); % use autoticks, false means just start stop and zero
            p.addParameter('hideGridAfter', true, @islogical); % automatically mask grid to the right of
            p.addParameter('tickLabelOffset', []);
            p.addParameter('bridgeLabelOffset', []);
            p.parse(varargin{:});
            
            info = p.Results;
            if isempty(ax.yAutoBridgeInfo)
                ax.yAutoBridgeInfo = info;
            else
                if any([ax.yAutoBridgeInfo.zero] >= info.zero)
                    warning('Deleting existing auto bridges on x axis');
                    ax.clearAutoBridgeY();
                    ax.yAutoBridgeInfo = info;
                else
                    ax.yAutoBridgeInfo(end+1, 1) = info;
                end
            end
        end 
        
        function clearAutoBridgeX(ax)
            % delete the old objects
            remove = cat(1, ax.xAutoBridge{:});
            for i = 1:numel(ax.xAutoBridge)
                try
                    delete(ax.xAutoBridge{i});
                catch
                end
            end
            ax.removeHandles(remove);
        end
        
        function clearAutoBridgeY(ax)
            remove = cat(1, ax.xAutoBridge{:});
            for i = 1:numel(ax.yAutoBridge)
                try
                    delete(ax.yAutoBridge{i});
                catch
                end
            end
            ax.removeHandles(remove);
        end
        
        function updateAutoBridges(ax)
            import AutoAxis.PositionType;
            import AutoAxis.AnchorInfo;
            
            % delete the old objects
            remove = cat(1, ax.xAutoBridge{:}, ax.yAutoBridge{:});
%             firstTime = isempty(remove);
            for i = 1:numel(ax.xAutoBridge)
                try
                    delete(ax.xAutoBridge{i});
                catch
                end
            end
            for i = 1:numel(ax.yAutoBridge)
                try
                    delete(ax.yAutoBridge{i});
                catch
                end
            end
            
            if ~isempty(ax.xAutoBridgeInfo)
                [ax.xAutoBridge, xticks, xticksminor] = cellvec(numel(ax.xAutoBridgeInfo));
                for i = 1:numel(ax.xAutoBridgeInfo)
                    [args, xticks{i}, xticksminor{i}] = generateTickArgs(ax.xAutoBridgeInfo(i), 'x');
                    other_args = generateOtherArgs(ax.xAutoBridgeInfo(i), 'x');
                    infoThis = ax.xAutoBridgeInfo(i);
                    if infoThis.drawBridge && ~isempty(xticks{i})
                        hlist = ax.addTickBridge('x', ...
                            'useAutoBridgeCollections', true, ...
                            'addAnchors', i == 1, ...
                            'otherSide', strcmp(ax.axh.XAxisLocation, 'right'), args{:}, other_args{:});
                    else
                        hlist = gobjects(0, 1);
                    end
                    if i < numel(ax.xAutoBridgeInfo) && infoThis.hideGridAfter
                        infoNext = ax.xAutoBridgeInfo(i+1);
                        start = infoThis.zero + infoThis.stop;
                        stop = infoNext.start + infoNext.zero;
                        if stop > start % this can be false if the alignments have offsets that make them overlap, in which case we can't do anything
                            hrect = rectangle('Position', [start 0 stop-start 1], 'FaceColor', ax.figh.Color, 'EdgeColor', 'none', 'Parent', ax.axhDraw, ...
                                'YLimInclude', 'off', 'XlimInclude', 'off');
                            ax.addAnchor(AnchorInfo(hrect, PositionType.Top, ax.axh, PositionType.Top, 0, 'gridMasking'));
                            ax.addAnchor(AnchorInfo(hrect, PositionType.Bottom, ax.axh, PositionType.Bottom, 0, 'gridMaskingRect', 'translateDontScale', false));
                            hlist(end+1) = hrect; %#ok<AGROW>
                            ax.stackBottom(hrect);
                        end
                    end
                    
                    ax.xAutoBridge{i} = hlist;
                end

                xticks = unique(cat(1, xticks{:}));
                xticksminor = unique(cat(1, xticksminor{:}));
                ax.axh.XTick = xticks;
                if ~verLessThan('matlab', 'R2017a')
                    ax.axh.XRuler.MinorTickValues = xticksminor;
                end
            end

            if ~isempty(ax.yAutoBridgeInfo)
                [ax.yAutoBridge, yticks, yticksminor] = cellvec(numel(ax.yAutoBridgeInfo));
                for i = 1:numel(ax.yAutoBridgeInfo)
                    [args, yticks{i}, yticksminor{i}] = generateTickArgs(ax.yAutoBridgeInfo(i), 'y');
                    other_args = generateOtherArgs(ax.xAutoBridgeInfo(i), 'x');
                    infoThis = ax.yAutoBridgeInfo(i);
                    if infoThis.drawBridge && ~isempty(yticks{i})
                        hlist = ax.addTickBridge('y', ...
                            'useAutoBridgeCollections', true, ...
                            'addAnchors', i == 1, ...
                            'otherSide', strcmp(ax.axh.YAxisLocation, 'top'), args{:}, other_args{:});
                    else
                        hlist = gobjects(0, 1);
                    end
                    if i < numel(ax.yAutoBridgeInfo) && infoThis.hideGridAfter
                        infoNext = ax.yAutoBridgeInfo(i+1);
                        start = infoThis.zero + infoThis.stop;
                        stop = infoNext.start + infoNext.zero;
                        hrect = rectangle('Position', [0 start 1 stop-start], ...
                            'FaceColor', ax.figh.Color, 'EdgeColor', 'none', ...
                            'XLimInclude', 'off', 'YLimInclude', 'off', 'Parent', ax.axhDraw);
                        ax.addAnchor(AnchorInfo(hrect, PositionType.Left, ax.axh, PositionType.Left, 0, 'gridMasking'));
                        ax.addAnchor(AnchorInfo(hrect, PositionType.Right, ax.axh, PositionType.Right, 0, 'gridMaskingRect', 'translateDontScale', false));
                        hlist(end+1) = hrect; %#ok<AGROW>
                        ax.stackBottom(hrect);
                    end
                    ax.yAutoBridge{i} = hlist;
                end
                
                yticks = unique(cat(1, yticks{:}));
                yticksminor = unique(cat(1, yticksminor{:}));
                ax.axh.YTick = yticks;
                if ~verLessThan('matlab', 'R2017a')
                    ax.axh.YRuler.MinorTickValues = yticksminor;
                end
            end

            % remove after the new ones are added by addTickBridge
            % so that anchors aren't deleted
            ax.removeHandles(remove);
            
            function [args, autoTicks, autoTicksMinor] = generateTickArgs(info, which)
                if strcmp(which, 'x')
                    exponent = double(ax.axh.XRuler.Exponent);
                    autoMajor = ax.xAutoMajor;
                    autoMinor = ax.xAutoMinor;
                else
                    exponent = double(ax.axh.YRuler.Exponent);
                    autoMajor = ax.yAutoMajor;
                    autoMinor = ax.yAutoMinor;
                end
                autoTicks = info.zero + AutoAxis.linspaceIntercept(info.start, autoMajor, info.stop, 0);
                autoTicksMinor = info.zero + AutoAxis.linspaceIntercept(info.start, autoMinor, info.stop, 0);
                
                if info.autoTicks
                    ticks = autoTicks;
                    labels = sprintfc('%g', (ticks-info.zero) / 10^exponent);
                    labels(info.zero == ticks) = {info.zeroLabel};
                else
                    ticks = info.zero + [info.start; 0; info.stop];
                    labels = sprintfc('%g', (ticks-info.zero)/ 10^exponent);
                    labels{2} = info.zeroLabel;
                end
                
                % filter ticks and labels by visible
                if strcmp(which, 'x')
                    lim = ax.axh.XLim;
                else
                    lim = ax.axh.YLim;
                end
                [~, indUnique] = unique(ticks);
                mask = false(size(ticks));
                mask(indUnique) = true;
                mask(ticks < lim(1) | ticks > lim(2)) = false;
                ticks = makecol(ticks(mask));
                labels = labels(mask);
                autoTicks(autoTicks < lim(1) | autoTicks > lim(2)) = [];
                
                if isfield(info, 'extendToLimits')
                    extendToLimits = info.extendToLimits;
                else
                    extendToLimits = 'auto';
                end
                if strcmp(extendToLimits, 'auto')
                    if strcmp(which, 'x')
                        extendToLimits = ax.autoAxisXExtendToLimits;
                    else
                        extendToLimits = ax.autoAxisYExtendToLimits;
                    end
                end
                
                args = {'extendToLimits', extendToLimits, 'tick', ticks, 'tickLabel', labels};
                if info.autoTicks
                    args = cat(2, args, {'alignOuterLabelsInwards', false});
                end
                if extendToLimits
                    args = cat(2, args, {'span', [info.start info.stop] + info.zero});
                end
            end

            function args = generateOtherArgs(info, which) %#ok<INUSD> 
                args = struct();
                if isfield(info, 'bridgeLabelOffset') && ~isempty(info.bridgeLabelOffset)
                    args.bridgeLabelOffset = info.bridgeLabelOffset;
                end

                if isfield(info, 'tickLabelOffset') && ~isempty(info.tickLabelOffset)
                    args.tickLabelOffset = info.tickLabelOffset;
                end

                args = namedargs2cell(args);
            end
        end
        
        function addAutoScaleBarX(ax, varargin)
            p = inputParser;
            % this will be called with no arguments on each update, so the
            % params here should maintain the current settings
            p.addParameter('units', ax.xUnits, @isstringlike);
            p.addParameter('length', ax.scaleBarLenX, @(x) isempty(x) || isscalar(x));
            p.addParameter('hideLabel', ax.scaleBarHideLabelX, @islogical);
            p.addParameter('scaleFactor', ax.scaleBarScaleFactorX, @isscalar);
            p.parse(varargin{:});
            
            ax.xUnits = p.Results.units;
            ax.scaleBarLenX = p.Results.length;
            ax.scaleBarHideLabelX = p.Results.hideLabel;
            ax.scaleBarScaleFactorX = p.Results.scaleFactor;
            
            % adds a scale bar to the x axis that will automatically update
            % its length to match the major tick interval along the x axis
            if ~isempty(ax.autoScaleBarX)
                firstTime = false;
                
                % delete the old objects
                try delete(ax.autoScaleBarX.h); catch, end
                
                % remove from handle collection
                remove = ax.autoScaleBarX.h;
            else
                firstTime = true;
                remove = [];
            end
            
            alignWithOther = ~isempty(ax.autoScaleBarY) || ax.autoScaleBarX_forceAlignWithOther;
            
            % if the corresponding scale bar is added, we have to update the anchors
            if ax.autoScaleBarX_anchorsAlignedWithY ~= alignWithOther
                firstTime = true;
            end
            
            ax.autoScaleBarX.h = ax.addScaleBar('x', ...
                'units', ax.xUnits, 'length', ax.scaleBarLenX, ...
                'hideLabel', ax.scaleBarHideLabelX, 'scaleFactor', ax.scaleBarScaleFactorX, ...
                'useAutoScaleBarCollection', true, 'addAnchors', firstTime, ...
                'alignWithOtherScaleBar', alignWithOther);
            
            ax.autoScaleBarX_anchorsAlignedWithY = alignWithOther;
            
            % remove after the new ones are added by addTickBridge
            % so that the existing anchors aren't deleted
            ax.removeHandles(remove);
        end
        
        function removeAutoScaleBarX(ax, varargin)
            if ~isempty(ax.autoScaleBarX)
                try delete(ax.autoScaleBarX.h); catch, end
                ax.removeHandles(ax.autoScaleBarX.h);
                ax.autoScaleBarX = [];
            end
        end
        
        function addAutoScaleBarY(ax, varargin)
            p = inputParser;
            % this will be called with no arguments on each update, so the
            % params here should maintain the current settings
            p.addParameter('units', ax.yUnits, @isstringlike);
            p.addParameter('length', ax.scaleBarLenY, @(x) isempty(x) || isscalar(x));
            p.addParameter('hideLabel', ax.scaleBarHideLabelY, @islogical);
            p.addParameter('scaleFactor', ax.scaleBarScaleFactorY, @isscalar);
            
            p.parse(varargin{:});
            
            ax.yUnits = p.Results.units;
            ax.scaleBarLenY = p.Results.length;
            ax.scaleBarHideLabelY = p.Results.hideLabel;
            ax.scaleBarScaleFactorY = p.Results.scaleFactor;
            
            % adds a scale bar to the x axis that will automatically update
            % its length to match the major tick interval along the x axis
            if ~isempty(ax.autoScaleBarY)
                firstTime = false;
                
                % delete the old objects
                try
                    delete(ax.autoScaleBarY.h);
                catch
                end
                
                % remove from handle collection
                remove = ax.autoScaleBarY.h;
            else
                firstTime = true;
                remove = [];
            end
            
            alignWithOther = ~isempty(ax.autoScaleBarX) || ax.autoScaleBarY_forceAlignWithOther;
            % if the corresponding scale bar is added, we have to update the anchors
            if ax.autoScaleBarY_anchorsAlignedWithX ~= alignWithOther
                firstTime = true;
            end
            
            ax.autoScaleBarY.h = ax.addScaleBar('y', 'units', ax.yUnits, ...
                'useAutoScaleBarCollections', true, 'addAnchors', firstTime, ...
                'hideLabel', ax.scaleBarHideLabelY, 'scaleFactor', ax.scaleBarScaleFactorY, ...
                'length', ax.scaleBarLenY, 'alignWithOtherScaleBar', alignWithOther);
            
            ax.autoScaleBarY_anchorsAlignedWithX = alignWithOther;
            
            % remove after the new ones are added by addTickBridge
            % so that the existing anchors aren't deleted
            ax.removeHandles(remove);
        end
        
        function removeAutoScaleBarY(ax, varargin)
            if ~isempty(ax.autoScaleBarY)
                try delete(ax.autoScaleBarY.h); catch, end
                ax.removeHandles(ax.autoScaleBarY.h);
                ax.autoScaleBarY = [];
            end
        end
        
        function addTitle(ax, varargin)
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addOptional('title', '', @isstringlike);
            p.addParameter('HorizontalAlignment', ax.axh.TitleHorizontalAlignment, @isstringlike);
            p.addParameter('alignOuter', ax.titleAlignOuter, @islogical);
            p.parse(varargin{:});
            
            if ~isempty(p.Results.title)
                title(ax.axh, p.Results.title);
            end
            
            hlabel = get(ax.axh, 'Title');
            set(hlabel, 'FontSize', ax.titleFontSize, 'Color', ax.titleFontColor, ...
                'FontWeight', ax.titleFontWeight, ...
                'Margin', 0.1, 'HorizontalAlign', 'center', ...
                'VerticalAlign', 'bottom', 'BackgroundColor', 'none');
            if ax.debug
                set(hlabel, 'EdgeColor', 'r');
            end
            
            % anchor title vertically above axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.Bottom, ...
                ax.axh, PositionType.Top, ...
                'axisPaddingTop', 'Title above axis');
            ax.addAnchor(ai);
            
            % anchor title horizontally centered on axis
%             ai = AutoAxis.AnchorInfo(hlabel, PositionType.HCenter, ...
%                 ax.axh, PositionType.HCenter, ...
%                 0, 'Title centered on axis');
%             ax.addAnchor(ai);
            
            ax.hTitle = hlabel;
        end
        
        function title(ax, varargin)
            if nargin == 2
                str = varargin{1};
            else
                str = sprintf(varargin{:});
            end
            title(ax.axh, str);
        end
        
        function ht = addTicklessLabels(ax, varargin)
            % add labels to x or y axis where ticks would appear but
            % without the tick marks, i.e. positioned labels
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @isstringlike);
            
            p.addParameter('location', [], @(x) isempty(x) || isa(x, 'AutoAxis.FullPositionSpec')); 
            
            p.addParameter('tick', [], @isvector);
            p.addParameter('tickLabel', {}, @(x) isempty(x) || iscellstr(x) || isstring(x));
            p.addParameter('tickAlignment', [], @(x) isempty(x) || iscellstr(x) || isstring(x));
            p.addParameter('orthTickAlignment', [], @(x) isempty(x) || iscellstr(x) || isstring(x));
            p.addParameter('offset', [], @(x) true); % default is axisPadding
            p.addParameter('rotation', 0, @isscalar);
            p.addParameter('multilineSpacing', 0, @isscalar);
            p.addParameter('fontSize', ax.tickFontSize, @isscalar);
            p.addParameter('color', ax.tickColor, @(x) true);
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh;
            useX = strcmp(p.Results.orientation, 'x');
            if ~isempty(p.Results.tick)
                ticks = p.Results.tick;
                labels = p.Results.tickLabel;
            elseif useX
                ticks = axh.xAutoTicks;
                labels = axh.xAutoTickLabels;
            else
                ticks = axh.yAutoTicks;
                labels = axh.yAutoTickLabels;
            end
            
            if isempty(p.Results.location)
                outside = true;
                if useX
                    offset = {'axisPaddingBottom', 'tickLabelOffset'};
                else
                    offset = {'', 'tickLabelOffset'};
                end
            elseif useX
                outside = p.Results.location.outsideY;
                offset = p.Results.location.offsetY;
            else
                outside = p.Results.location.outsideX;
                offset = p.Results.location.offsetX;
            end
                
            if isempty(labels)
                labels = sprintfc("%g", ticks);
            end
            labels = string(labels);
            
            if isempty(p.Results.tickAlignment)
                if useX
                    tickAlignment = repmat({'center'}, numel(ticks), 1);
                else
                    tickAlignment = repmat({'middle'}, numel(ticks), 1);
                end
            else
                if iscell(p.Results.tickAlignment)
                    tickAlignment = p.Results.tickAlignment;
                else
                    tickAlignment = repmat({char(p.Results.tickAlignment)}, numel(ticks), 1);
                end
            end
            
            color = p.Results.color;
            fontSize = p.Results.fontSize;
            
            % generate line, ignore length here, we'll anchor that later
            if useX
                xtext = ticks;
                ytext = 0 * ticks;
                ha = tickAlignment;

                if isempty(p.Results.orthTickAlignment)
                    if outside
                        va = repmat({'top'}, numel(ticks), 1);
                    else
                        va = repmat({'bottom'}, numel(ticks), 1);
                    end
                else
                    if iscell(p.Results.orthTickAlignment)
                        va = p.Results.orthTickAlignment;
                    else
                        va = repmat({char(p.Results.orthTickAlignment)}, numel(ticks), 1);
                    end
                end
            else
                % y axis labels
                xtext = 0* ticks;
                ytext = ticks;
                if isempty(p.Results.orthTickAlignment)
                    if outside
                        ha = repmat({'right'}, numel(ticks), 1);
                    else
                        ha = repmat({'left'}, numel(ticks), 1);
                    end
                else
                    if iscell(p.Results.orthTickAlignment)
                        ha = p.Results.orthTickAlignment;
                    else
                        ha = repmat({char(p.Results.verticalTickAlignment)}, numel(ticks), 1);
                    end
                end
                va = tickAlignment;
                offset = {'axisPaddingLeft', 'tickLabelOffset'};
            end
            
            ht = cell(numel(ticks, 1)); % we'll concatenate later
            for i = 1:numel(ticks)
                % check for newlines within ticks, which require special handling
                if contains(labels(i), "\n")
                    lines = split(labels(i), "\n");
                    hlines = gobjects(numel(lines), 1);
                    for iL = 1:numel(lines)
                        hlines(iL) = text(xtext(i), ytext(i), lines{iL}, ...
                        'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                        'Interpreter', 'none', 'Parent', ax.axhDraw, 'Background', 'none', Rotation=p.Results.rotation);
                    end
                    ht{i} = hlines;
                    
                    % add the anchor to stack them
                    if useX
                        ax.anchorAsStack(hlines, stacking="horizontal", spacing=p.Results.multilineSpacing);
                        ax.anchorToDataLiteral(hlines, AutoAxis.PositionType.Center, xtext(i));
                    else
                        ax.anchorAsStack(hlines, stacking="vertical", spacing=p.Results.multilineSpacing);
                        ax.anchorToDataLiteral(hlines, AutoAxis.PositionType.VCenter, ytext(i));
                    end
                else
                    ht{i} = text(xtext(i), ytext(i), labels{i}, ...
                        'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                        'Interpreter', 'none', 'Parent', ax.axhDraw, 'Background', 'none', Rotation=p.Results.rotation);
                end
            end
            ht = cat(1, ht{:});
            set(ht, 'Clipping', 'off', 'Margin', 0.1, 'FontSize', fontSize, ...
                    'Color', color);
                
            if ax.debug
                set(ht, 'EdgeColor', 'r');
            end
            
            if ~isempty(p.Results.offset)
                offset = p.Results.offset;
            end
            
            % build anchor for labels to axis
            if useX
                if outside
                    ai = AnchorInfo(ht, PositionType.Top, ax.axh, ...
                        PositionType.Bottom, offset, 'xTicklessLabels below axis');
                else
                    ai = AnchorInfo(ht, PositionType.Bottom, ax.axh, ...
                        PositionType.Bottom, offset, 'xTicklessLabels within axis');
                end
                ax.addAnchor(ai);
            else
                if outside
                    ai = AnchorInfo(ht, PositionType.Right, ...
                        ax.axh, PositionType.Left, offset, 'yTicklessLabels left of axis');
                else
                    ai = AnchorInfo(ht, PositionType.Left, ...
                        ax.axh, PositionType.Left, offset, 'yTicklessLabels left of axis');
                end
                ax.addAnchor(ai);
            end
            
            % add handles to handle collections
            ht = AutoAxisUtilities.makecol(ht);
            if useX
                ax.addHandlesToCollection('belowX', ht);
            else
                ax.addHandlesToCollection('leftY', ht);
            end
            
            % list as generated content
            ax.addHandlesToCollection('generated', ht);
        end
        
        function updateAutoExponents(ax, varargin)
            import AutoAxis.PositionType;
            import AutoAxis.AnchorInfo;
            
            if isa(ax.axh, 'matlab.graphics.axis.Axes')
                ax.xExponent = double(ax.axh.XRuler.Exponent);
                ax.yExponent = double(ax.axh.YRuler.Exponent);
            else
                if strcmp(ax.axh.Orientation, 'vertical')
                    ax.xExponent = 0;
                    ax.yExponent = double(ax.axh.YRuler.Exponent);
                else
                    ax.xExponent = double(ax.axh.XRuler.Exponent);
                    ax.yExponent = 0;
                end
            end
                
            ax.removeHandles(ax.htXExponent);
            try
                delete(ax.htXExponent);
            catch
            end
            ax.removeHandles(ax.htYExponent);
            try
                delete(ax.htYExponent);
            catch
            end

            if ax.xExponent && ax.showXExponent
                exponentText = sprintf('\\times10^{%d}', ax.xExponent);
                htexp = text(0, 0, exponentText, 'HorizontalAlignment', 'left', ...
                    'VerticalAlignment', 'top', 'BackgroundColor', 'none', 'Margin', 0.01, ...
                    'Parent', ax.axhDraw, 'Interpreter', 'tex');
                ax.addHandlesToCollection('XExponent', htexp);
                ax.htXExponent = htexp;
                
                if strcmp(ax.axh.XAxisLocation, 'bottom')
                    ax.addAnchor(AnchorInfo(htexp, PositionType.Top, ax.axh, PositionType.Bottom, 'tickLabelOffset', 'xExponent to axis'));
                    ax.addAnchor(AnchorInfo(htexp, PositionType.Left, ax.axh, PositionType.Right, 'tickLabelOffset', 'xExponent to axis'));
                    ax.addHandlesToCollection('belowX', htexp);
                else
                    ax.addAnchor(AnchorInfo(htexp, PositionType.Bottom, ax.axh, PositionType.Top, 'tickLabelOffset', 'xExponent to axis'));
                    ax.addAnchor(AnchorInfo(htexp, PositionType.Left, ax.axh, PositionType.Right, 'tickLabelOffset', 'xExponent to axis'));
                    ax.addHandlesToCollection('aboveX', htexp);
                end
            end
            if ax.yExponent && ax.showYExponent
                exponentText = sprintf('\\times10^{%d}', ax.yExponent);
                htexp = text(0, 0, exponentText, 'HorizontalAlignment', 'left', ...
                    'VerticalAlignment', 'top', 'BackgroundColor', 'none', 'Margin', 0.01, ...
                    'Parent', ax.axhDraw, 'Interpreter', 'tex');
                ax.addHandlesToCollection('YExponent', htexp);
                ax.htYExponent = htexp;
                
                if strcmp(ax.axh.YAxisLocation, 'left')
                    ax.addAnchor(AnchorInfo(htexp, PositionType.Bottom, ax.axh, PositionType.Top, 'tickLabelOffset', 'yExponent to axis'));
                    ax.addAnchor(AnchorInfo(htexp, PositionType.Right, ax.axh, PositionType.Left, 'tickLabelOffset', 'yExponent to axis'));
                    ax.addHandlesToCollection('leftY', htexp);
                else
                    ax.addAnchor(AnchorInfo(htexp, PositionType.Bottom, ax.axh, PositionType.Top, 'tickLabelOffset', 'yExponent to axis'));
                    ax.addAnchor(AnchorInfo(htexp, PositionType.Left, ax.axh, PositionType.Right, 'tickLabelOffset', 'yExponent to axis'));
                    ax.addHandlesToCollection('rightY', htexp);
                end
            end
        end
        
        function [hlist] = addTickBridge(ax, varargin)
            % add line and text objects to the axis that replace the normal
            % axes
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @isstringlike);
            p.addParameter('span', [], @(x) isempty(x) || isvector(x));
            p.addParameter('tick', [], @isvector);
            p.addParameter('tickLabel', {}, @(x) isempty(x) || iscellstr(x) || isstring(x));
            p.addParameter('tickAlignment', [], @(x) isempty(x) || iscellstr(x) || isstring(x));
            p.addParameter('tickLabelOffset', 'tickLabelOffset', @(x) true);
            p.addParameter('tickFontSize', ax.tickFontSize, @isscalar);
            p.addParameter('tickMarks', ax.tickLength > 0, @islogical);
            p.addParameter('alignOuterLabelsInwards', false, @islogical);
            p.addParameter('tickRotation', NaN, @isscalar);
            p.addParameter('useAutoAxisCollections', false, @islogical);
            p.addParameter('useAutoBridgeCollections', false, @islogical);
            p.addParameter('addAnchors', true, @islogical);
            p.addParameter('otherSide', false, @islogical);
            p.addParameter('manualPositionOrthogonalAxis', NaN, @isscalar);
            p.addParameter('bridgeLabel', '', @(x) ischar(x) || isstring(x));
            p.addParameter('bridgeLabelColor', ax.tickColor, @(x) true);
            p.addParameter('bridgeLabelAnchorTicks', true, @islogical);
            p.addParameter('bridgeLabelFontSize', ax.labelFontSize, @isscalar);
            p.addParameter('bridgeLabelFontWeight', 'normal', @isstringlike);
            p.addParameter('bridgeLabelOffset', 'tickLabelOffset', @(x) true);
            p.addParameter('bridgeLabelOffsetLateral', 0, @(x) true);
            
            p.addParameter('extendToLimits', false, @islogical); % false = align edge of bridge with a tick; true = draw stem all the way across
            
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh; %#ok<*PROPLC,*PROP>
            useX = strcmp(p.Results.orientation, 'x');
            otherSide = p.Results.otherSide;
            tickLabelOffset = p.Results.tickLabelOffset;
            bridgeLabelOffset = p.Results.bridgeLabelOffset;
            bridgeLabelOffsetLateral = p.Results.bridgeLabelOffsetLateral;

            if ~isempty(p.Results.tick)
                ticks = p.Results.tick;
                labels = p.Results.tickLabel;
                
                if isempty(ticks)
                    if useX
                        ticks = get(axh, 'XLim');
                        labels = {''; ''};
                    else
                        ticks = get(axh, 'YLim');
                        labels = {''; ''};
                    end
                end
            else
                % briefly need to set font size back to automatically determine the ticks
                ax.updateAutoTicks();
                if useX
                    if strcmp(ax.axh.XTickMode, 'manual')
                        % use manual ticks
                        ticks = ax.axh.XTick;
                        labels = ax.axh.XTickLabels;
                    else
                        ticks = ax.xAutoTicks;
                        labels = ax.xAutoTickLabels;
                    end
                else
                    if strcmp(ax.axh.YTickMode, 'manual')
                        % use manual ticks
                        ticks = ax.axh.YTick;
                        labels = ax.axh.YTickLabels;
                    else
                        ticks = ax.yAutoTicks;
                        labels = ax.yAutoTickLabels;
                    end
                end
            end
              
            if useX
                exponent = ax.xExponent;
                if isempty(exponent)
                    exponent = double(ax.axh.XRuler.Exponent);
                end
            else
                exponent = ax.yExponent;
                if isempty(exponent)
                    exponent = double(ax.axh.YRuler.Exponent);
                end
            end
            
            if isempty(labels) || numel(labels) ~= numel(ticks)
                ticks(abs(ticks) < 10*eps) = 0;
                labels = sprintfc('%g', ticks / 10^exponent);
            end
            
            if useX
                ax.showXExponent = true;
            else
                ax.showYExponent = true;
            end
            
            if isempty(p.Results.tickAlignment)
                if useX
                    tickAlignment = repmat({'center'}, numel(ticks), 1);
                else
                    tickAlignment = repmat({'middle'}, numel(ticks), 1);
                end
            else
                tickAlignment = p.Results.tickAlignment;
            end
            
            if p.Results.alignOuterLabelsInwards
                if useX
                    tickAlignment{1} = 'left';
                    tickAlignment{end} = 'right';
                else
                    tickAlignment{1} = 'bottom'; % this is lower on the axis
                    tickAlignment{end} = 'top';
                end
            end
            
            [ticks, sortIdx] = sort(ticks);
            labels = labels(sortIdx);
            
%             tickLen = ax.tickLength;
            lineWidth = ax.tickLineWidth;
            tickRotation = p.Results.tickRotation;
            if isnan(tickRotation)
                if useX
                    tickRotation = get(axh, 'XTickLabelRotation');
                else
                    tickRotation = get(axh, 'YTickLabelRotation');
                end
            end
            if tickRotation > 0 && tickRotation < 90
                % anchor right side of label
                if useX
                    [tickAlignment{:}] = deal('right');
                else
                    [tickAlignment{:}] = deal('bottom');
                end
            elseif tickRotation < 0 && tickRotation < -90
                if useX
                    [tickAlignment{:}] = deal('left');
                else
                    [tickAlignment{:}] = deal('bottom');
                end
            end
            color = ax.tickColor;
            fontSize = p.Results.tickFontSize;
            
            % determine what the edge behavior of the bridge will look like
            extendToLimits = p.Results.extendToLimits;
            if isscalar(extendToLimits)
                % can independently control low, high separately
                extendToLimits = repmat(extendToLimits, 2, 1);
            end
            if useX 
                lims = ax.axh.XLim;
            else
                lims = ax.axh.YLim;
            end
            span = p.Results.span;
            if ~isempty(span)
                lims = span;
            end
            loTickAtLimit = ~isempty(ticks) && AutoAxisUtilities.isequaltol(ticks(1), lims(1));
            hiTickAtLimit = ~isempty(ticks) && AutoAxisUtilities.isequaltol(ticks(end), lims(2));
            
            if extendToLimits(1) || isempty(ticks)
                % we're extending the base of the bridge all the way to the axis limits
                mergeLoTick = loTickAtLimit;
            else
                mergeLoTick = true;
            end
            
            if extendToLimits(2) || isempty(ticks)
                mergeHiTick = hiTickAtLimit;
            else
                mergeHiTick = true;
            end
            
            if mergeLoTick
                loInd = 2;
                bridgeLo = ticks(1);
            else
                loInd = 1;
                bridgeLo = lims(1);
            end
            if mergeHiTick
                hiInd = numel(ticks)-1;
                bridgeHi = ticks(end);
            else
                hiInd = numel(ticks);
                bridgeHi = lims(2);
            end
            separateTicks = ticks(loInd:hiInd);
            bridgeIncludesAtLeastOneEdgeTick = mergeLoTick || mergeHiTick;
                
            % generate line, ignore length here, we'll anchor that later
            manPos = p.Results.manualPositionOrthogonalAxis;
            if ~isnan(manPos)
                useManPos = true;
                hiPos = manPos;
            else
                useManPos = false;
                hiPos = 0;
            end
            tickMarks = p.Results.tickMarks && ~isempty(ticks);
            
            xvals = [];
            yvals = [];
            if useX
                % get the ticks going in the right direction
                if xor(ax.yReverse, otherSide)
                    hi = hiPos;
                    lo = hiPos + 1;
                else
                    hi = hiPos;
                    lo = hiPos - 1;
                end
                
                % to get nice line caps on the edges, merge the edge ticks
                % with the bridge
                if tickMarks
                    if ~isempty(separateTicks)
                        xvals = [AutoAxisUtilities.makerow(separateTicks); AutoAxisUtilities.makerow(separateTicks)];
                        yvals = repmat([hi; lo], 1, numel(separateTicks));
                    end
                
                    xbridge = [bridgeLo; bridgeLo; bridgeHi; bridgeHi];
                    ybridge = [lo; hi; hi; lo];
                    
                    if ~mergeLoTick
                        xbridge(1) = [];
                        ybridge(1) = [];
                    end
                    if ~mergeHiTick
                        xbridge(end) = [];
                        ybridge(end) = [];
                    end 
                else
                    xbridge = [bridgeLo; bridgeHi];
                    ybridge = [hi; hi];
                end
                
                % y is anchored, x is fixed, see below for bridge label
                bridgeLabel_x = (bridgeLo+bridgeHi) / 2;
                bridgeLabel_y = lo;
                
                xtext = ticks;
                ytext = repmat(lo, size(ticks));
                ha = tickAlignment;
                if ~otherSide
                    va = repmat({'top'}, numel(ticks), 1);
                else
                    va = repmat({'bottom'}, numel(ticks), 1);
                end
                if ~otherSide
                    offset = 'axisPaddingBottom';
                else
                    offset = 'axisPaddingTop';
                end
            else
                % y axis ticks
                % get bridge pointed in the right direction
                if xor(ax.xReverse, otherSide)
                    lo = hiPos+1;
                    hi = hiPos;
                else
                    lo = hiPos-1;
                    hi = hiPos;
                end
                
                if tickMarks
                    if ~isempty(separateTicks)
                        yvals = [AutoAxisUtilities.makerow(separateTicks); AutoAxisUtilities.makerow(separateTicks)];
                        xvals = repmat([hi; lo], 1, numel(separateTicks));
                    end

                    xbridge = [lo; hi; hi; lo];
                    ybridge = [bridgeLo; bridgeLo; bridgeHi; bridgeHi];
                    
                    if ~mergeLoTick
                        xbridge(1) = [];
                        ybridge(1) = [];
                    end
                    if ~mergeHiTick
                        xbridge(end) = [];
                        ybridge(end) = [];
                    end 
                else
                    xbridge = [hi; hi];
                    ybridge = [bridgeLo; bridgeHi];
                end                
                % y is anchored, x is fixed, see below for bridge label
                bridgeLabel_y = (bridgeLo+bridgeHi) / 2;
                bridgeLabel_x = lo;
                
                xtext = repmat(lo, size(ticks));
                ytext = ticks;
                if ~otherSide
                    ha = repmat({'right'}, numel(ticks), 1);
                else
                    ha = repmat({'left'}, numel(ticks), 1);
                end
                va = tickAlignment;
                
                if ~otherSide
                    offset = 'axisPaddingLeft';
                else
                    offset = 'axisPaddingRight';
                end
            end
            
            % draw tick bridge
            if ~isempty(separateTicks) && tickMarks
                ht = line(xvals, yvals, 'LineWidth', lineWidth, 'Color', color, 'Parent', ax.axhDraw);
                set(ht, 'Clipping', 'off', 'YLimInclude', 'off', 'XLimInclude', 'off');
                AutoAxis.hideInLegend(ht);
            else
                ht = gobjects(0, 1);
            end
            
            hb = line(xbridge, ybridge, 'LineWidth', lineWidth, 'Color', color, 'Parent', ax.axhDraw);
            AutoAxis.hideInLegend(hb);
            set(hb, 'Clipping', 'off', 'YLimInclude', 'off', 'XLimInclude', 'off');
            
            % draw tick labels
            hl = AutoAxis.allocateHandleVector(numel(ticks));
            xtext = double(xtext);
            ytext = double(ytext);
            for i = 1:numel(ticks)
                hl(i) = text(xtext(i), ytext(i), labels{i}, ...
                    'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                    'Rotation', tickRotation, 'BackgroundColor', 'none', 'Margin', 0.01, ...
                    'Parent', ax.axhDraw, 'Interpreter', 'none');
            end
            set(hl, 'Clipping', 'off', 'Margin', 0.01, 'FontSize', fontSize, ...
                    'Color', color);
               
            % draw bridge label
            bridgeLabel = string(p.Results.bridgeLabel);
            bridgeLabel_x = double(bridgeLabel_x);
            bridgeLabel_y = double(bridgeLabel_y);
            if strlength(bridgeLabel) > 0
                hbl = text(bridgeLabel_x, bridgeLabel_y, bridgeLabel, 'HorizontalAlignment', 'Center', 'VerticalAlignment', 'Top', ...
                        'BackgroundColor', 'none', 'Margin', 0.01, 'FontSize', p.Results.bridgeLabelFontSize, ...
                        'FontWeight', p.Results.bridgeLabelFontWeight, ...
                        'Color', p.Results.bridgeLabelColor, ...
                        'Parent', ax.axhDraw, 'Interpreter', 'none');   
            else
                hbl = [];
            end
            
            if ax.debug
                set(hl, 'EdgeColor', 'r');
            end
            
            if p.Results.useAutoAxisCollections
                if useX
                    ax.addHandlesToCollection('autoAxisXBridge', hb);
                    if ~isempty(ht)
                        ax.addHandlesToCollection('autoAxisXTicks', ht);
                    end
                    ax.addHandlesToCollection('autoAxisXTickLabels', hl);
                    if ~isempty(hbl)
                        ax.addHandlesToCollection('autoAxisXBridgeLabel', hbl);
                    end
                    hbRef = 'autoAxisXBridge';
                    htRef = 'autoAxisXTicks';
                    hlRef = 'autoAxisXTickLabels';
                    hblRef = 'autoAxisXBridgeLabel';
                else
                    ax.addHandlesToCollection('autoAxisYBridge', hb);
                    if ~isempty(ht)
                        ax.addHandlesToCollection('autoAxisYTicks', ht);
                    end
                    ax.addHandlesToCollection('autoAxisYTickLabels', hl);
                    if ~isempty(hbl)
                        ax.addHandlesToCollection('autoAxisYBridgeLabel', hbl);
                    end
                    hbRef = 'autoAxisYBridge';
                    htRef = 'autoAxisYTicks';
                    hlRef = 'autoAxisYTickLabels';
                    hblRef = 'autoAxisYBridgeLabel';
                end
            elseif p.Results.useAutoBridgeCollections
                if useX
                    ax.addHandlesToCollection('autoBridgeXBridge', hb);
                    if ~isempty(ht)
                        ax.addHandlesToCollection('autoBridgeXTicks', ht);
                    end
                    ax.addHandlesToCollection('autoBridgeXTickLabels', hl);
                    if ~isempty(hbl)
                        ax.addHandlesToCollection('autoBridgeXBridgeLabel', hbl);
                    end
                    hbRef = 'autoBridgeXBridge';
                    htRef = 'autoBridgeXTicks';
                    hlRef = 'autoBridgeXTickLabels';
                    hblRef = 'autoBridgeXBridgeLabel';
                else
                    ax.addHandlesToCollection('autoBridgeYBridge', hb);
                    if ~isempty(ht)
                        ax.addHandlesToCollection('autoBridgeYTicks', ht);
                    end
                    ax.addHandlesToCollection('autoBridgeYTickLabels', hl);
                    if ~isempty(hbl)
                        ax.addHandlesToCollection('autoBridgeYBridgeLabel', hbl);
                    end
                    hbRef = 'autoBridgeYBridge';
                    htRef = 'autoBridgeYTicks';
                    hlRef = 'autoBridgeYTickLabels';
                    hblRef = 'autoBridgeYBridgeLabel';
                end
            else
                hbRef = hb;
                htRef = ht;
                hlRef = hl;
                hblRef = hbl;
            end
            
            % build anchor for bridges (to axis), 
            % anchor ticks to bridge
            % set lengths of ticks on bridge and ticks
            % anchor labels to bridges since
            % it's guaranteed to have at least 2 ticks, whereas ht might be
            % empty
            if p.Results.addAnchors
                if useX
                    if ~otherSide
                        % bottom of axis
                        if ~useManPos
                            ai = AnchorInfo(hbRef, PositionType.Top, ax.axh, ...
                                PositionType.Bottom, offset, 'xTickBridge below axis');
                            ax.addAnchor(ai);
                        end
                        
                        % anchor the height of the bridge which includes
                        % the outermost ticks
                        if bridgeIncludesAtLeastOneEdgeTick
                            ai = AnchorInfo(hbRef, PositionType.Height, ...
                                [], 'tickLength', 0, 'xTickBridge height for outermost ticks');
                            ax.addAnchor(ai);
                        end

                        if ~isempty(ht)
                            % anchor ticks
                            ai = AnchorInfo(htRef, PositionType.Height, ...
                                [], 'tickLength', 0, 'xTick length');
                            ax.addAnchor(ai);
                            ai = AnchorInfo(htRef, PositionType.Top, hbRef, ...
                                PositionType.Top, 0, 'xTick below xTickBridge');
                            ax.addAnchor(ai);
                        end
                        
                        % anchor labels to bridge
                        ai = AnchorInfo(hlRef, PositionType.Top, ...
                            hbRef, PositionType.Bottom, tickLabelOffset, ...
                            'xTickLabels below ticks');
                        ax.addAnchor(ai);
                        
                        % anchor bridge label to ticks / bridge
                        if ~isempty(hbl)
                            if p.Results.bridgeLabelAnchorTicks
                                ai = AnchorInfo(hblRef, PositionType.Top, ...
                                    hlRef, PositionType.Bottom, bridgeLabelOffset, ...
                                    'xBridgeLabel below tick labels');
                            else
                                ai = AnchorInfo(hblRef, PositionType.Top, ...
                                    hbRef, PositionType.Bottom, bridgeLabelOffset, ...
                                    'xBridgeLabel below bridge');
                            end
                            ax.addAnchor(ai);

                            if bridgeLabelOffsetLateral ~= 0
                                ax.anchorToDataLiteral(hblRef, PositionType.HCenter, bridgeLabel_x, offset=bridgeLabelOffsetLateral, ...
                                    desc="xBridgeLabel lateral offset");
                            end
                        end
                       
                    else
                        % top of axis
                        if ~useManPos
                            ai = AnchorInfo(hbRef, PositionType.Bottom, ax.axh, ...
                                PositionType.Top, offset, 'xTickBridge above axis');
                            ax.addAnchor(ai);
                        end
                        if bridgeIncludesAtLeastOneEdgeTick
                            ai = AnchorInfo(hbRef, PositionType.Height, ...
                                [], 'tickLength', 0, 'xTickBridge height for outermost ticks');
                            ax.addAnchor(ai);
                        end
                        
                        if ~isempty(ht)
                            % anchor ticks
                            ai = AnchorInfo(htRef, PositionType.Height, ...
                                [], 'tickLength', 0, 'xTick length');
                            ax.addAnchor(ai);
                            ai = AnchorInfo(htRef, PositionType.Bottom, hbRef, ...
                                PositionType.Bottom, 0, 'xTick above xTickBridge');
                            ax.addAnchor(ai);
                        end
                        
                        % anchor labels to bridge
                        ai = AnchorInfo(hlRef, PositionType.Bottom, ...
                            hbRef, PositionType.Top, tickLabelOffset, ...
                            'xTickLabels above ticks');
                        ax.addAnchor(ai);
                        
                        % anchor bridge label to ticks / bridge
                        if ~isempty(hbl)
                            if p.Results.bridgeLabelAnchorTicks
                                ai = AnchorInfo(hblRef, PositionType.Bottom, ...
                                    hlRef, PositionType.Above, bridgeLabelOffset, ...
                                    'xBridgeLabel above tick labels');
                            else
                                ai = AnchorInfo(hblRef, PositionType.Bottom, ...
                                    hbRef, PositionType.Above, bridgeLabelOffset, ...
                                    'xBridgeLabel above tick labels');
                            end
                            ax.addAnchor(ai);

                            if bridgeLabelOffsetLateral ~= 0
                                ax.anchorToDataLiteral(hblRef, PositionType.HCenter, bridgeLabel_x, offset=bridgeLabelOffsetLateral, ...
                                    desc="xBridgeLabel lateral offset");
                            end
                        end
                    end

                else
                    if ~otherSide
                        % left of axis
                        if ~useManPos
                            ai = AnchorInfo(hbRef, PositionType.Right, ...
                                ax.axh, PositionType.Left, offset, 'yTickBridge left of axis');
                            ax.addAnchor(ai);
                        end
                        if bridgeIncludesAtLeastOneEdgeTick
                            ai = AnchorInfo(hbRef, PositionType.Width, ...
                                [], 'tickLength', 0, 'yTickBridge width for outermost ticks');
                            ax.addAnchor(ai);
                        end
                        
                        if ~isempty(ht)
                            % anchor ticks
                            ai = AnchorInfo(htRef, PositionType.Width, ...
                                [], 'tickLength', 0, 'yTick length');
                            ax.addAnchor(ai);
                            ai = AnchorInfo(htRef, PositionType.Right, ...
                                hbRef, PositionType.Right, 0, 'yTick left of yTickBridge');
                            ax.addAnchor(ai);
                        end
                        
                        % anchor labels to bridge
                        ai = AnchorInfo(hlRef, PositionType.Right, ...
                            hbRef, PositionType.Left, tickLabelOffset, ...
                            'yTickLabels left of ticks');
                        ax.addAnchor(ai);
                        
                        % anchor bridge label to ticks / bridge
                        if ~isempty(hbl)
                            if p.Results.bridgeLabelAnchorTicks
                                ai = AnchorInfo(hblRef, PositionType.Right, ...
                                    hlRef, PositionType.Left, bridgeLabelOffset, ...
                                    'yBridgeLabel left of tick labels');
                            else
                                ai = AnchorInfo(hblRef, PositionType.Right, ...
                                    hbRef, PositionType.Left, bridgeLabelOffset, ...
                                    'yBridgeLabel left of bridge');
                            end
                            ax.addAnchor(ai);

                            if bridgeLabelOffsetLateral ~= 0
                                ax.anchorToDataLiteral(hblRef, PositionType.VCenter, bridgeLabel_y, offset=bridgeLabelOffsetLateral, ...
                                    desc="yBridgeLabel lateral offset");
                            end
                        end
                        
                    else
                        % right side
                        if ~useManPos
                            ai = AnchorInfo(hbRef, PositionType.Left, ...
                                ax.axh, PositionType.Right, offset, 'yTickBridge right of axis');
                            ax.addAnchor(ai);
                        end
                        if bridgeIncludesAtLeastOneEdgeTick
                            ai = AnchorInfo(hbRef, PositionType.Width, ...
                                [], 'tickLength', 0, 'yTickBridge width for outermost ticks');
                            ax.addAnchor(ai);
                        end
                        
                        if ~isempty(ht)
                            % anchor ticks
                            ai = AnchorInfo(htRef, PositionType.Width, ...
                                [], 'tickLength', 0, 'yTick length');
                            ax.addAnchor(ai);
                            ai = AnchorInfo(htRef, PositionType.Left, ...
                                hbRef, PositionType.Left, 0, 'yTick right of yTickBridge');
                            ax.addAnchor(ai);
                        end
                        
                        % anchor labels to bridge
                        ai = AnchorInfo(hlRef, PositionType.Left, ...
                            hbRef, PositionType.Right, 'tickLabelOffset', ...
                            'yTickLabels right of ticks');
                        ax.addAnchor(ai);

                        % anchor bridge label to ticks / bridge
                        if ~isempty(hbl)
                            if p.Results.bridgeLabelAnchorTicks
                                ai = AnchorInfo(hblRef, PositionType.Left, ...
                                    hlRef, PositionType.Right, bridgeLabelOffset, ...
                                    'yBridgeLabel right of tick labels');
                            else
                                ai = AnchorInfo(hblRef, PositionType.Left, ...
                                    hbRef, PositionType.Right, bridgeLabelOffset, ...
                                    'yBridgeLabel right of bridge');
                            end
                            ax.addAnchor(ai);

                            if bridgeLabelOffsetLateral ~= 0
                                ax.anchorToDataLiteral(hblRef, PositionType.VCenter, bridgeLabel_y, offset=bridgeLabelOffsetLateral, ...
                                    desc="yBridgeLabel lateral offset");
                            end
                        end
                    end
                end
            end
            
            % add handles to handle collections
            hlist = cat(1, AutoAxisUtilities.makecol(ht), AutoAxisUtilities.makecol(hl), hb, hbl);
            if useX
                if ~otherSide
                    ax.addHandlesToCollection('belowX', hlist);
                else
                    ax.addHandlesToCollection('aboveX', hlist);
                end
            else
                if ~otherSide
                    ax.addHandlesToCollection('leftY', hlist);
                else
                    ax.addHandlesToCollection('rightY', hlist);
                end
            end
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
        end   
        
        function [hm, ht] = addMarkerX(ax, varargin)
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('x', @isscalar);
            p.addOptional('label', '', @(x) ischar(x) || iscellstr(x) || isstring(x));
            p.addParameter('labelColor', ax.tickFontColor, @(x) isvector(x) || isempty(x) || ischar(x));
            %p.addParameter('marker', 'o', @(x) isempty(x) || ischar(x));
            p.addParameter('markerColor', [0.1 0.1 0.1], @(x) isvector(x) || ischar(x) || isempty(x));
            p.addParameter('alpha', 1, @isscalar);
            p.addParameter('interval', [], @(x) isempty(x) || isvector(x)); % add a rectangle interval behind the marker to indicate a range of locations
            p.addParameter('intervalColor', [0.5 0.5 0.5], @(x) isvector(x) || ischar(x) || isempty(x));
            
            p.addParameter('distribution', [], @(x) isempty(x) || isvector(x)); % like interval but alpha value varies with distribution
            p.addParameter('normalizeDistribution', true, @islogical); % if false, distribution must already be scaled to [0 1]
            p.addParameter('distributionBins', [], @(x) isempty(x) || isvector(x)); % left edges of the bins
            p.addParameter('distributionColor', [0.5 0.5 0.5], @(x) isvector(x) || ischar(x) || isempty(x));
            
            p.addParameter('textOffsetY', 0, @isscalar);
            p.addParameter('textOffsetX', 0, @isscalar);
            p.addParameter('horizontalAlignment', 'center', @isstringlike);
            p.addParameter('verticalAlignment', 'top', @isstringlike);
            p.addParameter('addSpaceForScaleBar', true, @islogical);
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            label = char(p.Results.label);
            
            yl = get(ax.axh, 'YLim');
            
            holdState = ishold(ax.axhDraw);
            hold(ax.axhDraw, 'on');

            % add the interval rectangle if necessary, so that it sits
            % beneath the marker
            hr = [];
            hasInterval = false;
            if ~isempty(p.Results.interval)
                interval = p.Results.interval;
                assert(numel(interval) == 2, 'Interval must be a vector with length 2');
                
                if interval(2) - interval(1) > 0
                    hasInterval = true;
                    % set the height later
                    hr = rectangle('Position', [interval(1), yl(1), interval(2)-interval(1), 1], ...
                        'EdgeColor', 'none', 'FaceColor', p.Results.intervalColor, ...
                        'YLimInclude', 'off', 'XLimInclude', 'off', 'Clipping', 'off', 'Parent', ax.axhDraw);
                    AutoAxis.hideInLegend(hr);
                end
            end
            
            % add the distribution image
            hdist = [];
            hasDistribution = false;
            if ~isempty(p.Results.distribution)
                dist = p.Results.distribution;
                if p.Results.normalizeDistribution
                    dist = dist - min(dist(:));
                    dist = dist ./ max(dist(:));
                end
                bins = p.Results.distributionBins;
             
                if ~isempty(dist)
                    assert(numel(dist) == numel(bins));
                    
                    inds = find(dist > 0, 1, 'first') : find(dist > 0, 1, 'last');
                    bins = bins(inds);
                    dist = dist(inds);
                    
                    if numel(inds) > 1
                        hasDistribution = true;

                        % 1 x bins x 3
                        imdata = shiftdim(repmat(TrialDataUtilities.Color.toRGB(p.Results.distributionColor), numel(bins), 1), -1);
                        alphadata = makerow(dist);

                        % set the height later
                        hdist = image('XData', bins, 'YData', [yl(1); yl(1)+1], 'CData', imdata, ...
                            'AlphaData', alphadata, ...
                            'YLimInclude', 'off', 'XLimInclude', 'off', 'Clipping', 'off', 'Parent', ax.axhDraw);
                        AutoAxis.hideInLegend(hdist);
                    end
                end
            end
            
            % plot marker
%             holdState = ishold(ax.axhDraw);
%             hold(ax.axhDraw, 'on');
%             hm = plot(ax.axhDraw, p.Results.x, yl(1), 'Marker', p.Results.marker, ...
%                 'MarkerSize', 1, 'MarkerFaceColor', p.Results.markerColor, ...
%                 'MarkerEdgeColor', 'none', 'YLimInclude', 'off', 'XLimInclude', 'off', ...
%                 'Clipping', 'off');   
            
            hm = rectangle('Position', [p.Results.x - ax.markerWidth/2, yl(1), ax.markerWidth, ax.markerHeight], 'Curvature', ax.markerCurvature, ...
                'EdgeColor', 'none', 'FaceColor', p.Results.markerColor, ...
                'YLimInclude', 'off', 'XLimInclude', 'off', 'Clipping', 'off', 'Parent', ax.axhDraw);
            hm.FaceColor(4) = p.Results.alpha;
            AutoAxis.hideInLegend(hm);
                       
            % marker label
            ht = text(p.Results.x, yl(1), p.Results.label, ...
                'FontSize', ax.tickFontSize, 'Color', p.Results.labelColor, ...
                'HorizontalAlignment', p.Results.horizontalAlignment, ...
                'VerticalAlignment', p.Results.verticalAlignment, ...
                'Parent', ax.axhDraw, 'Interpreter', 'none', 'BackgroundColor', 'none');
            set(ht, 'Clipping', 'off', 'Margin', 0.1);
            
            % anchor marker height
            if iscell(label), label = strjoin(label, ' '); end
            ai = AutoAxis.AnchorInfo(hm, PositionType.Height, ...
                [], 'markerHeight', 0, sprintf('markerX label ''%s'' height', label));
            ax.addAnchor(ai);
            
%             % anchor marker width
            ai = AutoAxis.AnchorInfo(hm, PositionType.Width, ...
                [], 'markerWidth', 0, sprintf('markerX label ''%s'' width', label));
            ax.addAnchor(ai);
            
            % anchor marker to axis
            if p.Results.addSpaceForScaleBar
                offsetBottom = @(ax, varargin) ax.axisPaddingBottom + ax.scaleBarThickness;
            else
                offsetBottom = 'axisPaddingBottom';
            end
            ai = AutoAxis.AnchorInfo(hm, PositionType.Top, ...
                ax.axh, PositionType.Bottom, offsetBottom, ...
                sprintf('markerX ''%s'' to bottom of axis', label));
            ax.addAnchor(ai); 
            
            % anchor label to bottom of axis factoring in marker size,
            % this makes it consistent with how addIntervalX's label is
            % anchored
            offY = p.Results.textOffsetY;
            pos = PositionType.verticalAlignmentToPositionType(p.Results.verticalAlignment);  
            if p.Results.addSpaceForScaleBar
                offsetBottom = @(ax, varargin) ax.axisPaddingBottom + ax.scaleBarThickness + ax.markerHeight + ax.markerLabelOffset + offY;
            else
                offsetBottom = @(ax, varargin) ax.axisPaddingBottom + ax.markerHeight + ax.markerLabelOffset + offY;
            end
            ai = AutoAxis.AnchorInfo(ht, pos, ...
                ax.axh, PositionType.Bottom, offsetBottom, ...
                sprintf('markerX label ''%s'' to bottom of axis', label));
            ax.addAnchor(ai);
            
            % add lateral offset to label
            if p.Results.textOffsetX ~= 0
                pos = PositionType.horizontalAlignmentToPositionType(p.Results.horizontalAlignment);
                ai = AutoAxis.AnchorInfo(ht, pos, ...
                    p.Results.x, PositionType.Literal, p.Results.textOffsetX, ...
                    sprintf('markerX label ''%s'' offset %g from X=%g', ...
                    label, p.Results.textOffsetX, p.Results.x));
                ax.addAnchor(ai);
            end
                   
            % anchor error rectangle height and vcenter
            if hasInterval
                ai = AutoAxis.AnchorInfo(hr, PositionType.Height, ...
                    [], @(ax, info) ax.markerHeight/3, 0, 'markerX interval rect height');
                ax.addAnchor(ai);
                ai = AutoAxis.AnchorInfo(hr, PositionType.VCenter, ...
                    hm, PositionType.VCenter, 0, 'markerX interval rect to marker');
                ax.addAnchor(ai);
            end
            if hasDistribution
                ai = AutoAxis.AnchorInfo(hdist, PositionType.Height, ...
                    [], @(ax, info) ax.markerHeight/3, 0, 'markerX distribution rect height');
                ax.addAnchor(ai);
                ai = AutoAxis.AnchorInfo(hdist, PositionType.VCenter, ...
                    hm, PositionType.VCenter, 0, 'markerX distribution rect to marker');
                ax.addAnchor(ai);
            end
                        
            % add to belowX handle collection to update the dependent
            % anchors
            hlist = [hm; hr; hdist; ht]; % order here matters, place error interval below marker
            ax.addHandlesToCollection('belowX', hlist);
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
            
            % put in top layer
            ax.addHandlesToCollection('markers', hlist);
            
            if ~holdState
                hold(ax.axhDraw, 'off');
            end
        end
        
        % 
        function hstrip = addColorStrip(ax, orientation, varargin)
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @isstringlike);
            p.addParameter('position', @isvector);
            p.addParameter('colors', [], @ismatrix); % specify the raw colors at each value
            p.addParameter('color', [], @isvector); % specify a single color to use alpha as the value indicator
            p.addParameter('colormap', []);
            p.addParameter('colormap_limits', []);
            p.addParameter('values', []);
            p.addParameter('normalizeValues', true, @islogical);
            p.addParameter('alpha', 1);
            p.addParameter('indicator', [], @(x) isvector(x) && islogical(x));
            p.addParameter('exactIndicatorEdges', true, @islogical);
            p.addParameter('uniformSpacing', [], @(x) isempty(x) || islogical(x));
            p.addParameter('otherSide', false, @islogical);
            p.addParameter('offset', NaN);
            p.addParameter('height', ax.scaleBarThickness, @isscalar);

            p.parse(orientation, varargin{:});

            axis_pos = makecol(p.Results.position);
            alpha = p.Results.alpha;
            if isscalar(alpha)
                alpha = repmat(alpha, numel(axis_pos), 1);
            end

            if isempty(p.Results.uniformSpacing)
                dts = uniquetol(diff(axis_pos), mean(diff(axis_pos)) / 1000);
                if numel(dts) > 1
                    uniformSpacing = false; % we need to use patch instead of image
                else
                    uniformSpacing = true; % image okay
                end
            else
                uniformSpacing = p.Results.uniformSpacing;
            end

            otherSide = p.Results.otherSide;
            pos_computed = false;

            % determine what the color values will be
            if ~isempty(p.Results.colors)
                colors = p.Results.colors;
            elseif ~isempty(p.Results.values)
                values = p.Results.values;
                if p.Results.normalizeValues
                    values = (values - min(values(:))) / (max(values(:)) - min(values(:)));
                end
                if ~isempty(p.Results.color)
                    % value sets alpha
                    colors = repmat(p.Results.color, numle(axis_pos), 1);
                    alpha = values;
                else
                    % value selects in colormap
                    if isempty(p.Results.colormap)
                        colormap =  TrialDataUtilities.Colormaps.rocket();
                    else
                        colormap = p.REsults.colormap;
                    end
                    colormap_limits = p.Results.colormap_limits;
                    
                    colors = TrialDataUtilities.Color.evalColorMapAt(colormap, values, colormap_limits);
                end
            elseif ~isempty(p.Results.indicator)
                indicator = p.Results.indicator;

                if p.Results.exactIndicatorEdges
                    % we adjust the pixel boundaries of the indicator to match the on and off times precisely
                    % and then subsample indicator to draw the minimum number of patches
                    uniformSpacing = false;
                
                    
                    if indicator(1)
                        on_idx = [1 find(diff(indicator) == 1)+1];
                    else
                        on_idx = find(diff(indicator) == 1)+1;
                    end
                    if indicator(end)
                        off_idx = [find(diff(indicator) == -1) numel(indicator)];
                    else
                        off_idx = find(diff(indicator) == -1);
                    end

                    on_pos = axis_pos(on_idx);
                    off_pos = axis_pos(off_idx);

                    % single timepoint high? go until halfway to next sample
                    single_high = on_idx == off_idx;
                    dts = diff(axis_pos);
                    half_steps = [dts/2; dts(end)/2];
                    next_half_step = axis_pos(on_idx) + half_steps(on_idx);
                    off_pos(single_high) = next_half_step(single_high);

                    % used below
                    pos_mat = [on_pos'; off_pos'];
                    pos = pos_mat(:);

                    pos_computed = true;
                    indicator = false(numel(pos)-1, 1);
                    indicator(1:2:end) = true;
                end
                   
                if ~isempty(p.Results.color)
                    colors = repmat(p.Results.color, numel(indicator), 1);
                elseif ~isempty(p.Results.colormap)
                    colormap = p.Results.colormap;
                    if size(colormap, 1) == numel(indicator)
                        colors = colormap;
                    else
                        colors = repmat(colormap(1, :), numel(indicator), 1);
                    end
                else
                    error('Specify color or colormap with indicator');
                end

                alpha = zeros(size(indicator));
                alpha(~indicator) = 0;
                alpha(indicator) = p.Results.alpha(1);

            else
                error('Specify colors, values + (color or colormap), or indicator + (color or colormap)');
            end
            
            if pos_computed
                assert(size(colors, 2) == 3 && size(colors, 1) == numel(pos)-1, 'Values / colors must match numel(axis_pos)');
                assert(numel(alpha) == numel(pos)-1, 'alpha must be scalar or have numel(axis_pos) values');
            else
                assert(size(colors, 2) == 3 && size(colors, 1) == numel(axis_pos), 'Values / colors must match numel(axis_pos)');
                assert(numel(alpha) == numel(axis_pos), 'alpha must be scalar or have numel(axis_pos) values');
            end
            
            useX = strcmp(orientation, "x");

            if useX
                % nVals x 3 --> 1 x nVals x 3
                imdata = shiftdim(colors, -1);
            else
                % nVals x 3 --> nVals x 1 x 3
                imdata = permute(colors, [1 3 2]);
            end
            
            washolding = ishold(ax.axhDraw);

            hold(ax.axhDraw, 'on');
            if uniformSpacing
                % spacing is uniform along axis_pos, so we use image()
                
                if useX
                    yl = ylim(ax.axh);
                    hstrip = image(axis_pos([1 end]), [yl(1) yl(1) + 1], imdata, ...
                        'AlphaData', makerow(alpha), ...
                        'YLimInclude', 'off', 'XLimInclude', 'off', 'Clipping', 'off', 'Parent', ax.axhDraw);
                else
                    xl = xlim(ax.axh);
                    hstrip = image([xl(1) xl(1) + 1], axis_pos([1 end]), imdata, ...
                        'AlphaData', makecol(alpha), ...
                        'YLimInclude', 'off', 'XLimInclude', 'off', 'Clipping', 'off', 'Parent', ax.axhDraw);
                end
            else
                % use patch. need left and right edges for each value
                dt = diff(axis_pos);
                if ~pos_computed
                    pos = [axis_pos-[dt(1)/2; dt/2]; axis_pos(end)+dt(end)/2]; % nVals + 1
                end

                if useX
                    yl = ylim(ax.axh);
                    X = [pos(1:end-1) pos(2:end) pos(2:end) pos(1:end-1)]';
                    Y = repmat([yl(1) yl(1) yl(1)+1 yl(1)+1], numel(pos)-1, 1)';
                else
                    xl = ylim(ax.axh);
                    X = repmat([xl(1) xl(1) xl(1)+1 xl(1)+1], numel(pos)-1, 1)';
                    Y = [pos(1:end-1) pos(2:end) pos(2:end) pos(1:end-1)]';
                end
                hstrip = patch(XData=X, YData=Y, FaceColor='flat', FaceVertexCData=colors, EdgeColor="none", ...
                    FaceAlpha='flat', AlphaDataMapping='none', FaceVertexAlphaData=alpha, ...
                    YLimInclude='off', XLimInclude='off', Clipping='off', Parent=ax.axhDraw);
            end
            AutoAxis.hideInLegend(hstrip);

            % anchor height (or width) of strip
            offset = p.Results.offset;
            if useX
                ai = AutoAxis.AnchorInfo(hstrip, PositionType.Height, ...
                    [], @(ax, info) ax.markerHeight/3, 0, 'colorStrip height');
                ax.addAnchor(ai);
                if otherSide
                    if isnan(offset)
                        offset = 'axisPaddingBottom';
                    end
                    ai = AutoAxis.AnchorInfo(hstrip, PositionType.Bottom, ...
                        ax.axh, PositionType.Top, offset, 'colorStrip below axis');
                else
                    if isnan(offset)
                        offset = 'axisPaddingTop';
                    end
                    ai = AutoAxis.AnchorInfo(hstrip, PositionType.Top, ...
                        ax.axh, PositionType.Bottom, offset, 'colorStrip above axis');
                end
                ax.addAnchor(ai);
            else
                ai = AutoAxis.AnchorInfo(hstrip, PositionType.Width, ...
                    [], @(ax, info) ax.markerHeight/3, 0, 'markerX distribution rect width');
                ax.addAnchor(ai);
                if otherSide
                    if isnan(offset)
                        offset = 'axisPaddingRight';
                    end
                    ai = AutoAxis.AnchorInfo(hstrip, PositionType.Left, ...
                        ax.axh, PositionType.Right, offset, 'colorStrip right of axis');
                else
                    if isnan(offset)
                        offset = 'axisPaddingLeft';
                    end
                    ai = AutoAxis.AnchorInfo(hstrip, PositionType.Right, ...
                        ax.axh, PositionType.Left, offset, 'colorStrip left of axis');
                end
                ax.addAnchor(ai);
            end

            if ~washolding
                hold(ax.axhDraw, 'off');
            end
        end
        
        function hlist = addScaleBar(ax, varargin)
            % add rectangular scale bar with text label to either the x or
            % y axis, at the lower right corner
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @ischar);
            p.addParameter('length', [], @(x) isscalar(x) || isempty(x));
            p.addParameter('units', '', @(x) isempty(x) || isstringlike(x));
            p.addParameter('scaleFactor', 1, @isscalar); % 1 unit of axis x/y is scaleFactor units on scale bar
            p.addParameter('hideLabel', false, @islogical);
            p.addParameter('manualLabel', '', @(x) isempty(x) || ischar(x));
            p.addParameter('useAutoScaleBarCollections', false, @islogical);
            p.addParameter('addAnchors', true, @islogical); % if false, no anchors are added
            p.addParameter('addPositionAnchors', true, @islogical); % if false, the position of the rectangle and label will not be anchored, only to each other and the scalebar thickness
            p.addParameter('color', ax.scaleBarColor, @(x) ischar(x) || isvector(x));
            p.addParameter('textAlign', '', @isstringlike);
            p.addParameter('fontColor', ax.scaleBarFontColor, @(x) ischar(x) || isvector(x));
            p.addParameter('fontSize', ax.scaleBarFontSize, @(x) isscalar(x));
            p.addParameter('manualPositionAlongAxis', [], @(x) isempty(x) || isscalar(x)); % position of right edge of scale bar
            p.addParameter('offsetOrthogonal', []); % defaults to axisPadding 
            p.addParameter('offsetParallel', []); % default respects alignWithOtherScaleBar
            p.addParameter('alignWithOtherScaleBar', true, @islogical);
            
            p.addParameter('scaleBarLabelLateralOffset', 0, @isscalar); 
            
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh; %#ok<*PROP>
            useX = strcmp(p.Results.orientation, 'x');
            if ~isempty(p.Results.length)
                len = p.Results.length ./ p.Results.scaleFactor;
            else
                if isempty(ax.xAutoTicks)
                    ax.updateAutoTicks();
                end
                if (ax.keepAutoScaleBarsEqual || axh.DataAspectRatio(1) == axh.DataAspectRatio(2)) && p.Results.useAutoScaleBarCollections
                    xticks = ax.xAutoTicks;
                    yticks = ax.yAutoTicks;
                    len = min([xticks(end) - xticks(end-1), yticks(end) - yticks(end-1)]);
                else
                    if useX
                        ticks = ax.xAutoTicks;
                    else
                        ticks = ax.yAutoTicks;
                    end
                    if isempty(ticks)
                        xl = get(ax.axh, 'XLim');
                        len = floor(diff(xl)/5);
                    else
                        len = ticks(end) - ticks(end-1);
                    end
                end
            end
            
            units = p.Results.units;
            if isempty(units)
                if useX
                    units = ax.xUnits;
                else
                    units = ax.yUnits;
                end
            end
            if ~p.Results.hideLabel
                if ismember('manualLabel', p.UsingDefaults) % allow '' to be specified too
                    scaled_len = len .* p.Results.scaleFactor;
                    if isempty(units)
                        label = sprintf('%g', scaled_len);
                    else
                        label = sprintf('%g %s', scaled_len, units);
                    end
                else
                    label = p.Results.manualLabel;
                end
            else
                label = '';
            end
            
            color = p.Results.color;
            fontColor = p.Results.fontColor;
            fontSize = p.Results.fontSize;
            textAlign = string(p.Results.textAlign);
            if textAlign == ""
                if useX
                    textAlign = "right";
                else
                    textAlign = "bottom";
                end
            end
            
            % the two scale bars thicknesses must not be customized because
            % the placement of y depends on thickness of x and vice versa
            xl = get(axh, 'XLim');
            yl = get(axh, 'YLim');
            if useX
                if isempty(p.Results.manualPositionAlongAxis)
                    xpos = xl(2);
                else
                    xpos = p.Results.manualPositionAlongAxis;
                end
                hr = rectangle('Position', [xpos - len, yl(1), len, ax.scaleBarThickness], ...
                    'Parent', ax.axhDraw);
                AutoAxis.hideInLegend(hr);
                if ~isempty(label)
                    if textAlign == "left"
                        horzAlign = 'right';
                    elseif textAlign == "center"
                        horzAlign = 'center';
                    elseif textAlign == "right"
                        horzAlign = 'left';
                    else
                        error('Unknown textAlign');
                    end
                    ht = text(double(xpos), double(yl(1)), label, 'HorizontalAlignment', horzAlign, ...
                        'VerticalAlignment', 'top', 'Parent', ax.axhDraw, 'BackgroundColor', 'none', 'Margin', 0.01);
                    
                else
                    ht = [];
                end
            else
                if isempty(p.Results.manualPositionAlongAxis)
                    ypos = yl(1);
                else
                    ypos = p.Results.manualPositionAlongAxis;
                end
                hr = rectangle('Position', [xl(2) - ax.scaleBarThickness, ypos, ...
                    ax.scaleBarThickness, len], ...
                    'Parent', ax.axhDraw);
                AutoAxis.hideInLegend(hr);
                if ~isempty(label)
                    if textAlign == "bottom"
                        horzAlign = 'left';
                    elseif textAlign == "center" || textAlign == "middle"
                        horzAlign = 'center';
                    elseif textAlign == "top"
                        horzAlign = 'right';
                    else
                        error('Unknown textAlign');
                    end
                        
                    ht = text(double(xl(2)), double(ypos), label, 'HorizontalAlignment', horzAlign, ...
                        'VerticalAlignment', 'bottom', 'Parent', ax.axhDraw, ...
                        'Rotation', -90, 'BackgroundColor', 'none', 'Margin', 0.01);
                else
                    ht = [];
                end
            end
            
            set(hr, 'FaceColor', color, 'EdgeColor', 'none', 'Clipping', 'off', ...
                'XLimInclude', 'off', 'YLimInclude', 'off');
            if ~isempty(ht)
                set(ht, 'FontSize', fontSize, 'Margin', 0.1, 'Color', fontColor, 'Clipping', 'off');
            end
            
            if ax.debug && ~isempty(ht)
                set(ht, 'EdgeColor', 'r');
            end
            
            if p.Results.useAutoScaleBarCollections
                if useX
                    ax.addHandlesToCollection('autoScaleBarXRect', hr);
                    hrRef = 'autoScaleBarXRect';
                    if ~isempty(ht)
                        ax.addHandlesToCollection('autoScaleBarXText', ht);
                        htRef = 'autoScaleBarXText';
                    end
                    
                    anchor_collection = "autoScaleBarX";
                else
                    ax.addHandlesToCollection('autoScaleBarYRect', hr);
                    hrRef = 'autoScaleBarYRect';
                    
                    if ~isempty(ht)
                        ax.addHandlesToCollection('autoScaleBarYText', ht);
                        htRef = 'autoScaleBarYText';
                    end
                    
                    anchor_collection = "autoScaleBarY";
                end
            else 
                hrRef = hr;
                htRef = ht;
                anchor_collection = "";
            end
            
            % build anchor for rectangle and label
            if p.Results.addAnchors
                addPosAnchors = p.Results.addPositionAnchors;
                % remove old anchors in this collection
                ax.deleteAnchorCollection(anchor_collection);
                offsetOrthogonal = p.Results.offsetOrthogonal;
                offsetParallel = p.Results.offsetParallel;
                
                if useX
                    % for x scale bar
                    ai = AnchorInfo(hrRef, PositionType.Height, [], 'scaleBarThickness', ...
                        0, 'xScaleBar thickness');
                    ax.addAnchor(ai, 'collection', anchor_collection);
                    if addPosAnchors
                        if isempty(offsetOrthogonal)
                            offsetOrthogonal = 'axisPaddingBottom';
                        end
                        ai = AnchorInfo(hrRef, PositionType.Top, ax.axh, ...
                            PositionType.Bottom, offsetOrthogonal, ...
                            'xScaleBar at bottom of axis');
                        ax.addAnchor(ai, 'collection', anchor_collection);
                        if isempty(p.Results.manualPositionAlongAxis)
                            if p.Results.alignWithOtherScaleBar
                                if isempty(offsetParallel)
                                    offsetParallel = {'axisPaddingRight', 'scaleBarThickness'};
                                end
                                ai = AnchorInfo(hrRef, PositionType.Right, ax.axh, ...
                                    PositionType.Right, offsetParallel, ...
                                    'xScaleBar flush with right edge of yScaleBar at right of axis');
                            else
                                if isempty(offsetParallel)
                                    offsetParallel = 0;
                                end
                                ai = AnchorInfo(hrRef, PositionType.Right, ax.axh, ...
                                    PositionType.Right, offsetParallel, ...
                                    'xScaleBar flush with right edge of axis');
                            end
                            ax.addAnchor(ai, 'collection', anchor_collection);
                        end
                    end

                    if ~isempty(ht)
                        ai = AnchorInfo(htRef, PositionType.Top, hrRef, PositionType.Bottom, 'scaleBarLabelOffset', ...
                            'xScaleBarLabel below xScaleBar');
                        ax.addAnchor(ai);
                        if textAlign == "left"
                            ai = AnchorInfo(htRef, PositionType.Left, hrRef, PositionType.Left, p.Results.scaleBarLabelLateralOffset, ...
                                'xScaleBarLabel flush with left edge of xScaleBar');
                        elseif textAlign == "center"
                            ai = AnchorInfo(htRef, PositionType.HCenter, hrRef, PositionType.HCenter, p.Results.scaleBarLabelLateralOffset, ...
                                'xScaleBarLabel at center of xScaleBar');
                        elseif textAlign == "right"
                            ai = AnchorInfo(htRef, PositionType.Right, hrRef, PositionType.Right, p.Results.scaleBarLabelLateralOffset, ...
                                'xScaleBarLabel flush with right edge of xScaleBar');
                        end
                        ax.addAnchor(ai, 'collection', anchor_collection);
                    end
                else
                    % for y scale bar
                    ai = AnchorInfo(hrRef, PositionType.Width, [], 'scaleBarThickness', 0, ...
                        'yScaleBar thickness');
                    ax.addAnchor(ai, 'collection', anchor_collection);
                    if addPosAnchors
                        if isempty(offsetOrthogonal)
                            offsetOrthogonal = 'axisPaddingRight';
                        end
                        ai = AnchorInfo(hrRef, PositionType.Left, ax.axh, ...
                            PositionType.Right, offsetOrthogonal, ...
                            'yScaleBar at right of axis');
                        ax.addAnchor(ai, 'collection', anchor_collection);
                        if isempty(p.Results.manualPositionAlongAxis)
                            if p.Results.alignWithOtherScaleBar
                                if isempty(offsetParallel)
                                    offsetParallel = {'axisPaddingBottom', 'scaleBarThickness'};
                                end
                                ai = AnchorInfo(hrRef, PositionType.Bottom, ax.axh, ...
                                    PositionType.Bottom, offsetParallel, ...
                                    'yScaleBar flush with bottom of xScaleBar at bottom of axis');
                            else
                                if isempty(offsetParallel)
                                    offsetParallel = 0;
                                end
                                ai = AnchorInfo(hrRef, PositionType.Bottom, ax.axh, ...
                                    PositionType.Bottom, offsetParallel, ...
                                    'yScaleBar flush with bottom edge of axis');
                            end
                            ax.addAnchor(ai, 'collection', anchor_collection);
                        end
                    end
                    if ~isempty(ht)
                        ai = AnchorInfo(htRef, PositionType.Left, hrRef, PositionType.Right, 'scaleBarLabelOffset', ...
                            'yScaleBarLabel right of yScaleBar');
                        ax.addAnchor(ai, 'collection', anchor_collection);
                        if textAlign == "top"
                            ai = AnchorInfo(htRef, PositionType.Top, hrRef, PositionType.Top, p.Results.scaleBarLabelLateralOffset, ...
                                'yScaleBarLabel flush with top edge of yScaleBar');
                        elseif textAlign == "center"
                            ai = AnchorInfo(htRef, PositionType.VCenter, hrRef, PositionType.VCenter, p.Results.scaleBarLabelLateralOffset, ...
                                'yScaleBarLabel at center of yScaleBar');
                        elseif textAlign == "bottom"
                            ai = AnchorInfo(htRef, PositionType.Bottom, hrRef, PositionType.Bottom, p.Results.scaleBarLabelLateralOffset, ...
                                'yScaleBarLabel flush with bottom edge of xScaleBar');
                        end
                        ax.addAnchor(ai, 'collection', anchor_collection);
                    end
                end
            end
           
            % add handles to handle collections
            hlist = [hr; ht];
            if useX
                ax.addHandlesToCollection('belowX', hlist);
            else
                ax.addHandlesToCollection('hRightY', hlist);
            end
            
            % for uistacking
            ax.addHandlesToCollection('scaleBars', hlist);
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
        end
        
        function hlist = addScaleBarY(ax, varargin)
            hlist = ax.addScaleBar('y', varargin{:});
        end
        
        function hlist = addScaleBarX(ax, varargin)
            hlist = ax.addScaleBar('x', varargin{:});
        end
        
        function [hr, ht] = addIntervalX(ax, varargin)
            % add rectangular bar with text label to either the x or
            % y axis, at the lower right corner
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('interval', @(x) isvector(x) && numel(x) == 2);
            p.addOptional('label', '', @isstringlike);
            p.addParameter('labelColor', ax.tickFontColor, @(x) isvector(x) || isempty(x) || ischar(x));
            p.addParameter('color', [0.1 0.1 0.1], @(x) isvector(x) || ischar(x) || isempty(x));    
            p.addParameter('errorInterval', [], @(x) isempty(x) || (isvector(x) && numel(x) == 2)); % a background rectangle drawn to indicate error in the placement of the main interval
            p.addParameter('errorIntervalColor', [0.5 0.5 0.5], @(x) isvector(x) || isempty(x) || ischar(x));
            p.addParameter('leaveInPlace', false, @islogical); % if true, don't anchor overall position, only internal relationships
            p.addParameter('manualPos', 0, @isscalar); % when leaveInPlace is true, where to place overall top along y
            p.addParameter('textOffsetY', 0, @isscalar);
            p.addParameter('textOffsetX', 0, @isscalar);
            p.addParameter('addSpaceForScaleBar', true, @islogical);
            p.addParameter('manualVerticalOffset', [], @(x) true);
            p.addParameter('vcenterWithMarkers', true, @islogical);
            p.addParameter('horizontalAlignment', 'center', @ischar);
            p.addParameter('verticalAlignment', 'top', @ischar);
            p.addParameter('fontSize', ax.tickFontSize, @isscalar);
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh; %#ok<*PROP>
            %leaveInPlace = p.Results.leaveInPlace;
            %manualPos = p.Results.manualPos;
            
            interval = double(p.Results.interval);
            color = p.Results.color;
            label = p.Results.label;
            errorInterval = p.Results.errorInterval;
            errorIntervalColor = p.Results.errorIntervalColor;
            fontSize = p.Results.fontSize;
            
            hr = [];
            ht = [];
            if interval(2) <= interval(1)
                warning('Skipping interval: endpoints must be monotonically increasing');
                return;
            end
            
            yl = get(axh, 'YLim');
            if ~isempty(errorInterval)
                if errorInterval(2) > errorInterval(1)
                    hre = rectangle('Position', [errorInterval(1), yl(1), ...
                        errorInterval(2)-errorInterval(1), 1], ...
                        'Parent', ax.axhDraw);
                    AutoAxis.hideInLegend(hre);
                    set(hre, 'FaceColor', errorIntervalColor, 'EdgeColor', 'none', ...
                        'Clipping', 'off', 'XLimInclude', 'off', 'YLimInclude', 'off');
                end
            else
                hre = [];
            end
           
            hri = rectangle('Position', [interval(1), yl(1), interval(2)-interval(1), 1], ...
                'Parent', ax.axhDraw);
            AutoAxis.hideInLegend(hri);
            
            hr = [hre; hri]; % order here matters, show error range under interval
            
            ht = text(mean(interval), yl(1), label, 'HorizontalAlignment', p.Results.horizontalAlignment, ...
                'VerticalAlignment', p.Results.verticalAlignment, 'Parent', ax.axhDraw, 'BackgroundColor', 'none');
            set(ht, 'FontSize', fontSize, 'Margin', 0.01, 'Color', p.Results.labelColor);
            
            set(hri, 'FaceColor', color, 'EdgeColor', 'none', 'Clipping', 'off', ...
                'XLimInclude', 'off', 'YLimInclude', 'off');
           
            if ax.debug
                set(ht, 'EdgeColor', 'r');
            end
            
            % build anchor for rectangle and label
            ai = AnchorInfo(hri, PositionType.Height, [], 'intervalThickness', 0, ...
                sprintf('interval ''%s'' thickness', label));
            ax.addAnchor(ai);

            % defer to compute_interval_offset to do the computation so that this can be updated automatically
            if p.Results.vcenterWithMarkers
                ax.interval_vcenterWithMarkers = true;
            end
            if p.Results.addSpaceForScaleBar
                ax.interval_addSpaceForScaleBar = true;
            end
            
            if ~isempty(p.Results.manualVerticalOffset)
                offset = p.Results.manualVerticalOffset;
            else
                offset = @(ax, varargin) ax.compute_interval_offset(varargin{:});
            end
            ai = AnchorInfo(hri, PositionType.VCenter, ax.axh, ...
                PositionType.Bottom, offset, ...
                sprintf('interval ''%s'' below axis (vcenter)', label));
            ax.addAnchor(ai);

            % add custom or default y offset from bottom of rectangle
            textOffsetY = p.Results.textOffsetY;
            pos = PositionType.verticalAlignmentToPositionType(p.Results.verticalAlignment);
            offsetBottom = @(ax, varargin) ax.compute_interval_label_offset_from_axis(textOffsetY);
            ai = AnchorInfo(ht, pos, ...
                ax.axh, PositionType.Bottom, offsetBottom, ...
                sprintf('interval label ''%s'' below axis', label));
            ax.addAnchor(ai);
  
            % add x offset in paper units to label 
            if p.Results.textOffsetX ~= 0
                pos = PositionType.horizontalAlignmentToPositionType(p.Results.horizontalAlignment);
                ai = AutoAxis.AnchorInfo(ht, pos, ...
                    p.Results.x, PositionType.Literal, p.Results.textOffsetX, ...
                    sprintf('interval label ''%s'' offset %g from X=%g', ...
                    label, p.Results.textOffsetX, p.Results.x));
                ax.addAnchor(ai);
            end

            if ~isempty(hre)
                % we use marker diameter here to make all error intervals
                % the same height
                ai = AnchorInfo(hre, PositionType.Height, [], @(ax,varargin) ax.markerHeight/3, 0, ...
                    sprintf('interval ''%s'' error thickness', label));
                ax.addAnchor(ai);
                ai = AnchorInfo(hre, PositionType.VCenter, hri, PositionType.VCenter, 0, ...
                    sprintf('interval ''%s'' error centered in interval', label));
                ax.addAnchor(ai);
            end  
           
            % add handles to handle collections
            hlist = [hr; ht];
            ax.addHandlesToCollection('belowX', hlist);
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
            
            % put in top layer
            ax.addHandlesToCollection('intervals', hlist);
        end

        function offset = compute_interval_offset(ax, varargin)
            % used by above to allow automatic updating of vertical offsets
            % we'd like the VCenters of the markers (height = markerDiameter)
            % to match the VCenters of the intervals (height =
            % intervalThickness). Marker tops sit at axisPaddingBottom from the
            % bottom of the axis. Note that this assumes markerDiameter >
            % intervalThickness.
            if ax.interval_vcenterWithMarkers
                % align v center to where the markers v center will be
                if ax.interval_addSpaceForScaleBar
                    offset = ax.axisPaddingBottom + ax.scaleBarThickness + ax.markerHeight/2;
                else
                    offset = ax.axisPaddingBottom + ax.markerHeight/2;
                end
            else
                % simply align top (include intervalthicknesss/2 since we're positioning the intervals v center, not the top)
                if ax.interval_addSpaceForScaleBar
                    offset = ax.axisPaddingBottom + ax.scaleBarThickness + ax.intervalThickness/2;
                else
                    offset = ax.axisPaddingBottom + ax.intervalThickness/2;
                end
            end
        end

        function offset = compute_interval_label_offset_from_axis(ax, textOffsetY)
            if ax.interval_addSpaceForScaleBar
                offset = ax.axisPaddingBottom + ax.scaleBarThickness + ax.intervalThickness + ax.markerLabelOffset + textOffsetY;
            else
                offset = ax.axisPaddingBottom + ax.intervalThickness + ax.markerLabelOffset + textOffsetY;
            end
        end
        
        function [hl, ht] = addLabeledSpan(ax, varargin)
            % add line and text objects to the axis that replace the normal
            % axes. 'span' is 2 x N matrix
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('which', @ischar);
            p.addParameter('span', [], @ismatrix); % 2 X N matrix of [ start; stop ] limits
            p.addParameter('label', {}, @isstringlike);
            p.addParameter('labelOffset', ax.tickLabelOffset, @(x) true);
            p.addParameter('labelInside', false, @islogical);
            p.addParameter('labelColor', []);
            p.addParameter('fontSize', ax.labelFontSize, @isscalar);
            p.addParameter('rotation', 0, @isscalar); % label rotation

            p.addParameter('aggregate_label', {}, @isstringlike);
            p.addParameter('aggregate_labelOffset', ax.tickLabelOffset, @(x) true);
            p.addParameter('aggregate_labelInside', false, @islogical);
            p.addParameter('aggregate_labelColor', []);
            p.addParameter('aggregate_fontSize', ax.labelFontSize, @isscalar);
            p.addParameter('aggregate_rotation', 0, @isscalar); % label rotation

            p.addParameter('color', [0 0 0], @(x) ischar(x) || iscell(x) || ismatrix(x));
            p.addParameter('lineWidth', ax.tickLineWidth, @isscalar);
            
            p.addParameter('leaveInPlace', false, @islogical);
            p.addParameter('otherSide', false, @isscalar); % if true, place top / right, false place at bottom / left
            p.addParameter('manualPos', 0, @isscalar); % position to place along non-orientation axis, when leaveInPlace is true
            p.addParameter('interpreter', 'none', @isstringlike);
            p.addParameter('showSpanLines', true, @islogical); % true to draw the line delineating the span, false for just the label

            % extender ellipses - continuation dots is [pre post] and can have nSpan rows. If a single row is provided,
            % the first span will get dots pre and the last span will get dots post.
            p.addParameter('spanPadding', [0 0]);
            p.addParameter('continuationDots', [false false]);
            p.addParameter('dotsSpan', 0.5, @isscalar); % width of dots and spacing
            p.addParameter('dotsCount', 3, @isscalar); % width of dots and spacing
            p.addParameter('dotSpacingFrac', 0.5, @isscalar);
            p.addParameter('includeDotsInSpan', true, @islogical); % shrink span to incorporate dots
            
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            useX = strcmp(p.Results.which, 'x');
            span = p.Results.span;
            label = string(p.Results.label);
            labelOffset = p.Results.labelOffset;
            labelInside = p.Results.labelInside;
            fontSize = p.Results.fontSize;
            lineWidth = p.Results.lineWidth;
            color = p.Results.color;
            labelColor = p.Results.labelColor;
            labelColor_aggregate = p.Results.aggregate_labelColor;
            leaveInPlace = p.Results.leaveInPlace;
            manualPos = p.Results.manualPos;
            otherSide = p.Results.otherSide;

            % check sizes
            if isvector(span)
                span = AutoAxisUtilities.makecol(span);
            end
            nSpan = size(span, 2);
            assert(size(span, 1) == 2, 'span must be 2 x N matrix of limits');
            label = string(label);
            if ~isempty(label)
                assert(numel(label) == nSpan, 'numel(label) must match size(span, 2)');
            end

            % continuation dot-related computations
            dots = p.Results.continuationDots;
            if isscalar(dots)
                dots = [dots dots];
            end
            if size(dots, 1) == 1 && nSpan > 1
                dots_orig = dots;
                dots = false(nSpan, 2);
                dots(1, 1) = dots_orig(1);
                dots(end, 2) = dots_orig(2);
            end
            assert(islogical(dots));
            dotsPre = dots(:, 1);
            dotsPost = dots(:, 2);
            dotsSpan = p.Results.dotsSpan;
            nDots = p.Results.dotsCount;
            dotSpacingFrac = p.Results.dotSpacingFrac;
            includeDotsInSpan = p.Results.includeDotsInSpan;
            spacing_width = dotSpacingFrac * dotsSpan / nDots;
            dot_width = (1-dotSpacingFrac) * dotsSpan / nDots;
            
            spanPadding = p.Results.spanPadding;
            if isscalar(spanPadding)
                spanPadding = [spanPadding spanPadding];
            end
            if size(spanPadding, 1) == 1 && nSpan > 1
                spanPadding = repmat(spanPadding, nSpan, 1);
            end
            spanPaddingPre = spanPadding(:, 1);
            spanPaddingPost = spanPadding(:, 2);
            
            if ischar(color)
                color = {color};
            end
            if isscalar(color) && nSpan > 1
                color = repmat(color, nSpan, 1);
            end
            if isempty(labelColor)
                labelColor = color;
            elseif ischar(labelColor)
                labelColor = {labelColor};
            end
            if isscalar(labelColor) && nSpan > 1
                labelColor = repmat(labelColor, nSpan, 1);
            end
            if isempty(labelColor_aggregate)
                labelColor_aggregate = color;
            end
            
            % generate line, ignore length here, we'll anchor that later
            if useX
                % x axis lines
                xvals = [span(1, :); span(2, :)];
                yvals = ones(size(xvals)) * manualPos;
                xtext = mean(span, 1);
                ytext = zeros(size(xtext));
                ha = repmat({'center'}, size(xtext));
                if ~otherSide
                    va = repmat({'top'}, size(xtext));
                    offset = 'axisPaddingBottom';
                else
                    va = repmat({'bottom'}, size(xtext));
                    offset = 'axisPaddingTop';
                end
                ha_aggregate = 'center';
                va_aggregate = 'middle';
                ytext_aggregate = manualPos;
                xtext_aggregate = mean([max(span(:)) min(span(:))]);

                [xdots_pre, xdots_post] = deal(nan(2, nDots, nSpan));
                [ydots_pre, ydots_post] = deal(ones(2, nDots, nSpan) * manualPos);
                    
                for i = 1:nSpan
                    % one short line per dot
                    if dotsPre(i)
                        for iD = 1:nDots
                            xdots_pre(1, iD, i) = span(1, i) + iD;
                            xdots_pre(2, iD, i) = span(1, i) + iD + 1;
                        end
                    end
                    if dotsPost(i)
                        for iD = 1:nDots
                            xdots_post(1, iD, i) = span(1, i) + iD;
                            xdots_post(2, iD, i) = span(1, i) + iD + 1;
                        end
                    end
                end
                
            else
                % y axis lines
                yvals = [span(1, :); span(2, :)];
                xvals = ones(size(yvals)) * manualPos;
                ytext = mean(span, 1);
                xtext = ones(size(ytext)) * manualPos;
                if abs(p.Results.rotation) < 20
                    if ~otherSide
                        ha = repmat({'right'}, size(xtext));
                    else
                        ha = repmat({'left'}, size(xtext));
                    end
                else
                    ha = repmat({'center'}, size(xtext));
                end
                va = repmat({'middle'}, size(xtext));
                if ~otherSide
                    offset = 'axisPaddingLeft';
                else
                    offset = 'axisPaddingRight';
                end
                ha_aggregate = 'center';
                va_aggregate = 'middle';
                xtext_aggregate = manualPos;
                ytext_aggregate = mean([max(span(:)) min(span(:))]);

                [ydots_pre, ydots_post] = deal(nan(2, nDots, nSpan));
                [xdots_pre, xdots_post] = deal(ones(2, nDots, nSpan) * manualPos);
                   
                % one short line per dot
                for i = 1:nSpan
                    if dotsPre(i)
                        for iD = 1:nDots
                            ydots_pre(1, iD, i) = span(1, i) + iD;
                            ydots_pre(2, iD, i) = span(1, i) + iD + 1;
                        end
                    end
                    if dotsPost(i)
                        for iD = 1:nDots
                            ydots_post(1, iD, i) = span(2, i) + iD;
                            ydots_post(2, iD, i) = span(2, i) + iD + 1;
                        end
                    end
                end
            end
            if iscell(color)
                nc = numel(color);
            else
                nc = size(color, 1);
            end
            wrap = @(i) mod(i-1, nc) + 1;
            
            if p.Results.showSpanLines
                hl = line(xvals, yvals, 'LineWidth', lineWidth, 'Parent', ax.axhDraw, ...
                    'Clipping', false, 'XLimInclude', false, 'YLimInclude', false);
            
                for i = 1:nSpan
                    if iscell(color)
                        set(hl(i), 'Color', color{wrap(i)});
                    else
                        set(hl(i), 'Color', color(wrap(i), :));
                    end
                end
                AutoAxis.hideInLegend(hl);

                % draw continuation dots
                if any(dotsPre)
                    hdotsPre = gobjects(nDots, nSpan);
                    for i = 1:nSpan
                        if ~dotsPre(i)
                            continue
                        end
                        hdotsPre(:, i) = line(xdots_pre(:, :, i), ydots_pre(:, :, i), 'LineWidth', lineWidth, 'Parent', ax.axhDraw);
                        if iscell(color)
                            set(hdotsPre(:, i), 'Color', color{wrap(i)});
                        else
                            set(hdotsPre(:, i), 'Color', color(wrap(i), :));
                        end
                    end
                else
                    hdotsPre = gobjects(0, 1);
                end
                if any(dotsPost)
                    hdotsPost = gobjects(nDots, nSpan);
                    for i = 1:nSpan
                        if ~dotsPost(i)
                            continue
                        end
                        hdotsPost(:, i) = line(xdots_post(:, :, i), ydots_post(:, :, i), 'LineWidth', lineWidth, 'Parent', ax.axhDraw);
                        if iscell(color)
                            set(hdotsPost(:, i), 'Color', color{wrap(i)});
                        else
                            set(hdotsPost(:, i), 'Color', color(wrap(i), :));
                        end
                    end
                else
                    hdotsPost = gobjects(0, 1);
                end

                flatten = @(v) v(:);
                hl_with_dots = [hl; flatten(hdotsPre(:, dotsPre)); flatten(hdotsPost(:, dotsPost))];
                set(hl_with_dots, 'Clipping', 'off', 'YLimInclude', 'off', 'XLimInclude', 'off');
            end
            
            ht = AutoAxis.allocateHandleVector(nSpan);
            keep = AutoAxisUtilities.truevec(nSpan);
            for i = 1:nSpan
                if isempty(label) || isempty(label{i}) || strcmp(label{i}, '')
                    keep(i) = false;
                    continue;
                end
                ht(i) = text(double(xtext(i)), double(ytext(i)), label{i}, ...
                    'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                    'Parent', ax.axhDraw, 'Interpreter', p.Results.interpreter, 'BackgroundColor', 'none', ...
                    'FontSize', fontSize, 'Rotation', p.Results.rotation, 'Margin', 0.001);
                if iscell(labelColor)
                    set(ht(i), 'Color', labelColor{wrap(i)});
                else
                    set(ht(i), 'Color', labelColor(wrap(i), :));
                end
            end
            ht = ht(keep);
            
            if ~isempty(ht)
                set(ht, 'Clipping', 'off', 'Margin', 0.01);
                
                if ax.debug
                    set(ht, 'EdgeColor', 'r');
                end
            end

            % aggregate label
            str_agg = string(p.Results.aggregate_label);
            if str_agg ~= ""
                ht_aggregate = text(double(xtext_aggregate), double(ytext_aggregate), str_agg, ...
                    'HorizontalAlignment', ha_aggregate, 'VerticalAlignment', va_aggregate, 'Color', labelColor_aggregate, ...
                    'Parent', ax.axhDraw, 'Interpreter', p.Results.interpreter, 'BackgroundColor', 'none', ...
                    'FontSize', p.Results.aggregate_fontSize, 'Rotation', p.Results.aggregate_rotation, 'Margin', 0.001);
            else
                ht_aggregate = [];
            end

            % build anchors for dots 
            if any(dotsPre)
                if useX
                    pos1 = PositionType.Right;
                    pos2 = PositionType.Left;
                    if ax.xReverse
                        [pos1, pos2] = swap(pos1, pos2);
                    end
                    posSize = PositionType.Width;
                    descPos = 'xLabeledSpan dotsPre left of main';
                    descSize = 'xBubbleSpan dotsPre width';
                else
                    pos1 = PositionType.Top;
                    pos2 = PositionType.Bottom;
                    if ax.yReverse
                        [pos1, pos2] = swap(pos1, pos2);
                    end
                    posSize = PositionType.Height;
                    descPos = 'yBubbleSpan dotsPre below main';
                    descSize = 'yBubbleSpan dotsPre height';
                end
                for i = 1:nSpan
                    if dotsPre(i)
                        for iDot = 1:nDots
                            % anchor right edge at offset
                            this_offset = (iDot-1) * dotsSpan / nDots + spacing_width;
                            ai = AnchorInfo(hdotsPre(iDot, i), pos1, hl(i), pos2, this_offset, descPos);
                            ax.addAnchor(ai);
    
                            ai = AnchorInfo(hdotsPre(iDot, i), posSize, [], dot_width, 0, descSize);
                            ax.addAnchor(ai);
                        end
                    end
                end
            end
            if any(dotsPost)
                if useX
                    pos1 = PositionType.Left;
                    pos2 = PositionType.Right;
                    if ax.xReverse
                        [pos1, pos2] = swap(pos1, pos2);
                    end
                    posSize = PositionType.Width;
                    descPos = 'xLabeledSpan dotsPost left of main';
                    descSize = 'xLabeledSpan dotsPost width';
                else
                    pos1 = PositionType.Bottom;
                    pos2 = PositionType.Top;
                    if ax.yReverse
                        [pos1, pos2] = swap(pos1, pos2);
                    end
                    posSize = PositionType.Height;
                    descPos = 'yLabeledSpan dotsPost above main';
                    descSize = 'yLabeledSpan dotsPost height';
                end
                for i = 1:nSpan
                    if dotsPost(i)
                        for iDot = 1:nDots
                            % anchor right edge at offset
                            this_offset = (iDot-1) * dotsSpan / nDots + spacing_width;
                            ai = AnchorInfo(hdotsPost(iDot, i), pos1, hl(i), pos2, this_offset, descPos);
                            ax.addAnchor(ai);
    
                            ai = AnchorInfo(hdotsPost(iDot, i), posSize, [], dot_width, 0, descSize);
                            ax.addAnchor(ai);
                        end
                    end
                end
            end

            
            if p.Results.showSpanLines
                if ~leaveInPlace
                    % build anchor for lines in non-spanned dimensions
                    if useX
                        if ~otherSide
                            ai = AnchorInfo(hl_with_dots, PositionType.Top, ax.axh, ...
                                PositionType.Bottom, offset, 'xLabeledSpan below axis');
                        else
                            ai = AnchorInfo(hl_with_dots, PositionType.Bottom, ax.axh, ...
                                PositionType.Top, offset, 'xLabeledSpan above axis');
                        end
                        ax.addAnchor(ai);
                    else
                        if ~otherSide
                            ai = AnchorInfo(hl_with_dots, PositionType.Right, ...
                                ax.axh, PositionType.Left, offset, 'yLabeledSpan left of axis');
                        else
                            ai = AnchorInfo(hl_with_dots, PositionType.Left, ...
                                ax.axh, PositionType.Right, offset, 'yLabeledSpan right of axis');
                        end
                        ax.addAnchor(ai);
                    end
                end

                % build anchors for rectangles in spanned dimension to accommodate padding and dots
                if useX
                    % position left and right sides
                    for i = 1:nSpan
                        this_offset = spanPaddingPre(i);
                        if dotsPre(i) && includeDotsInSpan
                            this_offset = this_offset + dotsSpan;
                        end
    
                        if ax.xReverse
                            posX = PositionType.Right;
                            this_offset = -this_offset;
                        else
                            posX = PositionType.Left;
                        end
                        vals = min(span, [], 1);
                        ai = AnchorInfo(hl(i), posX, vals(i), PositionType.Literal, this_offset, 'xLabeledSpan left with padding + dots');
                        ai.translateDontScale = false;
                        ax.addAnchor(ai);
                        
                        this_offset = spanPaddingPost(i);
                        if dotsPost(i) && includeDotsInSpan
                            this_offset = this_offset + dotsSpan;
                        end
                        if ax.xReverse
                            this_offset = -this_offset;
                        end
                        
                        ovals = max(span, [], 1);
                        ai = AnchorInfo(hl(i), posX.flip(), ovals(i), PositionType.Literal, -this_offset, 'xLabeledSpan right with padding + dots');
                        ai.translateDontScale = false;
                        ax.addAnchor(ai);
                    end
                else
                    % position bottom and top
                    for i = 1:nSpan
                        this_offset = spanPaddingPre(i);
                        if dotsPre(i) && includeDotsInSpan
                            this_offset = this_offset + dotsSpan;
                        end
    
                        if ax.yReverse
                            posY = PositionType.Top;
                            this_offset = -this_offset;
                        else
                            posY = PositionType.Bottom;
                        end
                        vals = min(span, [], 1);
                        ai = AnchorInfo(hl(i), posY, vals(i), PositionType.Literal, this_offset, 'yLabeledSpan bottom with padding + dots');
                        ai.translateDontScale = false;
                        ax.addAnchor(ai);
                        
                        this_offset = spanPaddingPost(i);
                        if dotsPost(i) && includeDotsInSpan
                            this_offset = this_offset + dotsSpan;
                        end
                        if ax.yReverse
                            this_offset = -this_offset;
                        end
    
                        ovals = max(span, [], 1);
                        ai = AnchorInfo(hl(i), posY.flip(), ovals(i), PositionType.Literal, -this_offset, 'yLabeledSpan top with padding + dots');
                        ai.translateDontScale = false;
                        ax.addAnchor(ai);
                    end
                end

                if ~isempty(ht)
                    % anchor labels to lines (always)
                    if useX
                        if xor(~otherSide, labelInside)
                            ai = AnchorInfo(ht, PositionType.Top, ...
                                hl_with_dots, PositionType.Bottom, labelOffset, ...
                                'xLabeledSpan label above line');
                        else
                            ai = AnchorInfo(ht, PositionType.Bottom, ...
                            hl_with_dots, PositionType.Top, labelOffset, ...
                            'xLabeledSpan label below line');
                        end
                        ax.addAnchor(ai);
                    else
                        if xor(~otherSide, labelInside)
                            ai = AnchorInfo(ht, PositionType.Right, ...
                                hl_with_dots, PositionType.Left, labelOffset, ...
                                'yLabeledSpan label right of line');
                        else
                            ai = AnchorInfo(ht, PositionType.Left, ...
                            hl_with_dots, PositionType.Right, labelOffset, ...
                            'yLabeledSpan label left of line');
                        end
                        ax.addAnchor(ai);
                    end
                end
            else
                % anchor labels to axis
                if useX
                    if ~otherSide
                        ai = AnchorInfo(ht, PositionType.Top, ax.axh, ...
                            PositionType.Bottom, offset, 'xLabeledSpan below axis');
                    else
                        ai = AnchorInfo(ht, PositionType.Bottom, ax.axh, ...
                            PositionType.Top, offset, 'xLabeledSpan above axis');
                    end
                    ax.addAnchor(ai);
                else
                    if ~otherSide
                        ai = AnchorInfo(ht, PositionType.Right, ...
                            ax.axh, PositionType.Left, offset, 'yLabeledSpan left of axis');
                    else
                        ai = AnchorInfo(ht, PositionType.Left, ...
                            ax.axh, PositionType.Right, offset, 'yLabeledSpan right of axis');
                    end
                    ax.addAnchor(ai);
                end
            end

            % anchor aggregate label
            if ~isempty(ht_aggregate)
                 if ~isempty(ht)
                    % anchor aggregate label to text labels
                    if useX
                        if xor(~otherSide, labelInside)
                            ai = AnchorInfo(ht_aggregate, PositionType.Top, ...
                                ht, PositionType.Bottom, labelOffset, ...
                                'xLabeledSpan aggregate label above labels');
                        else
                            ai = AnchorInfo(ht_aggregate, PositionType.Bottom, ...
                            ht, PositionType.Top, labelOffset, ...
                            'xLabeledSpan aggregatelabel below labels');
                        end
                        ax.addAnchor(ai);
                    else
                        if xor(~otherSide, labelInside)
                            ai = AnchorInfo(ht_aggregate, PositionType.Right, ...
                                ht, PositionType.Left, labelOffset, ...
                                'yLabeledSpan aggregate label right of labels');
                        else
                            ai = AnchorInfo(ht_aggregate, PositionType.Left, ...
                            ht, PositionType.Right, labelOffset, ...
                            'yLabeledSpan aggregate label left of labels');
                        end
                        ax.addAnchor(ai);
                    end

                 elseif ~isempty(hl_with_dots)
                     % no labels anchor aggregate label to span lines
                    if useX
                        if xor(~otherSide, labelInside)
                            ai = AnchorInfo(ht_aggregate, PositionType.Top, ...
                                hl_with_dots, PositionType.Bottom, labelOffset, ...
                                'xLabeledSpan aggregate label above line');
                        else
                            ai = AnchorInfo(ht_aggregate, PositionType.Bottom, ...
                            hl_with_dots, PositionType.Top, labelOffset, ...
                            'xLabeledSpan aggregate label below line');
                        end
                        ax.addAnchor(ai);
                    else
                        if xor(~otherSide, labelInside)
                            ai = AnchorInfo(ht_aggregate, PositionType.Right, ...
                                hl_with_dots, PositionType.Left, labelOffset, ...
                                'yLabeledSpan aggregate label right of line');
                        else
                            ai = AnchorInfo(ht_aggregate, PositionType.Left, ...
                            hl_with_dots, PositionType.Right, labelOffset, ...
                            'yLabeledSpan aggregate label left of line');
                        end
                        ax.addAnchor(ai);
                    end
                 else
                     error('Unexpected condition - aggregate label with no lines or labels. Should just be a single span?')
                 end
            end
            
            ht = AutoAxisUtilities.makecol(ht);
            if p.Results.showSpanLines
                hl_with_dots = AutoAxisUtilities.makecol(hl_with_dots);
                hlist = [hl_with_dots; ht];
            else
                hlist = ht;
            end
            if ~leaveInPlace
                % add handles to handle collections
                if useX
                    if ~otherSide
                        ax.addHandlesToCollection('belowX', hlist);
                    else
                        ax.addHandlesToCollection('aboveX', hlist);
                    end
                else
                    if ~otherSide
                        ax.addHandlesToCollection('leftY', hlist);
                    else
                        ax.addHandlesToCollection('rightY', hlist);
                    end
                end
            end
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
            
            % put in top layer
            ax.addHandlesToCollection('topLayer', hlist);

            function [b, a] = swap(a, b)
            end
        end 

        function [hr, ht] = addLabeledSpanBubbles(ax, varargin)
            % very similar to addLabeledSpans except uses rounded rectangles and adds some new options
            %  - continuation ellipses at the edges
            %  - padding relative to endpoints to create space between adjacent bubbles
            % 'span' is 2 x N matrix
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('which', @ischar);
            p.addParameter('span', [], @ismatrix); % 2 X N matrix of [ start; stop ] limits
            p.addParameter('label', {}, @isstringlike);
            p.addParameter('labelOffset', 'tickLabelOffset', @(x) true);
            p.addParameter('fontSize', ax.labelFontSize, @isscalar);
            p.addParameter('color', [0 0 0], @(x) ischar(x) || iscell(x) || ismatrix(x));
            p.addParameter('edgeColor', "none", @(x) ischar(x) || iscell(x) || ismatrix(x));
            p.addParameter('textColor', [], @(x) ischar(x) || iscell(x) || ismatrix(x));
            p.addParameter('addAnchors', false, @islogical);
            p.addParameter('otherSide', false, @isscalar); % if true, place top / right, false place at bottom / left
            p.addParameter('manualPos', 0, @isscalar); % position to place along non-orientation axis, when leaveInPlace is true
            p.addParameter('rotation', 0, @isscalar);
            p.addParameter('interpreter', 'none', @isstringlike);
            
            p.addParameter('bubblePadding', [0 0]);
            p.addParameter('continuationDots', [false false], @isvector);
            p.addParameter('dotsSpan', 0.5, @isscalar); % width of dots and spacing
            p.addParameter('includeDotsInSpan', true, @islogical); % shrink span to incorporate dots
            p.addParameter('dotsCount', 3, @isscalar); % width of dots and spacing
            p.addParameter('dotSpacingFrac', 0.5, @isscalar);
            p.addParameter('curvature', [0.1 0.1], @isvector);
            p.addParameter('height', 0.3, @isscalar);
            
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            useX = strcmp(p.Results.which, 'x');
            span = p.Results.span;
            label = string(p.Results.label);
            labelOffset = p.Results.labelOffset;
            fontSize = p.Results.fontSize;
            color = p.Results.color;
            edgeColor = p.Results.edgeColor;
            textColor = p.Results.textColor;
            if isempty(textColor)
                textColor = color;
            end
            manualPos = p.Results.manualPos;
            otherSide = p.Results.otherSide;

            % check sizes
            if isvector(span)
                span = AutoAxisUtilities.makecol(span);
            end
            nSpan = size(span, 2);
            assert(size(span, 1) == 2, 'span must be 2 x N matrix of limits');
            label = string(label);
            if ~isempty(label)
                assert(numel(label) == nSpan, 'numel(label) must match size(span, 2)');
            end

            bubblePadding = p.Results.bubblePadding;
            if isscalar(bubblePadding)
                bubblePadding = [bubblePadding bubblePadding];
            end
            if size(bubblePadding, 1) == 1 && nSpan > 1
                bubblePadding = repmat(bubblePadding, nSpan, 1);
            end
            bubblePaddingPre = bubblePadding(:, 1);
            bubblePaddingPost = bubblePadding(:, 2);
            
            % dot related properties
            dots = p.Results.continuationDots;
            if isscalar(dots)
                dots = [dots dots];
            end
            if size(dots, 1) == 1 && nSpan > 1
                dots_orig = dots;
                dots = false(nSpan, 2);
                dots(1, 1) = dots_orig(1);
                dots(end, 2) = dots_orig(2);
            end
            assert(islogical(dots));
            dotsPre = dots(:, 1);
            dotsPost = dots(:, 2);
            dotsSpan = p.Results.dotsSpan;
            nDots = p.Results.dotsCount;
            dotSpacingFrac = p.Results.dotSpacingFrac;
            includeDotsInSpan = p.Results.includeDotsInSpan;
            curvature = p.Results.curvature;
            height = p.Results.height;

            if ischar(color)
                color = {color};
            end
            if isscalar(color) && nSpan > 1
                color = repmat(color, nSpan, 1);
            end
            if ischar(edgeColor)
                edgeColor = {edgeColor};
            end
            if ischar(textColor)
                textColor = {textColor};
            end
            
            % generate line, ignore length here, we'll anchor that later
            if useX
                % x axis lines
                xv = span(1, :);
                wv = span(2, :) - span(1, :);
                yv = ones(1, nSpan)*manualPos;
                hv = ones(1, nSpan)*height;
                if ax.yReverse
                    [yv, hv] = swap(hv, yv);
                end
                
                xtext = mean(span, 1);
                ytext = zeros(size(xtext));
                ha = repmat({'center'}, size(xtext));
                if ~otherSide
                    va = repmat({'top'}, size(xtext));
                    offset = 'axisPaddingBottom';
                else
                    va = repmat({'bottom'}, size(xtext));
                    offset = 'axisPaddingTop';
                end
                
            else
                % y axis lines
                yv = span(1, :);
                hv = span(2, :) - span(1, :);
                xv = ones(1, nSpan)*manualPos;
                wv = ones(1, nSpan)*height;
                if ax.yReverse
                    [xv, wv] = swap(xv, wv);
                end
                ytext = mean(span, 1);
                xtext = zeros(size(ytext));
                if abs(p.Results.rotation) < 20
                    if ~otherSide
                        ha = repmat({'right'}, size(xtext));
                    else
                        ha = repmat({'left'}, size(xtext));
                    end
                else
                    ha = repmat({'center'}, size(xtext));
                end
                va = repmat({'middle'}, size(xtext));
                if ~otherSide
                    offset = 'axisPaddingLeft';
                else
                    offset = 'axisPaddingRight';
                end
            end
            if iscell(color)
                nc = numel(color);
            else
                nc = size(color, 1);
            end
            wrap = @(i) mod(i-1, nc) + 1;
            if iscell(edgeColor)
                nc_edge = numel(edgeColor);
            else
                nc_edge = size(edgeColor, 1);
            end
            wrap_edge = @(i) mod(i-1, nc_edge) + 1;
            if iscell(textColor)
                nc_text = numel(textColor);
            else
                nc_text = size(textColor, 1);
            end
            wrap_text = @(i) mod(i-1, nc_text) + 1;
            
            hr = gobjects(nSpan, 1);
            if any(dotsPre)
                hdot_pre = gobjects(nSpan, nDots);
            else
                hdot_pre = gobjects(0, 1);
            end
            if any(dotsPost)
                hdot_post = gobjects(nSpan, nDots);
            else
                hdot_post = gobjects(0, 1);
            end
            
            spacing_width = dotSpacingFrac * dotsSpan / nDots;
            dot_width = (1-dotSpacingFrac) * dotsSpan / nDots;
            
            for i = 1:nSpan
                pos = [xv(i) yv(i) wv(i) hv(i)];
                if iscell(color)
                    this_color = color{wrap(i)};
                else
                    this_color = color(wrap(i), :);
                end
                if iscell(edgeColor)
                    this_edge_color = edgeColor{wrap_edge(i)};
                else
                    this_edge_color = edgeColor(wrap_edge(i), :);
                end
                hr(i) = rectangle('Position', pos, 'Curvature', curvature, 'FaceColor', this_color, ...
                    'EdgeColor', this_edge_color, 'Parent', ax.axhDraw);

                if dotsPre(i)
                    % build dots before
                    if useX
                        for iDot = 1:nDots
                            this_offset = iDot * dotsSpan / nDots;
                            pos = [xv(i) - this_offset, yv(i), dot_width, hv(i)];
                            hdot_pre(i, iDot) = rectangle('Position', pos, 'Curvature', curvature, 'FaceColor', this_color, ...
                                'EdgeColor', this_edge_color, 'Parent', ax.axhDraw);
                        end
                    else
                        for iDot = 1:nDots
                            this_offset = iDot * dotsSpan / nDots;
                            pos = [xv(i), yv(i)-this_offset, wv(i), dot_width];
                            hdot_pre(i, iDot) = rectangle('Position', pos, 'Curvature', curvature, 'FaceColor', this_color, ...
                                'EdgeColor', this_edge_color, 'Parent', ax.axhDraw);
                        end
                    end
                end
                if dotsPost(i)
                    % build dots before
                    if useX
                        for iDot = 1:nDots
                            this_offset = iDot * dotsSpan / nDots;
                            pos = [xv(i) + wv(i) + this_offset, yv(i), dot_width, hv(i)];
                            hdot_post(i, iDot) = rectangle('Position', pos, 'Curvature', curvature, 'FaceColor', this_color, ...
                                'EdgeColor', this_edge_color, 'Parent', ax.axhDraw);
                        end
                    else
                        for iDot = 1:nDots
                            this_offset = iDot * dotsSpan / nDots;
                            pos = [xv(i), yv(i) + hv(i) + this_offset, wv(i), dot_width];
                            hdot_post(i, iDot) = rectangle('Position', pos, 'Curvature', curvature, 'FaceColor', this_color, ...
                                'EdgeColor', this_edge_color, 'Parent', ax.axhDraw);
                        end
                    end
                end
                hold on;
            end

            flatten = @(x) x(:);
            hrect_all = cat(1, hr, flatten(hdot_pre(dotsPre, :)), flatten(hdot_post(dotsPost, :)));
            AutoAxis.hideInLegend(hrect_all);
            set(hrect_all, 'Clipping', 'off', 'YLimInclude', 'off', 'XLimInclude', 'off');
            
            % build labels
            ht = AutoAxis.allocateHandleVector(nSpan);
            keep = AutoAxisUtilities.truevec(nSpan);
            for i = 1:nSpan
                if isempty(label) || isempty(label{i})
                    keep(i) = false;
                    continue;
                end
                ht(i) = text(double(xtext(i)), double(ytext(i)), label{i}, ...
                    'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                    'Parent', ax.axhDraw, 'Interpreter', p.Results.interpreter, 'BackgroundColor', 'none', ...
                    'FontSize', fontSize, 'Rotation', p.Results.rotation, 'Margin', 0.001);
                if iscell(textColor)
                    set(ht(i), 'Color', textColor{wrap_text(i)});
                else
                    set(ht(i), 'Color', textColor(wrap_text(i), :));
                end
            end
            ht = ht(keep);
            
            if ~isempty(ht)
                set(ht, 'Clipping', 'off', 'Margin', 0.01);
                
                if ax.debug
                    set(ht, 'EdgeColor', 'r');
                end
            end
            
            % build anchors for rectangles in non-spanned dimension
            if useX
                % height
                ai = AnchorInfo(hrect_all, PositionType.Height, [], height, 0, 'xBubbleSpan height');
                ax.addAnchor(ai);

                if ~otherSide
                    ai = AnchorInfo(hrect_all, PositionType.Top, ax.axh, ...
                        PositionType.Bottom, offset, 'xBubbleSpan below axis');
                else
                    ai = AnchorInfo(hrect_all, PositionType.Bottom, ax.axh, ...
                        PositionType.Top, offset, 'xBubbleSpan above axis');
                end
                ax.addAnchor(ai);
            else
                % width
                ai = AnchorInfo(hrect_all, PositionType.Width, [], height, 0, 'yBubbleSpan width');
                ax.addAnchor(ai);

                if ~otherSide
                    ai = AnchorInfo(hrect_all, PositionType.Right, ...
                        ax.axh, PositionType.Left, offset, 'yBubbleSpan left of axis');
                else
                    ai = AnchorInfo(hrect_all, PositionType.Left, ...
                        ax.axh, PositionType.Right, offset, 'yBubbleSpan right of axis');
                end
                ax.addAnchor(ai);
            end

            % build anchors for rectangles in spanned dimension to accommodate padding and dots
            if useX
                % position left and right sides
                for i = 1:nSpan
                    this_offset = bubblePaddingPre(i);
                    if dotsPre(i) && includeDotsInSpan
                        this_offset = this_offset + dotsSpan;
                    end

                    ai = AnchorInfo(hr(i), PositionType.Left, span(1, i), PositionType.Literal, this_offset, 'xBubbleSpan left with padding + dots');
                    ai.translateDontScale = false;
                    ax.addAnchor(ai);
                    
                    this_offset = bubblePaddingPost(i);
                    if dotsPost(i) && includeDotsInSpan
                        this_offset = this_offset + dotsSpan;
                    end

                    ai = AnchorInfo(hr(i), PositionType.Right, span(2, i), PositionType.Literal, -this_offset, 'xBubbleSpan right with padding + dots');
                    ai.translateDontScale = false;
                    ax.addAnchor(ai);
                end
            else
                % position bottom and top
                for i = 1:nSpan
                    this_offset = bubblePaddingPre(i);
                    if dotsPre(i) && includeDotsInSpan
                        this_offset = this_offset + dotsSpan;
                    end

                    ai = AnchorInfo(hr(i), PositionType.Bottom, span(1, i), PositionType.Literal, this_offset, 'yBubbleSpan bottom with padding + dots');
                    ai.translateDontScale = false;
                    ax.addAnchor(ai);
                    
                    this_offset = bubblePaddingPost(i);
                    if dotsPost(i) && includeDotsInSpan
                        this_offset = this_offset + dotsSpan;
                    end

                    ai = AnchorInfo(hr(i), PositionType.Top, span(2, i), PositionType.Literal, -this_offset, 'yBubbleSpan top with padding + dots');
                    ai.translateDontScale = false;
                    ax.addAnchor(ai);
                end
            end

            % build anchors for dots 
            if any(dotsPre)
                if useX
                    pos1 = PositionType.Right;
                    pos2 = PositionType.Left;
                    posSize = PositionType.Width;
                    descPos = 'xBubbleSpan dotsPre left of main';
                    descSize = 'xBubbleSpan dotsPre width';
                else
                    pos1 = PositionType.Top;
                    pos2 = PositionType.Bottom;
                    posSize = PositionType.Height;
                    descPos = 'yBubbleSpan dotsPre below main';
                    descSize = 'yBubbleSpan dotsPre height';
                end
                for i = 1:nSpan
                    if dotsPre(i)
                        for iDot = 1:nDots
                            % anchor right edge at offset
                            this_offset = (iDot-1) * dotsSpan / nDots + spacing_width;
                            ai = AnchorInfo(hdot_pre(i, iDot), pos1, hr(i), pos2, this_offset, descPos);
                            ax.addAnchor(ai);
    
                            ai = AnchorInfo(hdot_pre(i, iDot), posSize, [], dot_width, 0, descSize);
                            ax.addAnchor(ai);
                        end
                    end
                end
            end
            if any(dotsPost)
                if useX
                    pos1 = PositionType.Left;
                    pos2 = PositionType.Right;
                    posSize = PositionType.Width;
                    descPos = 'xBubbleSpan dotsPost left of main';
                    descSize = 'xBubbleSpan dotsPost width';
                else
                    pos1 = PositionType.Bottom;
                    pos2 = PositionType.Top;
                    posSize = PositionType.Height;
                    descPos = 'yBubbleSpan dotsPost above main';
                    descSize = 'yBubbleSpan dotsPost height';
                end
                for i = 1:nSpan
                    if dotsPost(i)
                        for iDot = 1:nDots
                            % anchor right edge at offset
                            offset = (iDot-1) * dotsSpan / nDots + spacing_width;
                            ai = AnchorInfo(hdot_post(i, iDot), pos1, hr(i), pos2, offset, descPos);
                            ax.addAnchor(ai);
    
                            ai = AnchorInfo(hdot_post(i, iDot), posSize, [], dot_width, 0, descSize);
                            ax.addAnchor(ai);
                        end
                    end
                end
            end

            % build anchors for labels
            if ~isempty(ht)
                % anchor labels to lines (always)
                if useX
                    if ~otherSide
                        ai = AnchorInfo(ht, PositionType.Top, ...
                            hr, PositionType.Bottom, labelOffset, ...
                            'xBubbleSpan label below');
                    else
                        ai = AnchorInfo(ht, PositionType.Bottom, ...
                        hr, PositionType.Top, labelOffset, ...
                        'xBubbleSpan label above');
                    end
                    ax.addAnchor(ai);

                    ai = AnchorInfo(ht, PositionType.HCenter, ...
                            hr, PositionType.HCenter, 0, ...
                            'xBubbleSpan label hcenter');
                    ax.addAnchor(ai);
                else
                    if ~otherSide
                        ai = AnchorInfo(ht, PositionType.Right, ...
                            hr, PositionType.Left, labelOffset, ...
                            'yBubbleSpan label left');
                    else
                        ai = AnchorInfo(ht, PositionType.Left, ...
                        hr, PositionType.Right, labelOffset, ...
                        'yBubbleSpan label right');
                    end
                    ax.addAnchor(ai);

                    ai = AnchorInfo(ht, PositionType.VCenter, ...
                            hr, PositionType.VCenter, 0, ...
                            'xBubbleSpan label vcenter');
                    ax.addAnchor(ai);
                end
            end
            
            ht = AutoAxisUtilities.makecol(ht);
            hr = AutoAxisUtilities.makecol(hr);
            hlist = [hr; ht];
            
            % add handles to handle collections
            if useX
                if ~otherSide
                    ax.addHandlesToCollection('belowX', hlist);
                else
                    ax.addHandlesToCollection('aboveX', hlist);
                end
            else
                if ~otherSide
                    ax.addHandlesToCollection('leftY', hlist);
                else
                    ax.addHandlesToCollection('rightY', hlist);
                end
            end
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
            
            % put in top layer
            ax.addHandlesToCollection('topLayer', hlist);

            function [b, a] = swap(a, b)
            end
        end 
        
        function hvec = addColoredLabels(ax, labels, colors, varargin)
            import AutoAxis.PositionType;
            import AutoAxis.AnchorInfo;
            
            p = inputParser();
            p.addParameter('posX', PositionType.Right, @(x) isa(x, 'AutoAxis.PositionType'));
            p.addParameter('posY', PositionType.Top, @(x) isa(x, 'AutoAxis.PositionType'));
            p.addParameter('outsideX', false, @islogical);
            p.addParameter('outsideY', false, @islogical);
            p.addParameter('fontSize', ax.labelFontSize, @(x) isscalar(x) || isvector(x));
            p.addParameter('fontWeight', "normal");
            p.addParameter('spacing', 'tickLabelOffset', @(x) true);
            p.addParameter('offsetX', '', @(x) true);
            p.addParameter('offsetY', '', @(x) true);
            p.addParameter('stacking', 'vertical', @isstringlike);
            p.addParameter('fillColor', 'none', @(x) true);
            p.addParameter('fillAlpha', 1, @isscalar);
            p.addParameter('interpreter', 'none', @isstringlike);
            p.addParameter('addAnchorsPosX', true, @islogical);
            p.addParameter('addAnchorsPosY', true, @islogical);
            p.parse(varargin{:});
            posX = p.Results.posX;
            interpreter = p.Results.interpreter;
            outsideX = p.Results.outsideX;
            offsetX = p.Results.offsetX;
            if isempty(offsetX)
                if outsideX
                    offsetX = 'tickLabelOffset';
                else
                    offsetX = '-tickLabelOffset';
                end
            end
                    
            posY = p.Results.posY;
            outsideY = p.Results.outsideY;
            offsetY = p.Results.offsetY;
            if isempty(offsetY)
                if outsideY
                    offsetY = 'tickLabelOffset';
                else
                    offsetY = '-tickLabelOffset';
                end
            end
            
            if isnumeric(labels)
                labels = arrayfun(@num2str, labels, 'UniformOutput', false);
            end  
            
            if ischar(labels)
                labels = string(labels);
            end
            
            N = numel(labels);
            
            if nargin < 3 || isempty(colors)
                colors = get(ax.axh, 'ColorOrder');
            end
            
            hvec = AutoAxis.allocateHandleVector(N);
            
            if strcmp(get(gca, 'YDir'), 'reverse')
                rev = true;
            else
                rev = false;
            end
            
            if outsideX
                horzAlign = posX.flip().toHorizontalAlignment();
                
            else
                horzAlign = posX.toHorizontalAlignment();
            end
            if outsideY
                vertAlign = posY.flip().toVerticalAlignment();
            else
                vertAlign = posY.toVerticalAlignment();
            end

            fontSize = p.Results.fontSize;
            if isscalar(fontSize)
                fontSize = repmat(fontSize, N, 1);
            end

            fontWeight = p.Results.fontWeight;
            fontWeight = string(fontWeight);
            if isscalar(fontWeight)
                fontWeight = repmat(fontWeight, N, 1);
            end
            
            for i = 1:N
                label = labels{i};
                if iscell(colors)
                    c = colors{i};
                elseif size(colors, 1) == 1
                    c = colors;
                else
                    c = colors(i, :);
                end
 
                if strcmp(p.Results.stacking, 'vertical')
                    x = 0;
                    y = (~rev * -i);
                else
                    y = 0;
                    x = ~rev * i;
                end
                
                
                hvec(i) = text(x, y, label, 'FontSize', fontSize(i), 'FontWeight', fontWeight(i), ...
                    'Color', c, 'Margin', 0.001, 'HorizontalAlignment', horzAlign, ...
                    'VerticalAlignment', vertAlign, 'Interpreter', interpreter);
                if isempty(p.Results.fillColor) || (ischar(p.Results.fillColor) && strcmp(p.Results.fillColor, 'none'))
                    set(hvec(i), 'BackgroundColor', 'none');
                else
                    set(hvec(i), 'BackgroundColor', p.Results.fillColor);
                    if p.Results.fillAlpha < 1
                        hvec(i).BackgroundColor(4) = p.Results.fillAlpha;
                    end  
                end
                    
            end

            if strcmp(p.Results.stacking, 'vertical')
                top = posY == PositionType.Top;
                if top
                    root = 1;
                    anchorToOffset = -1;
                    innerAnchorPosY = PositionType.Top;
                else
                    root = N;
                    anchorToOffset = 1;
                    innerAnchorPosY = PositionType.Bottom;
                end  
            
                % anchor the root to the axis and the rest to the one
                % above/below
                for i = 1:N
                    if i ~= root
                        % anchor to text above/below
                        ai = AnchorInfo(hvec(i), innerAnchorPosY, hvec(i+anchorToOffset), innerAnchorPosY.flip(), p.Results.spacing, ...
                            sprintf('colorLabel %s %s to %s %s', labels{i}, char(posY), labels{i+anchorToOffset}, char(posY.flip())));
                        ax.addAnchor(ai);
                    end                    
                end
                
                if p.Results.addAnchorsPosY
                    % anchor group to axis
                    if outsideY
                        ai = AnchorInfo(hvec, posY.flip(), ax.axh, posY, offsetY, ...
                            sprintf('colorLabel group %s to outside axis %s', char(posY), char(posY)));
                    else
                        ai = AnchorInfo(hvec, posY, ax.axh, posY, offsetY, ...
                            sprintf('colorLabel group %s to axis %s', char(posY), char(posY)));
                    end
                    ax.addAnchor(ai);
                end
                
                if p.Results.addAnchorsPosX
                    % anchor horizontally to axis
                    if outsideX
                        ai = AnchorInfo(hvec, posX.flip(), ax.axh, posX, offsetX, ...
                            sprintf('colorLabels %s to axis %s', char(posX.flip()), char(posX)));
                    else
                        ai = AnchorInfo(hvec, posX, ax.axh, posX, offsetX, ...
                            sprintf('colorLabels %s to axis %s', char(posX), char(posX)));
                    end
                    ax.addAnchor(ai);
                end

            else
                left = posX == PositionType.Left;
                if left
                    root = 1;
                    anchorToOffset = -1;
                    innerAnchorPosX = PositionType.Left;
                else
                    root = N;
                    anchorToOffset = 1;
                    innerAnchorPosX = PositionType.Right;
                end
                
                % anchor the root to the axis and the rest to the one
                % left/right
                for i = 1:N
                    if i ~= root
                        % anchor to text left/left
                        ai = AnchorInfo(hvec(i), innerAnchorPosX, hvec(i+anchorToOffset), innerAnchorPosX.flip(), p.Results.spacing, ...
                            sprintf('colorLabel %s %s to %s %s', labels{i}, char(posX), labels{i+anchorToOffset}, char(posX.flip())));
                        ax.addAnchor(ai);
                    end
                end
                
                if p.Results.addAnchorsPosX
                    % anchor group to axis
                    if outsideX
                        ai = AnchorInfo(hvec, posX.flip(), ax.axh, posX, offsetX, ...
                            sprintf('colorLabel group %s to outside axis %s', char(posY.flip()), char(posX)));
                    else
                        ai = AnchorInfo(hvec, posX, ax.axh, posX, offsetX, ...
                            sprintf('colorLabel group %s to axis %s', char(posY), char(posX)));
                    end
                    ax.addAnchor(ai);
                end
                
                if p.Results.addAnchorsPosY
                    % anchor vertically to axis
                    if outsideY
                        ai = AnchorInfo(hvec, posY.flip(), ax.axh, posY, offsetY, ...
                            sprintf('colorLabels %s to axis %s', char(posY), char(posY)));
                    else
                        ai = AnchorInfo(hvec, posY, ax.axh, posY, offsetY, ...
                            sprintf('colorLabels %s to axis %s', char(posY), char(posY)));
                    end
                    ax.addAnchor(ai);       
                end
            end
            
            
%             % add background box
%             if ~isempty(p.Results.fillColor)
%                 margin = 1;
%                 hr = rectangle('Position', [0 0 1 1], 'FaceColor', p.Results.fillColor, 'EdgeColor', 'r');
%                 ax.addAnchor(AnchorInfo(hr, AutoAxis.PositionType.Top, hvec, AutoAxis.PositionType.Top, -margin));
%                 ax.addAnchor(AnchorInfo(hr, AutoAxis.PositionType.Bottom, hvec, AutoAxis.PositionType.Bottom, margin));
%                 ax.addAnchor(AnchorInfo(hr, AutoAxis.PositionType.Left, hvec, AutoAxis.PositionType.Left, -margin));
%                 ax.addAnchor(AnchorInfo(hr, AutoAxis.PositionType.Right, hvec, AutoAxis.PositionType.Right, margin));
%                 ax.addHandlesToCollection('topLayer', hr);
%                 ax.addHandlesToCollection('generated', hr);
%             end
            
            % put in top layer
            ax.addHandlesToCollection('topLayer', hvec);
            
            % list as generated content
            ax.addHandlesToCollection('generated', hvec);
        end
        
        function h = addInsetTitle(ax, title, subtitle, varargin)
            import AutoAxis.PositionType;
            import AutoAxis.AnchorInfo;
            
            p = inputParser();
            p.addParameter('posX', PositionType.Left, @(x) isa(x, 'AutoAxis.PositionType'));
            p.addParameter('posY', PositionType.Top, @(x) isa(x, 'AutoAxis.PositionType'));
            p.addParameter('color', [0 0 0], @(x) true);
            p.addParameter('colorSubtitle', [], @(x) true);
            p.addParameter('fontSize', ax.labelFontSize, @isscalar);
            p.addParameter('fontWeight', 'bold', @ischar);
            p.addParameter('fontSizeSubtitle', ax.labelFontSize, @isscalar);
            p.addParameter('fontWeightSubtitle', 'normal', @ischar);
            p.addParameter('spacing', 'tickLabelOffset', @(x) true);
            p.addParameter('offsetX', '-tickLabelOffset', @(x) true);
            p.addParameter('offsetY', '-tickLabelOffset', @(x) true);
            p.addParameter('stacking', 'vertical', @ischar);
            p.addParameter('fillColor', 'none', @(x) true);
            p.addParameter('fillAlpha', 1, @isscalar);
            p.KeepUnmatched = true;
            p.parse(varargin{:});
           
            % try replacing with this
            if isempty(title) || strcmp(title, "")
                hasTitle = false;
                title = "";
            else
                hasTitle = true;
                title = string(title);
            end
            if isempty(subtitle) || strcmp(subtitle, "")
                hasSubtitle = false;
                subtitle = "";
            else
                hasSubtitle = true;
                subtitle = string(subtitle);
            end

            c = p.Results.color;
            csub = p.Results.colorSubtitle;
            if isempty(csub)
                csub = c;
            end

            labels = [title; subtitle];
            colors = [c; csub];
            sizes = [p.Results.fontSize, p.Results.fontSizeSubtitle];
            weights = [string(p.Results.fontWeight); string(p.Results.fontWeightSubtitle)];
            mask = [hasTitle; hasSubtitle];

            h = ax.addColoredLabels(labels(mask), colors(mask, :), p.Unmatched, FontSize=sizes(mask), FontWeight=weights(mask), ...
                posX=p.Results.posX, posY=p.Results.posY, spacing=p.Results.spacing, ...
                offsetX=p.Results.offsetX, offsetY=p.Results.offsetY, stacking=p.Results.stacking, ...
                fillColor=p.Results.fillColor, fillAlpha=p.Results.fillAlpha);

            % old version below:
            
%             if strcmp(get(gca, 'YDir'), 'reverse')
%                 rev = true;
%             else
%                 rev = false;
%             end
%             c = p.Results.color;
%             csub = p.Results.colorSubtitle;
%             if isempty(csub)
%                 csub = c;
%             end
%  
%             if strcmp(p.Results.stacking, 'vertical')
%                 x = 0;
%                 y = (~rev * -1);
%             else
%                 y = 0;
%                 x = ~rev * 1;
%             end
%             if ~isempty(title) && ~strcmp(title, "")
%                 htitle = text(x, y, title, 'FontSize', p.Results.fontSize, 'fontWeight', p.Results.fontWeight, ...
%                     'Color', c, 'HorizontalAlignment', posX.toHorizontalAlignment(), ...
%                     'VerticalAlignment', posY.flip().toVerticalAlignment());
%                 if isempty(p.Results.fillColor) || (ischar(p.Results.fillColor) && strcmp(p.Results.fillColor, 'none'))
%                     set(htitle, 'BackgroundColor', 'none');
%                 else
%                     set(htitle, 'BackgroundColor', p.Results.fillColor);
%                     if p.Results.fillAlpha < 1
%                         htitle.BackgroundColor(4) = p.Results.fillAlpha;
%                     end  
%                 end
% %                 hasTitle = true;
%             else
%                 htitle = gobjects(0, 1);
% %                 hasTitle = false;
%             end
%             
%             if ~isempty(subtitle) && ~strcmp(subtitle, "")
%                 if strcmp(p.Results.stacking, 'vertical')
%                     x = 0;
%                     y = (~rev * -2);
%                 else
%                     y = 0;
%                     x = ~rev * 2;
%                 end
%                 hsub = text(x, y, subtitle, 'FontSize', p.Results.fontSizeSubtitle, 'fontWeight', p.Results.fontWeightSubtitle, ...
%                     'Color', csub, 'HorizontalAlignment', posX.toHorizontalAlignment(), ...
%                     'VerticalAlignment', posY.flip().toVerticalAlignment());
%                 if isempty(p.Results.fillColor) || (ischar(p.Results.fillColor) && strcmp(p.Results.fillColor, 'none'))
%                     set(hsub, 'BackgroundColor', 'none');
%                 else
%                     set(hsub, 'BackgroundColor', p.Results.fillColor);
%                     if p.Results.fillAlpha < 1
%                         hsub.BackgroundColor(4) = p.Results.fillAlpha;
%                     end  
%                 end
% %                 hasSubTitle = true;
%             else
%                 hsub = gobjects(0, 1);
% %                 hasSubTitle = false;
%             end
% 
%             hvec = cat(1, htitle, hsub);
%             N = numel(hvec);
%             
%             if strcmp(p.Results.stacking, 'vertical')
%                 top = posY == PositionType.Top;
%                 if top
%                     root = 1;
%                     anchorToOffset = -1;
%                     innerAnchorPosY = PositionType.Top;
%                 else
%                     root = N;
%                     anchorToOffset = 1;
%                     innerAnchorPosY = PositionType.Bottom;
%                 end  
%             
%                 % anchor the root to the axis and the rest to the one
%                 % above/below
%                 for i = 1:N
%                     if i ~= root
%                         % anchor to text above/below
%                         ai = AnchorInfo(hvec(i), innerAnchorPosY, hvec(i+anchorToOffset), innerAnchorPosY.flip(), p.Results.spacing, ...
%                             sprintf('inset title %d %s to %d %s', i, char(posY), i+anchorToOffset, char(posY.flip())));
%                         ax.addAnchor(ai);
%                     end                    
%                 end
%                 
%                 % anchor group to axis
%                 ai = AnchorInfo(hvec, posY, ax.axh, posY, p.Results.offsetY, ...
%                     sprintf('colorLabel group %s to axis %s', char(posY), char(posY)));
%                 ax.addAnchor(ai);
%                 
%                 % anchor horizontally to axis
%                 ai = AnchorInfo(hvec, posX, ax.axh, posX, p.Results.offsetX, ...
%                     sprintf('colorLabels to axis %s', char(posX), char(posX)));
%                 ax.addAnchor(ai);
%             else
%                 left = posX == PositionType.Left;
%                 if left
%                     root = 1;
%                     anchorToOffset = -1;
%                     innerAnchorPosX = PositionType.Left;
%                 else
%                     root = N;
%                     anchorToOffset = 1;
%                     innerAnchorPosX = PositionType.Right;
%                 end
%                 
%                 % anchor the root to the axis and the rest to the one
%                 % left/right
%                 for i = 1:N
%                     if i ~= root
%                         % anchor to text left/left
%                         ai = AnchorInfo(hvec(i), innerAnchorPosX, hvec(i+anchorToOffset), innerAnchorPosX.flip(), p.Results.spacing, ...
%                             sprintf('colorLabel %s %s to %s %s', labels{i}, char(posX), labels{i+anchorToOffset}, char(posX.flip())));
%                     end
%                     ax.addAnchor(ai);
%                 end
%                 
%                 % anchor group to axis
%                 ai = AnchorInfo(hvec, posX, ax.axh, posX, p.Results.offsetX, ...
%                     sprintf('colorLabel group %s to axis %s', char(posY), char(posX)));
%                 ax.addAnchor(ai);
%                 
%                 % anchor vertically to axis
%                 ai = AnchorInfo(hvec, posY, ax.axh, posY, p.Results.offsetY, ...
%                     sprintf('colorLabels to axis %s', char(posY), char(posY)));
%                 ax.addAnchor(ai);       
%             end
%             
%             % put in top layer
%             ax.addHandlesToCollection('topLayer', hvec);
%             
%             % list as generated content
%             ax.addHandlesToCollection('generated', hvec);
        end
        
        function [hl, ht] = addLocationIndicator(ax, varargin)
            % for drawing small ticks near the edge of an axis, e.g. to indicate
            % the mean or median of a distribution
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('which', @ischar);
            p.addRequired('location', @isscalar);
            p.addOptional('label', '', @ischar);
            p.addParameter('fontSize', ax.tickFontSize, @isscalar);
            p.addParameter('otherSide', false, @isscalar); % if true, place top / right, false place at bottom / left
            p.addParameter('length', 0.5, @isscalar); % in cm
            p.addParameter('extendFromEdge', 0, @isscalar); % in cm
            p.addParameter('labelColor', ax.tickFontColor, @(x) isvector(x) || isempty(x) || ischar(x));
            p.addParameter('lineWidth', get(ax.axh, 'DefaultLineLineWidth'), @isscalar);
            p.addParameter('color', [0.1 0.1 0.1], @(x) isvector(x) || ischar(x) || isempty(x));
            p.addParameter('alpha', 1, @isscalar);
            p.addParameter('textOffset', 0.1, @isscalar);
            p.addParameter('horizontalAlignment', '', @ischar);
            p.addParameter('verticalAlignment', '', @ischar);
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            label = p.Results.label;
            
            if strcmp(p.Results.which, 'x')
                isX = true;
            else
                isX = false;
            end
            loc = p.Results.location;
            otherSide = p.Results.otherSide;
            extendFromEdge = p.Results.extendFromEdge;
            length = p.Results.length;
            
            yl = get(ax.axh, 'YLim'); dely = yl(2) - yl(1);
            xl = get(ax.axh, 'XLim'); delx = xl(2) - xl(1);
           
            if isX
                x = [loc;loc];
                if ~otherSide
                    y = [yl(2) - dely/10; yl(2)];
                    ypos = yl(2);
                else
                    y = [yl(1); yl(1) + dely/10];
                    ypos = yl(1);
                end
                xpos = loc;
            else
                y = [loc;loc];
                ypos = loc;
                if ~otherSide
                    x = [xl(2) - delx/10; xl(2)];
                    xpos = xl(2);
                else
                    x = [xl(1); xl(1) + delx/10];
                    xpos = xl(1);
                end
            end
            
            hl = line(x, y, 'LineWidth', p.Results.lineWidth, 'Color', p.Results.color, 'YLimInclude', 'off', ...
                'XLimInclude', 'off', 'Clipping', 'off', 'Parent', ax.axhDraw);
            hl.Color(4) = p.Results.alpha;
            AutoAxis.hideInLegend(hl);
            
            ha = p.Results.horizontalAlignment;
            va = p.Results.verticalAlignment;
            
            if isX
                if otherSide
                    % bottom
                    if isempty(ha), ha = 'left'; end
                    va = 'bottom';
                else
                    % top
                    if isempty(ha), ha = 'left'; end
                    va = 'top';
                end
            else
                if otherSide
                    % left
                    ha = 'left';
                    if isempty(va), va = 'bottom'; end
                else
                    % right
                    ha = 'right';
                    if isempty(va), va = 'bottom'; end
                end
            end
                
            
            % label
            ht = text(double(xpos), double(ypos), p.Results.label, ...
                'FontSize', p.Results.fontSize, 'Color', p.Results.labelColor, ...
                'HorizontalAlignment', ha, ...
                'VerticalAlignment', va, ...
                'Parent', ax.axhDraw, 'Interpreter', 'none', 'BackgroundColor', 'none');
            set(ht, 'Clipping', 'off', 'Margin', 0.001);
            
            % anchor both text and line to edge of axis
            if isX
                if otherSide
                    % anchor to bottom of axis
                    ai = AutoAxis.AnchorInfo(hl, PositionType.Bottom, ...
                        ax.axh, PositionType.Bottom, extendFromEdge, ...
                        sprintf('locationIndicator with label ''%s'' to bottom of axis', label));
                    at = AutoAxis.AnchorInfo(ht, PositionType.Bottom, ...
                        ax.axh, PositionType.Bottom, extendFromEdge, ...
                        sprintf('locationIndicator text label ''%s'' to bottom of axis', label));
                else
                    % anchor to top of axis
                    ai = AutoAxis.AnchorInfo(hl, PositionType.Top, ...
                        ax.axh, PositionType.Top, extendFromEdge, ...
                        sprintf('locationIndicator with label ''%s'' to top of axis', label));
                    at = AutoAxis.AnchorInfo(ht, PositionType.Top, ...
                        ax.axh, PositionType.Top, extendFromEdge, ...
                        sprintf('locationIndicator text label ''%s'' to top of axis', label));
                end
                ai2 = AutoAxis.AnchorInfo(hl, PositionType.Height, [], length, 0, sprintf('locationIndicator label ''%s'' height', label));
            else
                if otherSide
                    % anchor to left of axis
                    ai = AutoAxis.AnchorInfo(hl, PositionType.Left, ...
                        ax.axh, PositionType.Left, extendFromEdge, ...
                        sprintf('locationIndicator with label ''%s'' to left of axis', label));
                    at = AutoAxis.AnchorInfo(ht, PositionType.Left, ...
                        ax.axh, PositionType.Left, extendFromEdge, ...
                        sprintf('locationIndicator text label ''%s'' to left of axis', label));
                else
                    % anchor to right of axis
                    ai = AutoAxis.AnchorInfo(hl, PositionType.Right, ...
                        ax.axh, PositionType.Right, extendFromEdge, ...
                        sprintf('locationIndicator label ''%s'' to right of axis', label));
                    at = AutoAxis.AnchorInfo(ht, PositionType.Right, ...
                        ax.axh, PositionType.Right, extendFromEdge, ...
                        sprintf('locationIndicator label ''%s'' to right of axis', label));
                end
                ai2 = AutoAxis.AnchorInfo(hl, PositionType.Width, [], length, 0, sprintf('locationIndicator label ''%s'' width', label));
            end
            ax.addAnchor(ai);
            ax.addAnchor(at);
            ax.addAnchor(ai2);

            % add offset to label
            if p.Results.textOffset ~= 0
                if isX
                    % offset horizontally
                    pos = PositionType.horizontalAlignmentToPositionType(ha);
                    ai = AutoAxis.AnchorInfo(ht, pos, ...
                        xpos, PositionType.Literal, p.Results.textOffset, ...
                        sprintf('locationIndicator label ''%s'' horizontal offset %g from X=%g', ...
                        label, p.Results.textOffset, xpos));
                    ax.addAnchor(ai);
                else
                    pos = PositionType.verticalAlignmentToPositionType(va);
                    ai = AutoAxis.AnchorInfo(ht, pos, ...
                        ypos, PositionType.Literal, p.Results.textOffset, ...
                        sprintf('locationIndicator label ''%s'' vertical offset %g from Y=%g', ...
                        label, p.Results.textOffset, ypos));
                    ax.addAnchor(ai);
                end
            end
                   
            hlist = [hl; ht];
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
            
            % put in top layer
            ax.addHandlesToCollection('markers', hlist);
        end
        
        function [hl, ht] = addLocationIndicatorTop(ax, varargin)
            [hl, ht] = ax.addLocationIndicator('x', varargin{:}); 
        end
        
        function [hl, ht] = addLocationIndicatorBottom(ax, varargin)
            [hl, ht] = ax.addLocationIndicator('x', varargin{:}, 'otherSide', true); 
        end
        
        function [hl, ht] = addLocationIndicatorRight(ax, varargin)
            [hl, ht] = ax.addLocationIndicator('y', varargin{:}); 
        end
        
        function [hl, ht] = addLocationIndicatorLeft(ax, varargin)
            [hl, ht] = ax.addLocationIndicator('y', varargin{:}, 'otherSide', true); 
        end
        
        function hout = addColorbar(ax, varargin)
            import AutoAxis.PositionType;
            import AutoAxis.AnchorInfo;
            
            p = inputParser();
            p.addParameter('cmap', [], @(x) isa(x, 'function_handle') || ismatrix(x) || isempty(x));
            p.addParameter('limits', [], @isvector);
            p.addParameter('labelFormat', '%g', @isstringlike);
            p.addParameter('breakInds', [], @isvector);
            
            % specify one of the following:
            % breakLmitIntervals intervals specifies the values of each band in between the breaks (including the outer limits)
            % breakLabelsPrePost specifies the values below and above each break (excludes the outer limits)
            p.addParameter('breakLimitIntervals', zeros(0, 2), @ismatrix); % nIntervals x 2 array of low, high values
            p.addParameter('breakLabelsPrePost', zeros(0, 2), @ismatrix); % nBreaks x 2 array of pre-break. post-break values 
            
            p.addParameter('breakGapFraction', 0.02, @isscalar); % scale break thickness in fractions of colormap length
            p.addParameter('breakExtentFraction', 2, @isscalar); % scale break width orthogonal to colorbar, in fractions of colormap width
            p.addParameter('breakLineAngle', 15, @isscalar); % angle in degrees away from perpendicular of the lines that make hte break
            
            p.addParameter('fontSize', ax.scaleBarFontSize, @isscalar);
            p.addParameter('location', AutoAxis.FullPositionSpec.outsideRightTop(), @(x) isempty(x) || isa(x, 'AutoAxis.FullPositionSpec')); 
            
            p.addParameter('orientation', 'vertical', @isstringlike);
            p.addParameter('width', NaN, @isscalar);
            p.addParameter('height', NaN, @isscalar);
            p.addParameter('units', '', @isstringlike);

            % in lieu of using manually placed labels, you can use ticks as well. Note that limits must be specified
            p.addParameter('ticks', [], @isvector);
            p.addParameter('tickLabels', [], @(x) isempty(x) || isstringlike(x));

            p.addParameter('labelLimits', [], @(x) isempty(x) || islogical(x));
            p.addParameter('labelLimitsAboveBelow', false, @islogical);
            
            p.addParameter('labelHigh', '', @(x) ischar(x) || isscalar(x));
            p.addParameter('limitHighAppendUnits', true, @islogical);
            p.addParameter('labelLow', '', @(x) ischar(x) || isscalar(x));
            p.addParameter('limitLowAppendUnits', false, @islogical);

            p.addParameter('labelBelow', '', @isstringlike); % used to describe the lower limit
            p.addParameter('labelBelowAlignTicks', true, @islogical); % keep in line with ticks, or align left edge of colorbar
            p.addParameter('labelBelowAppendUnits', false, @islogical);
            
            
            p.addParameter('labelAbove', '', @isstringlike); % used to describe the upper limit; 
            p.addParameter('labelAboveAlignTicks', true, @islogical); % keep in line with ticks, or align left edge of colorbar
            p.addParameter('labelAboveAppendUnits', false, @islogical);
            
            p.addParameter('labelCenter', '', @(x) isstringlike(x) || isscalar(x));
            p.addParameter('labelCenterRotation', 0, @isscalar);
            p.addParameter('labelCenterNextLine', '', @(x) ischar(x) || isscalar(x));
            p.addParameter('labelCenterNextLineOffset', 0, @(x) true);
            p.addParameter('labelCenterAppendUnits', false, @islogical);

            p.addParameter('labelCenterOtherSide', '', @(x) isstringlike(x) || isscalar(x));
            p.addParameter('labelCenterOtherSideColor', ax.labelFontColor);
            p.addParameter('labelCenterOtherSideRotation', 0, @isscalar);
            p.addParameter('labelCenterOtherSideAppendUnits', false, @islogical);

            p.addParameter('labelLeftOtherSide', '', @(x) isstringlike(x) || isscalar(x));
            p.addParameter('labelLeftOtherSideColor', ax.labelFontColor);
            p.addParameter('labelLeftOtherSideRotation', 0, @isscalar);
            p.addParameter('labelLeftOtherSideAppendUnits', false, @islogical);
            
            p.addParameter('labelRightOtherSide', '', @(x) isstringlike(x) || isscalar(x));
            p.addParameter('labelRightOtherSideColor', ax.labelFontColor);
            p.addParameter('labelRightOtherSideRotation', 0, @isscalar);
            p.addParameter('labelRightOtherSideAppendUnits', false, @islogical);

            p.addParameter('backgroundColor', 'none', @ischar);
            p.addParameter('backgroundAlpha', 1, @isscalar);
            p.addParameter('padding', 'tickLabelOffset', @(x) true);
            
            p.parse(varargin{:});

            holdState = ishold(ax.axhDraw);
            hold(ax.axhDraw, 'on');
            
            locationSpec = p.Results.location;
            locationWasEmpty = isempty(locationSpec);
            if locationWasEmpty
                locationSpec.matchSizeY = false;
                locationSpec.matchSizeX = false;
            end

            isVertical = strncmp(p.Results.orientation, 'v', 1);
            labelFormat = string(p.Results.labelFormat);
            units = string(p.Results.units);
            labelFormatWithUnits = labelFormat + " " + units;
            
            
            ticks = p.Results.ticks;
            tickLabels = p.Results.tickLabels;
            labelLimits = p.Results.labelLimits;
            if isempty(labelLimits)
                labelLimits = isempty(ticks);
            end

            cmap = p.Results.cmap;
            if isempty(cmap)
                cmap = colormap(ax.axh);
            end
            
            climits = p.Results.limits;
            if isempty(climits)
                climits = caxis(ax.axh);
            end
            
            if isa(cmap, 'function_handle')
                cmap = cmap(50);
            end
                
            width = p.Results.width;
            height = p.Results.height;
            
            % make the background rect first if needed
            if ~strcmp(p.Results.backgroundColor, 'none')
                hrect = fill([0;1;1;0], [0;0;1;1], p.Results.backgroundColor, ...
                    'EdgeColor', 'none', 'FaceAlpha', p.Results.backgroundAlpha, ...
                    'Parent', ax.axhDraw, 'XLimInclude', 'off', 'YLimInclude', 'off');
                
%                 hrect = rectangle('Position', [0 0 1 1], 'FaceColor', p.Results.backgroundColor, ...
%                     'FaceAlpha', p.Results.backgroundAlpha, ...
%                     'EdgeColor', 'none', 'Parent', ax.axhDraw, 'XLimInclude', 'off', 'YLimInclude', 'off');
            else
                hrect = [];
            end
            
            % cm sizes along bar and bar thickness
            defLong = 3;
            defShort = 0.2;
            
            if isVertical
                if isnan(height) && ~locationSpec.matchSizeY
                    height = defLong;
                end
                if isnan(width)
                    width = defShort;
                end
            else
                if isnan(height)
                    height = defShort;
                end
                if isnan(width) && ~locationSpec.matchSizeX
                    width = defLong;
                end
            end
            
            imgArgs = {'Clipping', 'off', 'Parent', ax.axhDraw, 'XLimInclude', 'off', 'YLimInclude', 'off'};
            
            breakInds = makecol(p.Results.breakInds);
                
            if isempty(breakInds)
                % cmap is N x 3
                if isVertical
                    mat = permute(cmap, [1 3 2]); % puts first color at the top
                    ydir = ax.axh.YDir;
                    if strcmp(ydir, 'reverse')
                        % want last color at the top, but currently at the
                        % bottom
                        mat = flipud(mat);
                    end
                    himg = image(mat, imgArgs{:});
                    ax.axh.YDir = ydir;

                else
                    mat = permute(cmap, [3 1 2]);
                    xdir = ax.axh.XDir;
                    if strcmp(xdir, 'reverse')
                        % want last color at the right, needs to be flipped
                        mat = fliplr(mat);
                    end
                    himg = image(mat, imgArgs{:});
                end
                
                hBreakRects = gobjects(0, 1);
                htbreak = gobjects(0, 1);
            else
                assert(isempty(ticks), 'Ticks not yet supported when using colorbar with breaks, need to implement computed location');
                % handle special case where the colorbar has breaks drawn in it
                
                nBreaks = numel(breakInds);
                breakPrePost = p.Results.breakLabelsPrePost;
                breakLimitIntervals = p.Results.breakLimitIntervals;
                
                assert(issorted(breakInds));
                breakExtentFraction = p.Results.breakExtentFraction;
                
                if isVertical
                    % we can't accurately set the overall height of the colorbar and dynamically set the breaks because this 
                    % requires a simultaneous constraint solver, rather than a DAG of simple position + size updates
                    % however, we allow it because after 2 updates this can often converge
                    
%                     assert(~locationSpec.matchSizeY, 'Match size y for location not supported with breaks'); 

                    mat = permute(cmap, [1 3 2]); % puts first color at the top, rows are colors, 1 col, rgb along 3rd axis
                    ydir = ax.axh.YDir;
                    if strcmp(ydir, 'reverse')
                        % want last color at the top, but currently at the bottom
                        mat = flipud(mat);
                        breakInds = flipud(size(mat, 1) - breakInds + 2);
                        breakPrePost = flipud(breakPrePost);
                    end
                    
                    % loop over the breaks, from top to bottom (high to low inds in the cmap, now low inds to high inds in the mat because of the image display)
                    imgPieces = cell(2*nBreaks + 1, 1);
                    gapRows = ceil(p.Results.breakGapFraction * size(mat, 1));
                    
                    [gapStarts, gapStops] = deal(nan(nBreaks, 1));
                    start = 1;
                    for iB = 1:nBreaks + 1
                        if iB <= nBreaks
                            stop = breakInds(iB)-1;
                        else
                            stop = size(mat, 1);
                        end
                    
                        imgPieces{2*iB-1} = mat(start:stop, :, :);
                        if iB <= nBreaks
                            imgPieces{2*iB} = nan(gapRows, 1, 3, 'like', mat);
                            
                            gapStarts(iB) = stop + gapRows*(iB-1);
                            gapStops(iB) = stop + gapRows*iB + 1;
                        end
                        start = stop + 1;
                    end
                    
                    img = cat(1, imgPieces{:});
                    gap_mask = isnan(img);
                    img(gap_mask) = 1;
                    xval = ax.axh.XLim(2);
                    
                    % initial guess at width, this will be changed by anchor
                    xw = diff(ax.axh.XLim) * 0.02; % xw is the initial width of the colorbar (it will be resized later but the ratio with the gap break lines will be maintained
                    
                    % build with the correct height : width ratio so that the lines have the right angle after the anchor sets its height and width
                    if isnan(height) || isnan(width)
                        yheight = diff(ax.axh.YLim);
                    else
                        yheight = xw * height / width;
                    end
                    
                    if strcmp(ydir, 'reverse')
                        yvals = linspace(ax.axh.YLim(1), ax.axh.YLim(1) + yheight, size(img, 1));
                        ypx_up = yvals(1) - yvals(2);
                    else
                        yvals = linspace(ax.axh.YLim(2) - yheight, ax.axh.YLim(2), size(img, 1));
                        ypx_up = yvals(1) - yvals(2);
                    end

                    himg = image([xval-xw/6, xval + xw/6], yvals, img, imgArgs{:}); % total width will be 3 times diff(xv), and half of the gap width
                    himg.AlphaData = double(~gap_mask(:, :, 1));
                    ax.axh.YDir = ydir;
                    
%                     for iB = 1:nBreaks
%                         ax.anchorAbove(himg(iB), himg(iB+1), 'offset', breakGapSize, 'desc', 'break in colorbar to create gap size');
%                     end

                    % draw the lines defining the gap
                    breakw = xw * breakExtentFraction;
                    xlo = xval - breakw/2;
                    xhi = xval + breakw/2;
                    hBreakRects = gobjects(nBreaks, 1);
                    gapTheta = p.Results.breakLineAngle;
                    gapLineColor = [ 0.1 0.1 0.1 ];
                    if strcmp(ydir, 'reverse')
                        dy = -sind(gapTheta)*breakw;
                        dy_lineOffset = -dy / 4;
                    else
                        dy = sind(gapTheta)*breakw;
                        dy_lineOffset = dy / 4; % offsets both lines outward so as to ensure no gaps in the colorbar image appear
                    end
%                     dy_lineOffset = 0;
                    
                    for iB = 1:nBreaks
                        % top left, top right, bottom right, bottom left, 
                        X = [xlo; xhi; xhi; xlo];
                        
                        yhi = yvals(gapStarts(iB)) - ypx_up/2; 
                        ylo = yvals(gapStops(iB)) + ypx_up/2;
                        % dy/2 creates the gapTheta slant in the line, dy/4 offset shifts the bottom line to intersect the right side of the colorbar (so no white gap is visible)
                        Y = [yhi-dy/2 - dy_lineOffset; yhi+dy/2 - dy_lineOffset; ylo+dy/2 + dy_lineOffset; ylo-dy/2 + dy_lineOffset];
                        C = [gapLineColor; NaN NaN NaN; gapLineColor; NaN NaN NaN];
                        hBreakRects(iB) = patch('XData', X, 'YData', Y, 'FaceVertexCData', C, 'EdgeColor', 'flat', 'FaceColor', 'w', 'FaceAlpha', 1, imgArgs{:}); 
                        
%                         currentBreakRectHeightToWidthRatio = range(Y(:)) / range(X(:))+
%                         hBreakLines(iB, 1) = line([xlo; xhi], [yvals(gapStarts(iB))-dy/2; yvals(gapStarts(iB))+dy/2] - dy/4, 'Color', 'k', imgArgs{:});
%                         hBreakLines(iB, 2) = line([xlo; xhi], [yvals(gapStops(iB))-dy/2; yvals(gapStops(iB))+dy/2] - dy/4, 'Color', 'k', imgArgs{:});
                    end
                    
                    if ~isempty(breakPrePost) || ~isempty(breakLimitIntervals)
                        
                        if ~isempty(breakLimitIntervals)
                            % overwrite the outer limits
                            climits = [breakLimitIntervals(1, 1) breakLimitIntervals(end, 2)]; 
                        
                            % and build breakPrePost from the edges of the intervals
                            temp = breakLimitIntervals';
                            breakPrePost = reshape(temp(2:end-1), 2, [])';
                        end
                        
                        % add break labels above and below the gap
                        htbreak = gobjects(nBreaks, 2);
                        mask = false(nBreaks, 2);
                        if isnumeric(breakPrePost)
                            mask_nan = isnan(breakPrePost);
                            breakPrePost = arrayfun(@(v) sprintf(string(labelFormat), v), breakPrePost);
                            breakPrePost(mask_nan) = "";
                        else
                            breakPrePost = string(breakPrePost);
                        end
                        
                        for iB = 1:nBreaks
                            if strlength(breakPrePost(iB, 1)) > 0
                                htbreak(iB, 1) = text(xhi + breakw/2, yhi + 2*dy, toString(breakPrePost(iB, 1)), 'FontSize', p.Results.fontSize, 'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Margin', 0.01);
                                dyLabel = (breakExtentFraction/2+0.8)*width * sind(gapTheta);
%                                 dyLabel = 0;
                                ax.anchorBelow(htbreak(iB, 1), hBreakRects(iB), 'offset', @(ax, info) ax.tickLabelOffset-dyLabel, 'desc', 'colorbar break label pre below break');
                                mask(iB, 1) = true;
                            end
                            
                            if strlength(breakPrePost(iB, 2)) > 0 % skip if blank (or if was nan)
                                htbreak(iB, 2) = text(xhi + breakw/2, ylo - 2*dy, toString(breakPrePost(iB, 2)), 'FontSize', p.Results.fontSize, 'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Margin', 0.01);
                                ax.anchorAbove(htbreak(iB, 2), hBreakRects(iB), 'offset', @(ax, info) ax.tickLabelOffset/2, 'desc', 'colorbar break label post above break');
                                mask(iB, 2) = true;
                            end
                            
                        end
                        ax.anchorRight(htbreak(mask), himg, 'offset', 'tickLabelOffset', 'desc', 'colorbar break labels right of img');
                    end
                else
                    error('Need to implement horizontal colorbar with breaks');
                end
            end
            
            if ~isnan(width)
                if isempty(breakInds)
                    ax.addAnchor(AnchorInfo(himg, PositionType.Width, [], width, 0, 'colorbar width'));
                else
                    hgroup = cat(1, himg, hBreakRects(:));
                    ax.addAnchor(AnchorInfo(hgroup, PositionType.Width, [], breakExtentFraction*width, 0, 'colorbar+gaps width'));
                end
%                 ax.addAnchor(AnchorInfo(hBreakRects, PositionType.Width, [], 2*width, 0, 'colorbar gap width'));
            end
            if ~isnan(height)
                if isempty(breakInds)
                    ax.addAnchor(AnchorInfo(himg, PositionType.Height, [], height, 0, 'colorbar height'));
                else
                    hgroup = cat(1, himg, hBreakRects(:));
                    ax.addAnchor(AnchorInfo(hgroup, PositionType.Height, [], height, 0, 'colorbar+gaps height'));
                end
%                 for iB = 1:nBreaks
%                     ax.addAnchor(AnchorInfo(hBreakRects(iB), PositionType.Height, [], 2*width*currentBreakRectHeightToWidthRatio, 0, 'colorbar gap height'));
%                 end
            end

            if ~isempty(ticks)
                nTicks = numel(ticks);
                if isempty(tickLabels)
                    tickLabels = arrayfun(@(tick) sprintf(labelFormat, tick), ticks);
                end
            end

            labelHigh = toString(p.Results.labelHigh);
            if labelHigh == ""
                % make limits
                if labelLimits
                    if ~strcmp(units, "") && p.Results.limitHighAppendUnits
                        labelHigh = sprintf(labelFormatWithUnits, climits(2));
                    else
                        labelHigh = sprintf(labelFormat, climits(2)); % no units
                    end
                elseif p.Results.limitHighAppendUnits
                    labelHigh = units;
                end
            elseif p.Results.limitHighAppendUnits
                labelHigh = sprintf("%s %s", labelHigh, units);
            end

            labelLow = toString(p.Results.labelLow);
            if labelLow == ""
                % make limits
                if labelLimits
                    if ~strcmp(units, "") && p.Results.limitLowAppendUnits
                        labelLow = sprintf(labelFormatWithUnits, climits(1));
                    else
                        labelLow = sprintf(labelFormat, climits(1)); % no units
                    end
                elseif p.Results.limitLowAppendUnits
                    labelLow = units;
                end
            elseif p.Results.limitLowAppendUnits
                labelLow = sprintf("%s %s", labelLow, units);
            end

            labelBelow = toString(p.Results.labelBelow);
            if isequal(labelBelow, "") && p.Results.labelLimitsAboveBelow
                if ~strcmp(units, "") && p.Results.limitLowAppendUnits
                    labelBelow = sprintf(labelFormatWithUnits, climits(1));
                else
                    labelBelow = sprintf(labelFormat, climits(1)); % no units
                end
            elseif p.Results.labelBelowAppendUnits
                if ~isequal(labelBelow, "")
                    labelBelow = sprintf("%s %s", labelBelow, units);
                else
                    % no label center so just units with no space
                    labelBelow = units;
                end
            end

            labelCenter = toString(p.Results.labelCenter);
            if p.Results.labelCenterAppendUnits
                if labelCenter ~= ""
                    labelCenter = sprintf("%s %s", labelCenter, units);
                else
                    % no label center so just units with no space
                    labelCenter = units;
                end
            end

            labelCenterOtherSide = toString(p.Results.labelCenterOtherSide);
            if p.Results.labelCenterOtherSideAppendUnits
                if labelCenterOtherSide ~= ""
                    labelCenterOtherSide = sprintf("%s %s", labelCenterOtherSide, units);
                else
                    % no label center other side so just units with no space
                    labelCenterOtherSide = units;
                end
            end

            labelLeftOtherSide = toString(p.Results.labelLeftOtherSide);
            if p.Results.labelLeftOtherSideAppendUnits
                if labelLeftOtherSide ~= ""
                    labelLeftOtherSide = sprintf("%s %s", labelLeftOtherSide, units);
                else
                    % no label left other side so just units with no space
                    labelLeftOtherSide = units;
                end
            end

            labelRightOtherSide = toString(p.Results.labelRightOtherSide);
            if p.Results.labelRightOtherSideAppendUnits
                if labelRightOtherSide ~= ""
                    labelRightOtherSide = sprintf("%s %s", labelRightOtherSide, units);
                else
                    % no label right other side so just units with no space
                    labelRightOtherSide = units;
                end
            end

            labelAbove = toString(p.Results.labelAbove);
            if isequal(labelAbove, "") && p.Results.labelLimitsAboveBelow
                if ~strcmp(units, "") && p.Results.limitHighAppendUnits
                    labelAbove = sprintf(labelFormatWithUnits, climits(2));
                else
                    labelAbove = sprintf(labelFormat, climits(2)); % no units
                end
            elseif p.Results.labelAboveAppendUnits
                if ~isequal(labelAbove, "")
                    labelAbove = sprintf("%s %s", labelAbove, units);
                else
                    % no label center so just units with no space
                    labelAbove = units;
                end
            end
            
            function x = toString(x) 
                if isstring(x), return; end
                if ~ischar(x), x = num2str(x); end
                x = string(x);
            end

            if ~isempty(ticks)
                hticks = gobjects(nTicks, 1);
                for iT = 1:nTicks
                    hticks(iT) = text(0, 0, tickLabels(iT), 'FontSize', p.Results.fontSize, 'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Margin', 0.01);
                end

                % for ticks, we anchor the y values individually based on the height of the colorbar
                rescale = @(x, from, to) (x - from(1)) / (from(2) - from(1)) * (to(2) - to(1)) + to(1);
                ticksFrac = rescale(ticks, climits, [0 1]);
                for iT = 1:nTicks
                    if isVertical
                        ax.addAnchor(AnchorInfo(hticks(iT), PositionType.VCenter, himg, PositionType.VFraction, 0, 'colorbar tick VFraction', fraca=ticksFrac(iT)));
                    else
                        ax.addAnchor(AnchorInfo(hticks(iT), PositionType.HCenter, himg, PositionType.HFraction, 0, 'colorbar tick HFraction', fraca=ticksFrac(iT)));
                    end
                end

                if isVertical
                    ax.anchorRight(hticks, himg, 'offset', 'tickLabelOffset', 'desc', 'colorbar ticks');
                else
                    ax.anchorBelow(hticks, himg, 'offset', 'tickLabelOffset', 'desc', 'colorbar ticks');
                end
            end
            
            if labelLow ~= ""
                hl = text(0, 0, labelLow, 'FontSize', p.Results.fontSize, 'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Margin', 0.01);
                
                if isVertical
                    ax.anchorRightBottomAlign(hl, himg, 'offsetX', 'tickLabelOffset', 'desc', 'colorbar labelLow');
                else
                    ax.anchorBelowLeftAlign(hl, himg, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelLow');
                end
            else
                hl = [];
            end

            if labelHigh ~= ""
                hr = text(0, 0, labelHigh, 'FontSize', p.Results.fontSize, 'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Margin', 0.01);
                if isVertical
                    ax.anchorRightTopAlign(hr, himg, 'offsetX', 'tickLabelOffset', 'desc', 'colorbar label');
                else
                    ax.anchorBelowRightAlign(hr, himg, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar label');
                end
            else
                hr = []; 
            end

            if labelBelow ~= ""
                % anchor labelBelow directly beneath label low
                hbl = text(0, 0, labelBelow, 'FontSize', p.Results.fontSize, 'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Margin', 0.01);
                if p.Results.labelBelowAlignTicks || ~isVertical
                    if isVertical
                        if ~isempty(hl)
                            ax.anchorBelowLeftAlign(hbl, hl, 'offsetX', 'tickLabelOffset', 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelBelow');
                        else
                            ax.anchorBelowRightAlign(hbl, himg, 'offsetX', 'tickLabelOffset', 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelBelow');
                        end
                    else
                        if ~isempty(hl)
                            ax.anchorBelowLeftAlign(hbl, hl, 'offsetX', 0, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelAbove');
                        else
                            ax.anchorBelowLeftAlign(hbl, himg, 'offsetX', 0, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelAbove');
                        end
                    end
                else
                    % align left edge with colorbar, must be vertical
                    ax.anchorBelowLeftAlign(hbl, himg, 'offsetX', 0, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelAbove');
                end
            else
                hbl = [];
            end
            
            if labelCenter ~= ""
                hc = text(0, 0, labelCenter, 'FontSize', p.Results.fontSize, 'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Rotation', p.Results.labelCenterRotation, 'Margin', 0.01);
                if isVertical
                    ax.anchorRightCenterAlign(hc, himg, 'offsetX', 'tickLabelOffset', 'desc', 'colorbar labelCenter');
                else
                    ax.anchorBelowCenterAlign(hc, himg, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelCenter');
                end
            else
                hc = [];
            end

            if labelCenterOtherSide ~= ""
                hcos = text(0, 0, labelCenterOtherSide, 'FontSize', p.Results.fontSize, "Color", p.Results.labelCenterOtherSideColor, ...
                    'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Rotation', p.Results.labelCenterOtherSideRotation, 'Margin', 0.01);
                if isVertical
                    ax.anchorLeftCenterAlign(hcos, himg, 'offsetX', 'tickLabelOffset', 'desc', 'colorbar labelCenterOtherSide');
                else
                    ax.anchorAboveCenterAlign(hcos, himg, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelCenterOtherSide');
                end
            else
                hcos = [];
            end

            if labelLeftOtherSide ~= ""
                hlos = text(0, 0, labelLeftOtherSide, 'FontSize', p.Results.fontSize, "Color", p.Results.labelLeftOtherSideColor, ...
                    'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Rotation', p.Results.labelLeftOtherSideRotation, 'Margin', 0.01);
                if isVertical
                    ax.anchorLeftBottomAlign(hlos, himg, 'offsetX', 'tickLabelOffset', 'desc', 'colorbar labelLeftOtherSide');
                else
                    ax.anchorAboveLeftAlign(hlos, himg, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelLeftOtherSide');
                end
            else
                hlos = [];
            end

            if labelRightOtherSide ~= ""
                hros = text(0, 0, labelRightOtherSide, 'FontSize', p.Results.fontSize, "Color", p.Results.labelRightOtherSideColor, ...
                    'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Rotation', p.Results.labelLeftOtherSideRotation, 'Margin', 0.01);
                if isVertical
                    ax.anchorLeftTopAlign(hros, himg, 'offsetX', 'tickLabelOffset', 'desc', 'colorbar labelRightOtherSide');
                else
                    ax.anchorAboveRightAlign(hros, himg, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelRightOtherSide');
                end
            else
                hros = [];
            end
            
            % anchor labelBelow directly beneath label low
            if labelAbove ~= ""
                hab = text(0, 0, labelAbove, 'FontSize', p.Results.fontSize, 'BackgroundColor', 'none', 'HorizontalAlignment', 'left', 'Parent', ax.axhDraw, 'Margin', 0.01);
                if p.Results.labelAboveAlignTicks || ~isVertical
                    if ~isempty(hr)
                        if isVertical
                            ax.anchorAboveLeftAlign(hab, hr, 'offsetX', 0, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelAbove');
                        else
                            ax.anchorBelowLeftAlign(hab, hr, 'offsetX', 0, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelAbove');
                        end
                    else
                        if isVertical
                            ax.anchorRightAbove(hab, himg, 'offsetX', 'tickLabelOffset', 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelAbove');
                        else
                            ax.anchorBelowLeftAlign(hab, himg, 'offsetX', 0, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelAbove');
                        end
                    end
                else
                    % align left edge with colorbar, must be vertical
                    ax.anchorAboveLeftAlign(hab, himg, 'offsetX', 0, 'offsetY', 'tickLabelOffset', 'desc', 'colorbar labelAbove');
                end
            else
                hab = [];
            end
            
            if ~isempty(p.Results.labelCenterNextLine)
                hOtherLabels = [hl; hc; hcos; hr; hab; hbl];
                hcnl = text(0, 0, toString(p.Results.labelCenterNextLine), 'FontSize', p.Results.fontSize, 'BackgroundColor', 'none', 'Parent', ax.axhDraw, 'Margin', 0.01);
                clear ai;
                if isVertical
                    ax.anchorRightCenterAlign(hcnl, hOtherLabels, 'offsetX', 'tickLabelOffset');
                    ai(1) = AnchorInfo(hcnl, PositionType.Left, hOtherLabels, PositionType.Right, p.Results.labelCenterNextLineOffset, 'colorbar labelCenterNextLine horizontal');
                    ai(2) = AnchorInfo(hcnl, PositionType.VCenter, himg, PositionType.VCenter, 0, 'colorbar labelCenterNextLine vertical');
                else
                    ai(1) = AnchorInfo(hcnl, PositionType.Top, hOtherLabels, PositionType.Bottom, p.Results.labelCenterNextLineOffset, 'colorbar labelCenterNextLine vertical');
                    ai(2) = AnchorInfo(hcnl, PositionType.HCenter, himg, PositionType.HCenter, 0, 'colorbar labelCenterNextLine horizontal');
                end
                ax.addAnchor(ai);
            else
                hcnl = [];
            end
            
            hout.himg = himg;
            hout.hBreakRects = hBreakRects;
            hout.htbreak = htbreak;
            hout.hhi = hr;
            hout.hlo = hl;
            hout.hc = hc;
            hout.hcos = hcos;
            hout.hlos = hlos;
            hout.hros = hros;
            hout.hab = hab;
            hout.hbl = hbl;
            hout.hcnl = hcnl;
            hout.hrect = hrect;

            % anchor everything to inside of the axes
            hall = catfields(hout, asCell=false);
            
            if ~locationWasEmpty
                ai = locationSpec.buildAnchors(hall, ax.axhDraw, 'desc', 'colorbar location');
                ax.addAnchor(ai);
            end

            % anchor the background rectangle around the contents
            if ~strcmp(p.Results.backgroundColor, 'none')
                hgroup = setdiff(hall, hrect, 'stable');
                ax.anchorAroundObjectWithPadding(hrect, hgroup, p.Results.padding, 'desc', 'colorbar background rect');
            end
            
            if ~holdState
                hold(ax.axhDraw, 'off');
            end
        end
            
    end
    
    methods % Anchor objects to axis border
        function anchorToAxis(ax, h, posX, posY, varargin)
            import AutoAxis.PositionType;
            if posX == PositionType.Left
                if posY == PositionType.Top
                    ax.anchorToAxisTopLeft(h, varargin{:});
                else
                    ax.anchorToAxisBottomLeft(h, varargin{:});
                end
            else 
                if posY == PositionType.Top
                    ax.anchorToAxisTopRight(h, varargin{:});
                else
                    ax.anchorToAxisBottomRight(h, varargin{:});
                end
            end
        end
        
        function anchorToAxisIncludeMargin(ax, h, posX, posY, varargin)
            % like align to axis but includes the margin box as well (the outer position)
            import AutoAxis.PositionType;
            if posX == PositionType.Left
                if posY == PositionType.Top
                    ax.anchorToAxisTopLeft(h, 'includeMargin', true, varargin{:});
                else
                    ax.anchorToAxisBottomLeft(h, 'includeMargin', true, varargin{:});
                end
            else 
                if posY == PositionType.Top
                    ax.anchorToAxisTopRight(h, 'includeMargin', true, varargin{:});
                else
                    ax.anchorToAxisBottomRight(h, 'includeMargin', true, varargin{:});
                end
            end
        end

        function anchorAround(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('padding', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            padding = p.Results.padding;
            if isscalar(padding)
                padding = repmat(padding, 4, 1);
            end
            desc = string(p.Results.desc);
            ax.addAnchor(AnchorInfo(h, PositionType.Left, hto, PositionType.Left, padding(1), desc + " (left)", translateDontScale=true));
            ax.addAnchor(AnchorInfo(h, PositionType.Bottom, hto, PositionType.Bottom, padding(2), desc + " (bottom)", translateDontScale=true));
            ax.addAnchor(AnchorInfo(h, PositionType.Right, hto, PositionType.Right, padding(3), desc + " (right)", translateDontScale=false));
            ax.addAnchor(AnchorInfo(h, PositionType.Top, hto, PositionType.Top, padding(4), desc + " (bottom)", translateDontScale=false));
        end
        
        function anchorToAxisTopLeft(ax, h, varargin)
            p = inputParser();
            p.addParameter('outsideX', false, @islogical);
            p.addParameter('outsideY', false, @islogical);
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('includeMargin', false, @islogical);
            p.addParameter('desc', '', @ischar);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            if ~p.Results.outsideY
                ai = AnchorInfo(h, PositionType.Top, ax.axh, PositionType.Top, p.Results.offsetY, p.Results.desc);
            else
                ai = AnchorInfo(h, PositionType.Bottom, ax.axh, PositionType.Top, p.Results.offsetY, p.Results.desc);
            end
            ax.addAnchor(ai);
            if ~p.Results.outsideX
                ai = AnchorInfo(h, PositionType.Left, ax.axh, PositionType.Left, p.Results.offsetX, p.Results.desc);
            else
                ai = AnchorInfo(h, PositionType.Right, ax.axh, PositionType.Left, p.Results.offsetX, p.Results.desc);
            end
            ax.addAnchor(ai);
        end
        
        function anchorToAxisTopRight(ax, h, varargin)
            p = inputParser();
            p.addParameter('outsideX', false, @islogical);
            p.addParameter('outsideY', false, @islogical);
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('includeMargin', false, @islogical);
            
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            if ~p.Results.outsideY
                ai = AnchorInfo(h, PositionType.Top, ax.axh, PositionType.Top, p.Results.offsetY, p.Results.desc);
            else
                ai = AnchorInfo(h, PositionType.Bottom, ax.axh, PositionType.Top, p.Results.offsetY, p.Results.desc);
            end
            ax.addAnchor(ai);
            if ~p.Results.outsideX
                ai = AnchorInfo(h, PositionType.Right, ax.axh, PositionType.Right, p.Results.offsetX, p.Results.desc);
            else
                ai = AnchorInfo(h, PositionType.Left, ax.axh, PositionType.Right, p.Results.offsetX, p.Results.desc);
            end
            ax.addAnchor(ai);
        end
        
        function anchorAxisInsetTopRight(ax, h, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('width', 1, @(x) true);
            p.addParameter('height', 1, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            ax.anchorToAxisTopRight(h, 'offsetX', p.Results.offsetX, 'offsetY', p.Results.offsetY, p.Results.desc);
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Width, [], p.Results.width, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Width, [], p.Results.height, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorToAxisBottomRight(ax, h, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Bottom, ax.axh, PositionType.Bottom, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Right, ax.axh, PositionType.Right, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorToAxisBottomLeft(ax, h, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0,  @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Bottom, ax.axh, PositionType.Bottom, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Left, ax.axh, PositionType.Left, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorToDataLiteral(ax, h, pos, value, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, pos, value, PositionType.Literal, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end

        function anchorAbove(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Bottom, hto, PositionType.Top, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorBelowLeftAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Top, hto, PositionType.Bottom, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Left, hto, PositionType.Left, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorBelow(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Top, hto, PositionType.Bottom, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorBelowRightAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Top, hto, PositionType.Bottom, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Right, hto, PositionType.Right, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorBelowCenterAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Top, hto, PositionType.Bottom, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.HCenter, hto, PositionType.HCenter, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorAboveLeftAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Bottom, hto, PositionType.Top, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Left, hto, PositionType.Left, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorAboveRightAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Bottom, hto, PositionType.Top, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Right, hto, PositionType.Right, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorAboveCenterAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Bottom, hto, PositionType.Top, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.HCenter, hto, PositionType.HCenter, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorRight(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Left, hto, PositionType.Right, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorRightTopAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Top, hto, PositionType.Top, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Left, hto, PositionType.Right, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorRightAbove(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Bottom, hto, PositionType.Top, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Left, hto, PositionType.Right, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorRightBelow(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Top, hto, PositionType.Bottom, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Left, hto, PositionType.Right, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorRightCenterAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.VCenter, hto, PositionType.VCenter, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Left, hto, PositionType.Right, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorRightBottomAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Bottom, hto, PositionType.Bottom, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Left, hto, PositionType.Right, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorLeft(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Right, hto, PositionType.Left, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end

        function anchorLeftAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Left, hto, PositionType.Left, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end

        function anchorRightAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Right, hto, PositionType.Right, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end

        function anchorTopAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Top, hto, PositionType.Top, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end

        function anchorBottomAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Bottom, hto, PositionType.Bottom, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end

        function anchorCenterAlign(ax, h, hto, varargin)
            % horizontal align centers
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.HCenter, hto, PositionType.HCenter, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end

        function anchorVerticalCenterAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.VCenter, hto, PositionType.VCenter, p.Results.offset, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorLeftCenterAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.VCenter, hto, PositionType.VCenter, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Right, hto, PositionType.Left, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end

        function anchorLeftTopAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Top, hto, PositionType.Top, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Right, hto, PositionType.Left, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end

        function anchorLeftBottomAlign(ax, h, hto, varargin)
            p = inputParser();
            p.addParameter('offsetX', 0, @(x) true);
            p.addParameter('offsetY', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ai = AnchorInfo(h, PositionType.Bottom, hto, PositionType.Bottom, p.Results.offsetY, p.Results.desc);
            ax.addAnchor(ai);
            ai = AnchorInfo(h, PositionType.Right, hto, PositionType.Left, p.Results.offsetX, p.Results.desc);
            ax.addAnchor(ai);
        end
        
        function anchorAroundObjectWithPadding(ax, h, haround, padding, varargin)
            p = inputParser();
            p.addParameter('desc', '', @isstringlike);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ax.addAnchor(AnchorInfo(h, PositionType.Left, haround, PositionType.Left, padding));
            ax.addAnchor(AnchorInfo(h, PositionType.Right, haround, PositionType.Right, padding, p.Results.desc, 'translateDontScale', false));
            ax.addAnchor(AnchorInfo(h, PositionType.Top, haround, PositionType.Top, padding));
            ax.addAnchor(AnchorInfo(h, PositionType.Bottom, haround, PositionType.Bottom, padding, p.Results.desc, 'translateDontScale', false));
        end
        
        function anchorWidth(ax, h, width, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.addParameter('preserveAspectRatio', false, @islogical);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ax.addAnchor(AnchorInfo(h, PositionType.Width, [], width, p.Results.offset, p.Results.desc, ...
                'preserveAspectRatio', p.Results.preserveAspectRatio));
        end
        
        function anchorHeight(ax, h, height, varargin)
            p = inputParser();
            p.addParameter('offset', 0, @(x) true);
            p.addParameter('desc', '', @isstringlike);
            p.addParameter('preserveAspectRatio', false, @islogical);
            p.parse(varargin{:});
            
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            ax.addAnchor(AnchorInfo(h, PositionType.Height, [], height, p.Results.offset, p.Results.desc, ...
                'preserveAspectRatio', p.Results.preserveAspectRatio));
        end

        function anchorAsStack(ax, hvec, varargin)
            import AutoAxis.PositionType;
            import AutoAxis.AnchorInfo;
            
            p = inputParser();
            p.addParameter('spacing', 0, @(x) true);
            p.addParameter('stacking', 'vertical', @isstringlike);
            p.addParameter('anchorToFirst', true, @islogical); % if false, hvec(end) will be the root
            p.addParameter('desc', "", @isstringlike)
            p.parse(varargin{:});
            desc = p.Results.desc;
            anchorToFirst = p.Results.anchorToFirst;
            N = numel(hvec);

            if strcmp(p.Results.stacking, 'vertical')
                if anchorToFirst
                    root = 1;
                    anchorToOffset = -1;
                    innerAnchorPosY = PositionType.Top;
                else
                    root = N;
                    anchorToOffset = 1;
                    innerAnchorPosY = PositionType.Bottom;
                end

                % anchor the root to the axis and the rest to the one
                % above/below
                for i = 1:N
                    if i ~= root
                        % anchor to handle above/below
                        ai = AnchorInfo(hvec(i), innerAnchorPosY, hvec(i+anchorToOffset), innerAnchorPosY.flip(), p.Results.spacing, ...
                            sprintf('stack %s %d %s to %d %s', desc, i+anchorToOffset, string(innerAnchorPosY), i, string(innerAnchorPosY.flip())));
                        ax.addAnchor(ai);
                    end                    
                end
            else
                if anchorToFirst
                    root = 1;
                    anchorToOffset = -1;
                    innerAnchorPosX = PositionType.Left;
                else
                    root = N;
                    anchorToOffset = 1;
                    innerAnchorPosX = PositionType.Right;
                end
                
                % anchor the root to the axis and the rest to the one
                % left/right
                for i = 1:N
                    if i ~= root
                        % anchor to text left/left
                        ai = AnchorInfo(hvec(i), innerAnchorPosX, hvec(i+anchorToOffset), innerAnchorPosX.flip(), p.Results.spacing, ...
                            sprintf('stack %s %d %s to %d %s', desc, i+anchorToOffset, string(innerAnchorPosX), i, string(innerAnchorPosX.flip())));
                        ax.addAnchor(ai);
                    end
                end
            end
        end
    end
    
    methods % Anchor specific 
        function addAnchor(ax, infoVec, varargin)
            p = inputParser();
            p.addParameter('collection', "", @isstringlike);
            p.parse(varargin{:});
            
            for iA = 1:numel(infoVec)
                info = infoVec(iA);
                ind = numel(ax.anchorInfo) + 1;
                % sort here so that we can use ismembc later
                if info.isHandleH
                    info.h = sort(info.h);
                    ax.tagHandle(info.h);
                end
                if info.isHandleHa
                    info.ha = sort(info.ha);
                    ax.tagHandle(info.ha);
                end
                ax.anchorInfo(ind) = info;
            end
            % force an update of the dependency graph and reordering of the
            % anchors
            ax.refreshNeeded = true;
            
            collection = string(p.Results.collection);
            if collection ~= ""
                ax.addAnchorToCollection(collection, infoVec);
            end
        end
        
        function deleteAnchors(ax, maskOrAnchors)
            if islogical(maskOrAnchors) || isnumeric(maskOrAnchors)
                mask = maskOrAnchors;
            elseif isa(maskOrAnchors, 'AutoAxis.AnchorInfo')
                mask = ismember(ax.anchorInfo, maskOrAnchors);
            end
            
            ax.anchorInfo(mask) = [];
            ax.refreshNeeded = true;
        end
        
        function update(ax, force)
            if nargin < 2
                force = false;
            end
            if force
                ax.enableUpdate = true;
            end
            if ~ax.enabled || ~ax.enableUpdate
                return;
            end
            
            if ~ishandle(ax.axh)
                %ax.uninstall();
                return;
            end
            
            % complete the reconfiguration process after loading
            if ax.requiresReconfigure
                ax.reconfigurePostLoad();
            end
                    
            %disp('autoaxis.update!');
            gridActive = strcmp(ax.axh.XGrid, 'on') || strcmp(ax.axh.YGrid, 'on') || ...
                strcmp(ax.axh.XMinorGrid, 'on') || strcmp(ax.axh.YMinorGrid, 'on');
            figh = AutoAxis.getParentFigure(ax.axh);
            figColor = get(figh, 'Color');
            backgroundSet = ~isequal(figColor, ax.backgroundColor);
            if gridActive && ~backgroundSet
                % set the grid background if not set
                ax.backgroundColor = ax.gridBackground;
            end
            if gridActive || backgroundSet
                % dont turn the grid off, instead hide the rulers
                axis(ax.axh, 'on');
                box(ax.axh, 'off');
                ax.axh.XRuler.Visible = AutoAxis.bool2onoff(~ax.hideBuiltinAxes);
                ax.axh.YRuler.Visible = AutoAxis.bool2onoff(~ax.hideBuiltinAxes);
                
                % use a dark background with light grid lines
                if ~isempty(ax.backgroundColor)
                    ax.axh.Color = ax.backgroundColor;
                end
                ax.axh.GridColor = ax.gridColor;
                ax.axh.GridAlpha = 1;
                ax.axh.MinorGridColor = ax.minorGridColor;
                ax.axh.MinorGridAlpha = 1;
                ax.axh.MinorGridLineStyle = '-';
                
                figh.InvertHardcopy = 'off';
                % other properties will be set in deferred updates
            else
%                 axis(ax.axh, 'off');
                axis(ax.axh, 'on');
                box(ax.axh, 'off');
                ax.axh.XRuler.Visible = AutoAxis.bool2onoff(~ax.hideBuiltinAxes);
                ax.axh.YRuler.Visible = AutoAxis.bool2onoff(~ax.hideBuiltinAxes);
            end
            if ax.usingOverlay
                axis(ax.axhDraw, 'off');
                set(ax.axhDraw, 'Color', 'none');
            end
            
            % this has the effect of setting TightInset to 0, so that our
            % margins will be the effective margins
            
            ax.updateAutoExponents();
            
            % but we cache the normal ticks for x and y for use by tick
            % bridges and grids
            ax.updateAutoTicks();
            
            ax.updateAutoBridges();

            % update constants converting pixels to paper units
            ax.updateAxisScaling();
            
            if ax.usingOverlay
                % reposition and set limits on overlay axis
                ax.updateOverlayAxisPositioning();
            end
            
            if ax.refreshNeeded
                % re-order .anchorInfo so that dependencies are correctly resolved
                % i.e. order the anchors so that no anchor preceeds anchors
                % it depends upon.
                ax.removeRedundantAnchors();
                ax.prioritizeAnchorOrder();
                ax.refreshNeeded = false;
            end
            
            % recreate the auto axes and scale bars if installed
            if ~isempty(ax.autoAxisX)
                ax.addAutoAxisX('persistUnmatchedArgs', false);
            end
            if ~isempty(ax.autoAxisY)
                ax.addAutoAxisY('persistUnmatchedArgs', false);
            end
            if ~isempty(ax.autoScaleBarX)
                ax.addAutoScaleBarX();
            end
            if ~isempty(ax.autoScaleBarY)
                ax.addAutoScaleBarY();
            end
            
            % restore the X and Y label handles and make them visible since
            % they have a tendency to get hidden (presumably by axis off)
            ax.hXLabel = get(ax.axh, 'XLabel');
            set(ax.hXLabel, 'Visible', 'on', 'FontSize', ax.labelFontSize);
            
            ax.hYLabel = get(ax.axh, 'YLabel');
            set(ax.hYLabel, 'Visible', 'on', 'FontSize', ax.labelFontSize, 'BackgroundColor', 'none');

%             ax.addXLabel();
%             ax.addYLabel();
            
            % remove the background color from the labels
            set([get(ax.axh, 'XLabel'); get(ax.axh, 'YLabel'); get(ax.axh, 'Title')], 'BackgroundColor', 'none');

            if ~isempty(ax.anchorInfo)                
                % dereference all anchors into .anchorInfoDeref
                % i.e. replace collection names with handle vectors
                ax.derefAnchors();
                ax.pruneAnchors();
                
                % query the locations of each handle and put them into the
                % handle to LocationInfo map
                ax.updateLocationCurrentMap();
            
                % process all dereferenced anchors in order
                for i = 1:numel(ax.anchorInfoDeref)
%                     fprintf('Processing %s\n', ax.anchorInfoDeref(i).desc);
                    ax.processAnchor(ax.anchorInfoDeref(i));
                end
                
                % filter out invalid anchors
                valid = [ax.anchorInfoDeref.valid];
                ax.anchorInfo = ax.anchorInfo(valid);
            end
            
            ax.updateAxisStackingOrder();
            
            ax.doDeferredGraphicsUpdates();
            
            % cache the current limits for checking for changes in
            % callbacks
            ax.lastXLim = get(ax.axh, 'XLim');
            ax.lastYLim = get(ax.axh, 'YLim');
           
        end
        
        function removeRedundantAnchors(ax)
            % deduplicate the anchorInfo list. anchors are redundant if
            % they specify the same position of the same handle or handle
            % collection
            
            anchors = ax.anchorInfo;
            nA = numel(anchors);
            maskKeep = AutoAxisUtilities.truevec(nA);
            redundantWith = nanvec(nA);
            for iA = 1:nA
                for iB = iA+1:nA
                    if isequal(anchors(iB).h, anchors(iA).h) && isequal(anchors(iB).pos, anchors(iA).pos) && ...
                            isequal(anchors(iB).applyToPointsWithinLine, anchors(iA).applyToPointsWithinLine)
                        maskKeep(iA) = false;
                        redundantWith(iA) = iB;
                        break;
                    end
                end
            end
            
%             if any(~maskKeep)
%                 warning('Removing %d redundant anchorInfo which set identical position/size of the same handle', nnz(~maskKeep));
%             end
            ax.anchorInfo = ax.anchorInfo(maskKeep);  
        end
        
        function updateAxisStackingOrder(ax)
            % update the visual stacking order for annotations that are
            % added to ensure visual consistency
            
            % intervals, then on top of that markers, then on top of that
            % topLayer
            
            hvec = ax.getHandlesInCollection('intervals');
            if ~isempty(hvec)
                hvec = AutoAxis.filterValid(hvec);
                ax.stackTop(hvec);
            end
            
            hvec = ax.getHandlesInCollection('markers');
            if ~isempty(hvec)
                hvec = AutoAxis.filterValid(hvec);
                ax.stackTop(hvec);
            end
            
            hvec = ax.getHandlesInCollection('scaleBars');
            if ~isempty(hvec)
                hvec = AutoAxis.filterValid(hvec);
                ax.stackTop(hvec);
            end
            
            hvec = ax.getHandlesInCollection('topLayer');
            if ~isempty(hvec)
                hvec = AutoAxis.filterValid(hvec);
                ax.stackTop(hvec);
            end
        end
        
        function stackTop(ax, hvec)
            % hvec is listed in order of their creation, last created
            % is last in the array, but should be at the top of the
            % stacking order, hence flipud.
            % we do this directly because repeated calls to uistack are
            % slow and uistack doesn't preserve the order of the
            % handles passed in sometimes

            children = ax.axh.Children;
            mask = ismember(children, hvec);
%             hvecMask = ismember(hvec, children);
%             children = [flipud(hvec(hvecMask)); children(~mask)];
            children = [children(mask); children(~mask)];
            ax.axh.Children = children;
        end
        
        function stackBottom(ax, hvec)
            % hvec is listed in order of their creation, last created
            % is last in the array, but should be at the top of the
            % stacking order, hence flipud.
            % we do this directly because repeated calls to uistack are
            % slow and uistack doesn't preserve the order of the
            % handles passed in sometimes

            children = ax.axh.Children;
            mask = ismember(children, hvec);
            hvecMask = ismember(hvec, children);
            children = [children(~mask); flipud(hvec(hvecMask))];
            ax.axh.Children = children;
        end
        
%         function stackBelow(h, href)
%             children = ax.axh.Children;
%             maskH = ismember(children, h);
%             maskRef = ismember(children, href);
% 
%             idxH = find(maskH);
%             idxRef = find(maskRef);
%             
%             idxMove = idxH(idxH < idxRef(1));
%             hMove = children(idxMove);
%             
%             if ~isempty(hMove)
%                 idx = 1:numel(children);
%                 
%                 children = children(setdiff(
%             
%             if any(idxH < idxRef(end))
%             children = [flipud(hvec(hvecMask)); children(~mask)];
%             ax.axh.Children = children;
%         end
        
        function pruneAnchors(ax)
            % remove all anchorInfo that refer to invalid handles or
            % anchors. if some valid handles are referenced, keep only the
            % valid ones.
            
            maskKeep = AutoAxisUtilities.truevec(numel(ax.anchorInfoDeref));
            for i = 1:numel(ax.anchorInfoDeref)
                info = ax.anchorInfoDeref(i);
                infoRaw = ax.anchorInfo(i);
                
                validH = ishandle(info.h);
                if all(~validH)
                    maskKeep(i) = false;
                    continue;
                end
                
                if any(~validH)
                    % remove the invalid handles
                    if isequal(info.h, infoRaw.h)
                        infoRaw.h = infoRaw.h(validH);
                    end
                    info.h = info.h(validH);
                end
                
                if ~isempty(info.ha) && ~isscalar(info.ha)
                    validH = ishandle(info.ha);
                    if all(~validH)
                        maskKeep(i) = false;
                        continue;
                    end

                    if any(~validH)
                        % remove the invalid handles
                        if isequal(info.ha, infoRaw.ha)
                            infoRaw.ha = infoRaw.h(validH);
                        end
                        info.ha = info.ha(validH);
                    end
                end
            end
            
%             fprintf('Pruning %d / %d anchors\n', nnz(~maskKeep), numel(maskKeep));
            ax.anchorInfo = ax.anchorInfo(maskKeep);
            ax.anchorInfoDeref = ax.anchorInfoDeref(maskKeep);
        end
        
        function doDeferredGraphicsUpdates(ax) 
            % deferred set rectangle face clipping off
            hvec = ax.getHandlesInCollection('markers');
            for i = 1:numel(hvec)
                if isa(hvec(i), 'matlab.graphics.primitive.Rectangle')
                    if isempty(hvec(i).Face)
                        drawnow;
                    end
                    if isvalid(hvec(i))
                        hvec(i).Face.Clipping = 'off';
                    end
                end
            end
            
            % deferred grid line handling
            if strcmp(ax.axh.YGrid, 'on') && ~isempty(ax.axh.YGridHandle)
                if strcmp(ax.axh.YMinorGrid, 'on')
                    % use thick / thin lines
                    ax.axh.YGridHandle.LineWidth = 1;
                    ax.axh.YGridHandle.MinorLineWidth = 0.5;
                else
                    % use only thin lines
                    ax.axh.YGridHandle.LineWidth = 0.5;
                    ax.axh.YGridHandle.MinorLineWidth = 0.5;
                end
            end
            if strcmp(ax.axh.XGrid, 'on') && ~isempty(ax.axh.XGridHandle)
                if strcmp(ax.axh.XMinorGrid, 'on')
                    ax.axh.XGridHandle.LineWidth = 1;
                    ax.axh.XGridHandle.MinorLineWidth = 0.5;
                else
                    ax.axh.XGridHandle.LineWidth = 0.5;
                    ax.axh.XGridHandle.MinorLineWidth = 0.5;
                end
            end
        end
        
        function updateOverlayAxisPositioning(ax)
            % we want overlay axis to fill the figure,
            % but want the portion overlaying the axis to have the same
            % "limits" as the real axis
            if ax.usingOverlay
                set(ax.axhDraw, 'Position', [0 0 1 1], 'HitTest', 'off', 'Color', 'none'); 
                set(ax.axhDraw, 'YDir', get(ax.axh, 'YDir'), 'XDir', get(ax.axh, 'XDir'));
                axUnits = get(ax.axh, 'Units');
                set(ax.axh, 'Units', 'normalized');
                pos = get(ax.axh, 'Position');

                % convert normalized coordinates of [ 0 0 1 1 ]
                % into what they would be in expanding the
                % limits in data coordinates of axh to fill the figure
                lims = axis(ax.axh);
                normToDataX = @(n) (n - pos(1))/pos(3) * (lims(2) - lims(1)) + lims(1);
                normToDataY = @(n) (n - pos(2))/pos(4) * (lims(4) - lims(3)) + lims(3);
                limsDraw = [ normToDataX(0) normToDataX(1) normToDataY(0) normToDataY(1) ];
                axis(ax.axhDraw, limsDraw);
                
                uistack(ax.axhDraw, 'top');

                set(ax.axh, 'Units', axUnits);
            end
        end
        
        function updateAutoTicks(ax)
            sz = get(ax.axh, 'FontSize');
            fs = 0.1;
            
            if isa(ax.axh, 'matlab.graphics.axis.Axes')
                ax.enableUpdate = false;
                
                xl = ax.axh.XLim;
                xl_manual = strcmp(ax.axh.XLimMode, 'manual');
                yl = ax.axh.YLim;
                yl_manual = strcmp(ax.axh.YLimMode, 'manual');
                
                
                ax.axh.XLim = xl;
                ax.axh.YLim = yl;
                ax.axh.XRuler.FontSize = sz; % set big first
                ax.axh.YRuler.FontSize = sz;
                
                % X TICKS 
                
                % fetch auto ticks
                xManual = strcmp(ax.axh.XTickMode, 'manual');                    
                ticksManual = ax.axh.XTick;
                if xManual 
                    ax.axh.XTickMode = 'auto';
                end
                xminorManual = strcmp(ax.axh.XRuler.MinorTickValuesMode, 'manual');
                ticksMinorManual = ax.axh.XRuler.MinorTickValues;
                if xminorManual
                    ax.axh.XAxis.MinorTickValuesMode = 'auto';
                end
                ax.xAutoTicks = ax.axh.XRuler.TickValues;
                ax.xAutoTickLabels = ax.axh.XRuler.TickLabels;
                ax.xAutoMinorTicks = ax.axh.XRuler.MinorTickValues;
                % restore
                if xManual 
                    ax.axh.XTick = ticksManual;
                end
                if xminorManual
                    ax.axh.XRuler.MinorTickValues = ticksMinorManual;
                end
    
                % Y TICKS
                % set big first
                % fetch ticks
                yManual = strcmp(ax.axh.YTickMode, 'manual');                    
                ticksManual = ax.axh.YTick;
                if yManual 
                    ax.axh.YTickMode = 'auto';
                end
                yminorManual = strcmp(ax.axh.YRuler.MinorTickValuesMode, 'manual');
                ticksMinorManual = ax.axh.YRuler.MinorTickValues;
                if yminorManual
                    ax.axh.YAxis.MinorTickValuesMode = 'auto';
                end
                ax.yAutoTicks = ax.axh.YRuler.TickValues;
                ax.yAutoTickLabels = ax.axh.YRuler.TickLabels;
                ax.yAutoMinorTicks = ax.axh.YRuler.MinorTickValues;
                % restore
                if yManual 
                    ax.axh.YTick = ticksManual;
                end
                if yminorManual
                    ax.axh.YRuler.MinorTickValues = ticksMinorManual;
                end
                
                if ax.hideBuiltinAxes
                    % set small
                    ax.axh.XRuler.FontSize = fs;
                    ax.axh.XLabel.FontSize = sz;

                    ax.axh.YRuler.FontSize = fs;
                    ax.axh.YLabel.FontSize = sz;
                end
                
                % update grid ticks too
                if ~isempty(ax.axh.XGridHandle) && ~xManual
                    ax.axh.XGridHandle.MajorTick = ax.xAutoTicks;
                    ax.axh.XGridHandle.MinorTick = ax.xAutoTicks;
                end
   
                if ~isempty(ax.axh.YGridHandle) && ~yManual
                    ax.axh.YGridHandle.MajorTick = ax.yAutoTicks;
                    ax.axh.YGridHandle.MinorTick = ax.yAutoTicks;
                end
                
                if ~xl_manual
                    ax.axh.XLimMode = 'auto';
                end
                if ~yl_manual
                    ax.axh.YLimMode = 'auto';
                end
                ax.enableUpdate = true;
                
            else
                if strcmp('Orientation', 'vertical')
                    % set big first
                    ax.axh.Ruler.FontSize = sz;
                    % fetch ticks
                    ax.yAutoTicks = ax.axh.Ruler.TickValues;
                    ax.yAutoTickLabels = ax.axh.Ruler.TickLabels;
                    ax.yAutoMinorTicks = ax.axh.Ruler.MinorTickValues;
                    % set small
                    if ax.hideBuiltinAxes
                        ax.axh.Ruler.FontSize = fs;
                    end
                else
                    % set big first
                    ax.axh.Ruler.FontSize = sz;
                    % fetch ticks
                    ax.xAutoTicks = ax.axh.Ruler.TickValues;
                    ax.xAutoTickLabels = ax.axh.Ruler.TickLabels;
                    ax.xAutoMinorTicks = ax.axh.Ruler.MinorTickValues;
                    if ax.hideBuiltinAxes
                        % set small
                        ax.axh.Ruler.FontSize = fs;
                        ax.axh.Label.FontSize = sz;
                    end
                end
                
                if ax.hideBuiltinAxes
                    % set small again
                    ax.axh.YLabel.FontSize = sz;
                    ax.axh.XLabel.FontSize = sz;
                end
            end
        end

        function updateAxisScaling(ax)
            % set x/yDataToUnits scaling from data to paper units
            axh = ax.axh;
            axUnits = get(axh, 'Units');

            set(axh,'Units','centimeters');
            set(axh, 'LooseInset', ax.axisMargin);
            
            axlim = axis(axh);
            axwidth = diff(axlim(1:2));
            axheight = diff(axlim(3:4));
            axpos = AutoAxis.plotboxpos(axh);
            
            ax.xDataToUnits = axpos(3)/axwidth;
            ax.yDataToUnits = axpos(4)/axheight;
            
            % get data to points conversion
            set(axh,'Units','points');
            axpos = get(axh,'Position');
            ax.xDataToPoints = axpos(3)/axwidth;
            ax.yDataToPoints = axpos(4)/axheight;
            
            % get data to pixels conversion
            set(axh,'Units','pixels');
            axpos = get(axh,'Position');
            ax.xDataToPixels = axpos(3)/axwidth;
            ax.yDataToPixels = axpos(4)/axheight;

            % needed for axis data units to normalized figure units conversion
            [ax.axPositionNormUnits, ax.axOuterPositionNormUnits] = AutoAxis.axisPosInNormalizedFigureUnits(axh);
            
            set(axh, 'Units', axUnits);
        end

        function pos = convertNormalizedToDataUnits(aa, pos, treatAsSize)
            axpos = aa.axPositionNormUnits; % our axis inner plot box position in normalized figure units

            %% Get limits
            axlim = axis(aa.axh);
            axwidth = diff(axlim(1:2));
            axheight = diff(axlim(3:4));

            if treatAsSize
                assert(size(pos, 2) == 2);
                pos(:,1) = pos(:,1)*axwidth/axpos(3);
                pos(:,2) = pos(:,2)*axheight/axpos(4);        
            else
                pos(:,1) = (pos(:,1) - axpos(1))*axwidth/axpos(3) + axlim(1);
                pos(:,2) = (pos(:,2) - axpos(2))*axheight/axpos(4) + axlim(3);
                if size(pos, 2) > 2
                    pos(:,3) = pos(:,3)*axwidth/axpos(3);
                    pos(:,4) = pos(:,4)*axheight/axpos(4);        
                end
            end
        end

        function pos = convertDataUnitsToNormalized(aa, pos, treatAsSize)
            axpos = aa.axPositionNormUnits; % our axis inner plot box position in normalized figure units

            %% Get limits
            axlim = axis(aa.axh);
            axwidth = diff(axlim(1:2));
            axheight = diff(axlim(3:4));

            if treatAsSize
                assert(size(pos, 2) == 2);
                pos(:,1) = pos(:,1)/axwidth*axpos(3);
                pos(:,2) = pos(:,2)/axheight*axpos(4);        
            else
                pos(:,1) = (pos(:,1) - axlim(1))/axwidth*axpos(3) + axpos(1);
                pos(:,2) = (pos(:,2) - axlim(3))/axheight*axpos(4) + axpos(2);
                if size(pos, 2) > 2
                    pos(:,3) = pos(:,3)/axwidth*axpos(3);
                    pos(:,4) = pos(:,4)/axheight*axpos(4);        
                end
            end
        end
        
        function tf = get.xReverse(ax)
            tf = strcmp(get(ax.axh, 'XDir'), 'reverse');
        end
        
        function tf = get.yReverse(ax)
            tf = strcmp(get(ax.axh, 'YDir'), 'reverse');
        end
        
        function updateAxisInset(ax)
            % set x/yDataToUnits scaling from data to paper units
            axh = ax.axh;
            axUnits = get(axh, 'Units');

            set(axh,'Units','centimeters');
            set(axh, 'LooseInset', ax.axisMargin);
            
            set(axh, 'Units', axUnits);
        end
        
        function derefAnchors(ax)
            % go through .anchorInfo, dereference all referenced handle
            % collections and property values, and store in
            % .anchorInfoDeref.
            
            ax.anchorInfoDeref = ax.anchorInfo.copy();
            
            for i = 1:numel(ax.anchorInfoDeref)
                info = ax.anchorInfoDeref(i);
                
                % lookup h as handle collection
                if ischar(info.h) || iscell(info.h)
                    info.h = sort(ax.getHandlesInCollection(info.h));
                end
                
                % lookup ha as handle collection
                if ischar(info.ha) || iscell(info.ha)
                    info.ha = sort(ax.getHandlesInCollection(info.ha));
                end
                
                info.margin = derefMargin(info.margin, info.desc);
                
                % look property or eval fn() for .pos or .posa
                if ischar(info.pos)
                    info.pos = ax.(info.pos);
                elseif isa(info.pos, 'function_handle')
                    info.pos = info.pos(ax, info);
                end
                
                if ischar(info.posa)
                    try
                        info.posa = ax.(info.posa);
                    catch
                        warning('Could not find property %s', info.posa);
                        info.posa = 1;
                    end
                elseif isa(info.posa, 'function_handle')
                    try
                        info.posa = info.posa(ax, info);
                    catch
                        warning('Could not evaluate function handle for posa on on anchor %s', info.desc);
                        info.posa = AutoAxis.PositionType.Top;
                    end
                    
                end
            end
            
            function margin_val = derefMargin(margin_spec, desc)
                % lookup margin as property value or function handle
                if isnumeric(margin_spec)
                    margin_val = margin_spec;
                elseif ischar(margin_spec) || isstring(margin_spec)
                    if startsWith(margin_spec, '-')
                        margin_spec = extractAfter(margin_spec, 1);
                        inv = true;
                    else
                        inv = false;
                    end
                    try
                        margin_val = ax.(margin_spec);
                        if inv
                            margin_val = -margin_val;
                        end
                    catch
                        warning('Could not evaluate margin property %s', margin_spec);
                        margin_val = 0;
                    end
                elseif isa(margin_spec, 'function_handle')
                    try
                        margin_val = margin_spec(ax, info);
                    catch
                        warning('Could not evaluate function handle for margin on on anchor %s', desc);
                        margin_val = 0;
                    end
                elseif iscell(margin_spec)
                    margin_val = 0;
                    for iE = 1:numel(margin_spec)
                        margin_val = margin_val + derefMargin(margin_spec{iE}, desc);
                    end
                else
                    error('Could not process AnchorInfo margin');
                end
            end
        end

        function updateLocationCurrentMap(ax)
            % update .mapLocationCurrent (handle --> LocationCurrent)
            % to remove unused handles and add new ones
            
            maskH = [ax.anchorInfoDeref.isHandleH];
            maskHa = [ax.anchorInfoDeref.isHandleHa];
            hvec = unique(cat(1, ax.anchorInfoDeref(maskHa).ha, ax.anchorInfoDeref(maskH).h));
            
            % remove handles no longer needed
            [ax.mapLocationHandles, idxKeep] = intersect(ax.mapLocationHandles, hvec);
            %idxKeep = idxKeep & isvalid(ax.mapLocationHandles);
            ax.mapLocationCurrent = ax.mapLocationCurrent(idxKeep);
            
            % update handles which are considered "dynamic" whose position
            % changes unknowingly between calls to update()
            locCell = ax.mapLocationCurrent;
            for iH = 1:numel(locCell)
                if locCell{iH}.isDynamic
                    locCell{iH}.queryPosition(ax);
                end
            end
            
            % and build a LocationCurrent for missing handles
            missing = AutoAxis.setdiffHandles(hvec, ax.mapLocationHandles);
            for iH = 1:numel(missing)
                ax.setLocationCurrent(missing(iH), ...
                    AutoAxis.LocationCurrent.buildForHandle(missing(iH), ax));
            end
        end
        
        function setLocationCurrent(ax, h, loc)
            [tf, idx] = ismember(h, ax.mapLocationHandles);
            if tf
                ax.mapLocationCurrent{idx} = loc;
            else
                idx = numel(ax.mapLocationHandles) + 1;
                ax.mapLocationHandles(idx) = h;
                ax.mapLocationCurrent{idx} = loc;
            end
        end
        
        function loc = getLocationCurrent(ax, h)
            idx = find(h == ax.mapLocationHandles, 1);
            if isempty(idx)
                loc = AutoAxis.LocationCurrent.empty();
            else
                loc = ax.mapLocationCurrent{idx};
            end
        end
                 
        function valid = processAnchor(ax, info)
            import AutoAxis.PositionType;
            
            if isempty(info.h) || ~all(ishandle(info.h)) || ...
                (info.isHandleHa && ~all(ishandle(info.ha)))
                info.valid = false;
                valid = false;
                
                if ax.debug
                    warning('Invalid anchor %s encountered', info.desc);
                end
                return;
            end
            
            if isempty(info.ha)
                % this anchor specifies a height or width in raw paper units
                % convert the scalar value from paper to data units
                pAnchor = info.posa;
                if info.pos.isX
                    pAnchor = pAnchor / ax.xDataToUnits;
                else
                    pAnchor = pAnchor / ax.yDataToUnits;
                end
            elseif info.posa == PositionType.Literal
                % ha is a literal value in data coordinates
                pAnchor = info.ha;
            else
                % get the position of the anchoring element
                pAnchor = ax.getCurrentPositionData(info.ha, info.posa, info.fraca);
            end

            % add margin to anchor in the correct direction if possible
            if ~isempty(info.ha) && ~isempty(info.margin) && ~isequal(info.margin, NaN)
                offset = 0;
                
                if info.posa == PositionType.Top
                    offset = info.margin / ax.yDataToUnits;
                elseif info.posa == PositionType.Bottom || info.posa == PositionType.VCenter || info.posa == PositionType.VFraction
                    offset = -info.margin / ax.yDataToUnits;
                elseif info.posa == PositionType.Left ||  info.posa == PositionType.HCenter || info.posa == PositionType.HFraction
                    offset = -info.margin / ax.xDataToUnits;
                elseif info.posa == PositionType.Right
                    offset = info.margin / ax.xDataToUnits;
                elseif info.posa == PositionType.Literal && info.pos.isX()
                    offset = info.margin / ax.xDataToUnits;
                elseif info.posa == PositionType.Literal && info.pos.isY()
                    offset = info.margin / ax.yDataToUnits;
                end
                
                if (info.pos.isY() && ax.yReverse) || (info.pos.isX() && ax.xReverse)
                    offset = -offset;
                end
                
                pAnchor = pAnchor + offset;
            end
            
            % and actually set the position of the data
            % this will also create / update the position information
            % in the LocationCurrent for that object
            ax.updatePositionData(info.h, info.pos, pAnchor, info.translateDontScale, info.applyToPointsWithinLine, info.frac, info.preserveAspectRatio);
            
            valid = true;
        end
        
        function prioritizeAnchorOrder(ax)
            % re-order .anchorInfo so that they can be processed in order, 
            % such that later anchors are dependent only on the positions
            % of objects positioned by earlier (and thus already processed)
            % anchors
            
            import AutoAxis.PositionType;
            
            ax.derefAnchors();
            ax.pruneAnchors();
            nA = numel(ax.anchorInfoDeref);
            anchors = ax.anchorInfoDeref;
               
            % gather info about each anchor once up front to save time
            [specifiesSize, isX] = AutoAxisUtilities.nanvec(nA);
            [isHandleH, isHandleHa, translateDontScale, preserveAspectRatio] = AutoAxisUtilities.falsevec(nA);
            posSpecified = repmat(PositionType.Top, nA, 1);
            for iA = 1:nA
                a = anchors(iA);
                specifiesSize(iA) = a.pos.specifiesSize();
                isX(iA) = a.pos.isX();
                isHandleH(iA) = a.isHandleH;
                isHandleHa(iA) = a.isHandleHa;
                posSpecified(iA) = a.pos;
                translateDontScale(iA) = a.translateDontScale;
                preserveAspectRatio(iA) = a.preserveAspectRatio;
            end
            
            % first loop through and build a matrix of direct handle
            % dependendencies to speed things up. 
            [hCat, hWhichPartial] = AutoAxis.TensorUtils.catWhichIgnoreEmpty(1, ax.anchorInfoDeref(isHandleH).h);
            hWhich = AutoAxis.TensorUtils.indicesIntoMaskToOriginalIndices(hWhichPartial, isHandleH);
            [haCat, haWhichPartial] = AutoAxis.TensorUtils.catWhichIgnoreEmpty(1, ax.anchorInfoDeref(isHandleHa).ha);
            haWhich = AutoAxis.TensorUtils.indicesIntoMaskToOriginalIndices(haWhichPartial, isHandleHa);
                
            % now build potential dependency matrix hDepMat(i, j) = true if anchorInfo i uses as an
            % anchor a handle that is positioned/resized by anchorInfo j,
            % such that i may depend on j
            hDepMat = false(nA, nA);
            for iH = 1:numel(hCat)    
                hDepMat(haWhich(haCat == hCat(iH)), hWhich(iH)) = true;
            end
            
            % build an additional potential dependency matrix
            % hGroupSubsumesDepMat(i, j) = true if anchorInfo(i).h is a
            % group that includes (j).h and (j).ha, i.e. where j internally
            % reconfigures the elements of (i).h, such that j should come
            % first and thus i may depend on j
            hGroupSubsumesDepMat = false(nA, nA);
            for iA = 1:nA
                if isHandleH(iA) && numel(anchors(iA).h) > 1
                    for jA = 1:nA
                        if iA ~= jA && anchors(jA).posa ~= PositionType.Literal && ...
                                all(ismember([anchors(jA).h; anchors(jA).ha], anchors(iA).h))
                            hGroupSubsumesDepMat(iA, jA) = true;
                        end
                    end
                end
            end
            
            % build matrix which is true if anchorInfo i positions/sizes the
            % same handles as are positioned/sized by anchorInfo j
            hAffectSameMat = false(nA, nA);
            for iH = 1:numel(hCat)
                hAffectSameMat(hWhich(hCat == hCat(iH)), hWhich(iH)) = true;
            end
            hAffectSameMat = hAffectSameMat & ~eye(nA);
            
            % now loop through and build a list of actually realized dependencies,
            % which depends on hDepMat but also the types of positions that
            % are being specified
            % building the adjacency matrix of a directed acyclic graph
            dependencyMat = false(nA, nA); % does anchor i depend on anchor j
            
%             posSpecifiedFlip = posSpecified.flip();
            for iA = 1:nA
                if ~isHandleH(iA)
                    continue; % must specify a literal since it's already dereferenced
                end
                
                if isHandleHa(iA)
                    % add dependencies on any anchor that determines the
                    % corresponding position (posa) of this anchor's anchor
                    % object (ha)
%                     dependencyMat(iA, :) = ax.findAnchorsSpecifying(anchor.ha, anchor.posa);
                    
                    dependencyMat(iA, :) = ax.anchorInfoDeref.specifiesPosition(posSpecified(iA)) & ...
                        ((hDepMat(iA, :) & ~hGroupSubsumesDepMat(:, iA)') | ... % iA's ha is positioned by jA, but is not internal configuration within a group positioned by jA
                        hGroupSubsumesDepMat(iA, :)); % or, iA's h and ha are within a group positioned by jA, constituting an internal reconfiguration of the group
%                         (posSpecified' == posSpecified(iA) | (posSpecifiedFlip' == posSpecified(iA) & translateDontScale'));
                end
                
                % if this anchor sets the position of h, add dependencies
                % on any anchors which affect the size of the same object so
                % that sizing happens before positioning
                % note: this may be handled by width and height additions to specifiesPosition code...
                if ~specifiesSize(iA)
                    if isX(iA)
                        dependencyMat(iA, :) = dependencyMat(iA, :) | (hAffectSameMat(iA, :)' & specifiesSize & (isX | preserveAspectRatio))';
                    else
                        dependencyMat(iA, :) = dependencyMat(iA, :) | (hAffectSameMat(iA, :)' & specifiesSize & (~isX | preserveAspectRatio))';
                    end
                end

                % add dependencies on anchors such that MarkerDiameter is
                % always specified before size or position
                if posSpecified(iA) ~= PositionType.MarkerDiameter
%                     dependencyMat(i, :) = dependencyMat(i, :) | ax.findAnchorsSpecifying(anchor.h, PositionType.MarkerDiameter);
                    dependencyMat(iA, :) = dependencyMat(iA, :) | (hDepMat(iA, :) & posSpecified' == PositionType.MarkerDiameter);
                end
            end
%             
%             for iA = 1:nA
%                 dependencyMat(iA, iA) = false;
%             end
            
            % then sort the DAG in topographic order
            issuedWarning = false;
            sortedIdx = nan(nA, 1);
            active = true(nA, 1);
            iter = 1;
            while any(active)
                % find an anchor which has no dependencies
                depCount = sum(dependencyMat, 2);
                idxNoDep = find(depCount == 0 & active, 1, 'first');
                if isempty(idxNoDep)
                    if ~issuedWarning
                        warning('AutoAxis:AcyclicDependencies', 'AutoAxis anchor dependency graph is cyclic, anchors may be successfully implemented');
                        issuedWarning = true;
                    end
                    
                    depCount(~active) = Inf;
                    [~, idxNoDep] = min(depCount);
                end
                
                sortedIdx(iter) = idxNoDep;
                
                iter = iter + 1;
                
                % remove dependencies on this anchor
                dependencyMat(:, idxNoDep) = false;
                active(idxNoDep) = false;
            end
            
            % reorder the anchors to resolve dependencies
            ax.anchorInfo = ax.anchorInfo(sortedIdx);
        end
        
        function deleteAnchorsSpecifying(ax, varargin)
            mask = ax.findAnchorsSpecifying(varargin{:});
            ax.deleteAnchors(mask);
        end
        
        function mask = findAnchorsSpecifying(ax, hVec, posType)
            % returns a list of AnchorInfo which could specify position posa of object h
            % this includes 
            import AutoAxis.PositionType;
            
            % first find any anchors that specify any subset of the handles in
            % hVec
            
            % not using strings anymore since we do this all on
            % dereferenced anchors
            if ischar(hVec)
                maskH = cellfun(@(v) isequal(hVec, v), {ax.anchorInfo.h});
            else
                maskH = arrayfun(@(info) info.isHandleH && any(ismember(hVec, info.h)), ax.anchorInfoDeref);
            end
            
            if ~any(maskH) || nargin < 3 % any position valid
                mask = maskH;
                return;
            end
            
            % then search for any directly or indirectly specifying anchors
            info = ax.anchorInfoDeref(maskH); % | maskExact);

            maskTop = [info.pos] == PositionType.Top;
            maskBottom = [info.pos] == PositionType.Bottom;
            maskVCenter = [info.pos] == PositionType.VCenter;
            maskVFraction = [info.pos] == PositionType.VFraction;
            maskLeft = [info.pos] == PositionType.Left;
            maskRight = [info.pos] == PositionType.Right;
            maskHCenter = [info.pos] == PositionType.HCenter;
            maskHFraction = [info.pos] == PositionType.HFraction;
            maskHeight = [info.pos] == PositionType.Height; 
            maskWidth = [info.pos] == PositionType.Width;

            % directly specified anchors
            maskDirect = [info.pos] == posType;

            % placeholder for implicit "combination" specifying anchors,
            % e.g. height and/or bottom specifying the top position
            maskImplicit = false(size(info));

            switch posType
                case PositionType.Top
                    if sum([any(maskBottom) any(maskHeight) any(maskVCenter) any(maskVFraction)]) >= 1 % specifying any of these will affect the top
                        maskImplicit = maskBottom | maskHeight | maskVCenter | maskVFraction; 
                    end

                case PositionType.Bottom
                    if sum([any(maskTop) any(maskHeight) any(maskVCenter) any(maskVFraction)]) >= 1 % specifying any of these will affect the bottom
                        maskImplicit = maskTop | maskHeight | maskVCenter | maskVFraction; 
                    end

                case PositionType.VFraction
                    if sum([any(maskTop) any(maskBottom) any(maskHeight) any(maskVCenter)]) >= 1 % specifying any of these will affect a fractional location in vert axis
                        maskImplicit = maskTop | maskBottom | maskHeight | maskVCenter; 
                    end

                case PositionType.Height
                    if sum([any(maskTop) any(maskBottom) any(maskVCenter) any(maskVFraction)]) >= 2 % specifying any 2 of these will dictate the height, specifying only one will keep the height as is
                        maskImplicit = maskTop | maskBottom | maskVCenter | maskVFraction;
                    end

                case PositionType.VCenter
                    if sum([any(maskTop) any(maskBottom) any(maskHeight) any(maskVFraction)]) >= 1 % specifying any of these will affect the Vcenter
                        maskImplicit = maskTop | maskBottom | maskHeight | maskVFraction;
                    end

                case PositionType.Left
                    if sum([any(maskRight) any(maskWidth) any(maskHCenter) any(maskHFraction)]) >= 1 % specifying any of these will affect the left
                        maskImplicit = maskRight | maskWidth | maskHCenter | maskHFraction;
                    end

                case PositionType.Right
                    if sum([any(maskLeft) any(maskWidth) any(maskHCenter) any(maskHFraction)]) >= 1 % specifying any of these will affect the right
                        maskImplicit = maskLeft | maskWidth | maskHCenter | maskHFraction; 
                    end

                case PositionType.HFraction
                    if sum([any(maskLeft) any(maskRight) any(maskWidth) any(maskHCenter)]) >= 1 % specifying any of these will affect a fractional location in horiz axis
                        maskImplicit = maskLeft | maskRight | maskWidth | maskHCenter; 
                    end

                case PositionType.Width
                    if sum([any(maskLeft) && any(maskRight) any(maskHCenter) any(maskHFraction)]) >= 2 % specifying any 2 of these will dictate the width, specifying only one will keep the width as is
                        maskImplicit = maskLeft | maskRight | maskHCenter | maskHFraction;
                    end

                case PositionType.HCenter
                    if sum([any(maskLeft) && any(maskRight) any(maskWidth) any(maskHFraction)]) >= 1  % specifying any of these will affect the HCenter
                        maskImplicit = maskLeft | maskRight | maskWidth | maskHFraction;
                    end
            end
            
            %info = info(maskDirect | maskImplicit);
            idx = find(maskH);
            idx = idx(maskDirect | maskImplicit);
            mask = false(size(maskH));
            mask(idx) = true;
        end
        
        function pos = getCurrentPositionData(ax, hvec, posType, fraction)
            % grab the specified position / size value for object h, in figure units
            % when hvec is a vector of handles, uses the outer bounding
            % box for the objects instead
            
            import AutoAxis.PositionType;
            import AutoAxis.LocationCurrent;

            if nargin < 4
                fraction = 0;
            end
            
            if isempty(hvec)
                % pass thru for specifying length or width directly
                pos = posa;
                return;
            end
            
            % grab all current values from LocationCurrent for each handle
            clocVec = arrayfun(@(h) ax.getLocationCurrent(h), hvec, 'UniformOutput', false);
            clocVec = cat(1, clocVec{:});

            % and compute aggregate value across all handles
            pos = LocationCurrent.getAggregateValue(ax, clocVec, posType, fraction);
        end
        
        function success = updatePositionData(ax, hVec, posType, value, translateDontScale, applyToPointsWithinLine, fraction, preserveAspectRatio)
            % update the position of handles in vector hVec using the LocationCurrent in 
            % ax.locMap. When hVec is a vector of handles, linearly shifts
            % each object to maintain the relative positions and to
            % shift the bounding box of the objects
            
            value = double(value);
            import AutoAxis.*;
            
            if ~exist('translateDontScale', 'var') || isempty(translateDontScale)
                translateDontScale = true;
            end
            if ~exist('applyToPointsWithinLine', 'var')
                applyToPointsWithinLine = [];
            end
            if ~exist('fraction', 'var')
                fraction = NaN;
            end
            if ~exist('preserveAspectRatio', 'var') || isempty(preserveAspectRatio)
                preserveAspectRatio = false;
            end

            % set success to tru if any position details are actually set             
            if ~isscalar(hVec)
                success = ax.setAggregatePosition(hVec, posType, value, translateDontScale, fraction, preserveAspectRatio);
            else
                % scalar handle, move it directly via the LocationCurrent
                % handle 
                h = hVec(1);
                
                % use the corresponding LocationCurrent for this single
                % object to move the graphics object
                cloc = ax.getLocationCurrent(h);
                posCurrent = LocationCurrent.getAggregateValue(ax, cloc, posType, fraction);

                % handle some derived position types first that can be expressed more simply in terms of the more
                % fundamental position types
                if posType == PositionType.VCenter || posType == PositionType.HCenter
                    fraction = 0.5;
                end
                
                switch posType
                    case {PositionType.VCenter, PositionType.VFraction}
                        posTop = LocationCurrent.getAggregateValue(ax, cloc, PositionType.Top, NaN);
                            
                        if translateDontScale
                            % recast this as shifting the top isntead
                            posTopNew = posTop + (value - posCurrent);
                            success = ax.updatePositionData(h, PositionType.Top, posTopNew, true, applyToPointsWithinLine, NaN);
                        else
                            % stretch in the direction of value
                            if (~ax.yReverse && posTop <= value) || (ax.yReverse && posTop >= value)
                                % desired location is above top, keep bottom in place and move top accordingly
                                assert(fraction ~= 0, 'fraction cannot be 0 when positioning, since the top is anchored and fraction == 0 refers to Bottom')
                                posBottom = LocationCurrent.getAggregateValue(ax, cloc, PositionType.Bottom, NaN);
                                posTopNew = posBottom + (value - posBottom) / fraction;
                                success = ax.updatePositionData(h, PositionType.Top, posTopNew, translateDontScale, applyToPointsWithinLine, NaN);
                            else
                                % keep top in place and move bottom accordingly
                                assert(fraction ~= 1, 'fraction cannot be 1 when positioning, since the top is anchored and fraction == 1 refers to Top')
                                posBottomNew = posTop - (posTop - value) / (1-fraction);
                                success = ax.updatePositionData(h, PositionType.Bottom, posBottomNew, translateDontScale, applyToPointsWithinLine, NaN);
                            end
                        end

                   case {PositionType.HCenter, PositionType.HFraction}
                       posRight = LocationCurrent.getAggregateValue(ax, cloc, PositionType.Right, NaN);
                                
                        if translateDontScale
                            % recast this as shifting the top isntead
                            posRightNew = posRight + (value - posCurrent);
                            success = ax.updatePositionData(h, PositionType.Right, posRightNew, true, applyToPointsWithinLine, NaN);
                        else
                            if (~ax.xReverse && posRight <= value) || (ax.xReverse && posRight >= value)
                                % desired location is right of right, keep left in place and move right accordingly
                                posLeft = LocationCurrent.getAggregateValue(ax, cloc, PositionType.Left, NaN);
                                assert(fraction ~= 0, 'fraction cannot be 0 when positioning, since the left is anchored and fraction == 1 refers to Top')
                                posRightNew = posLeft + (value - posLeft) / fraction;
                                success = ax.updatePositionData(h, PositionType.Right, posRightNew, translateDontScale, applyToPointsWithinLine, NaN);
                            else
                                % keep right in place and move left accordingly
                                assert(fraction ~= 1, 'fraction cannot be 1 when positioning, since the right is anchored and fraction == 1 refers to Right')
                                posLeftNew = posRight - (posRight - value) / (1-fraction);
                                success = ax.updatePositionData(h, PositionType.Left, posLeftNew, translateDontScale, applyToPointsWithinLine, NaN);
                            end
                        end  
                            
                    otherwise
                        % let LocationCurrent handle the simplified positioning of Top/Bottom/Left/Right/Width/Height
                        [success, scale] = cloc.setPosition(ax, posType, value, translateDontScale, applyToPointsWithinLine);

                        if success && preserveAspectRatio
                            if posType == PositionType.Width
                                success = cloc.setPosition(ax, PositionType.Height, cloc.height * scale, translateDontScale, applyToPointsWithinLine);
                            end
                            if posType == PositionType.Height
                                success = cloc.setPosition(ax, PositionType.Width, cloc.width * scale, translateDontScale, applyToPointsWithinLine);
                            end
                        end 
                end
            end
        end

        function success = setAggregatePosition(ax, hVec, posType, value, translateDontScale, fraction, preserveAspectRatio)
            % here we linearly scale / translate the bounding box
            % in order to maintain internal anchoring, scaling should
            % be done before any "internal" anchorings are computed,
            % which should be taken care of by findAnchorsSpecifying
            %
            % note that this will recursively call updatePositionData, so that
            % the corresponding LocationCurrent objects will be updated
            import AutoAxis.PositionType
            success = false;
 
            if posType == PositionType.Height
                % scale everything vertically, but keep existing
                % vcenter (of bounding box) in place
                
                % first find the existing extrema of the objects
                oldTop = ax.getCurrentPositionData(hVec, PositionType.Top);
                oldBottom = ax.getCurrentPositionData(hVec, PositionType.Bottom);
                oldHeight = abs(oldTop - oldBottom);
                if oldHeight == 0
                    warning('Asked to set PositionType.Height for handles with height 0.')
                    return;
                end
                if ax.yReverse
                    newTop = (oldTop+oldBottom) / 2 + value/2;
                        % build affine scaling fns for inner objects
                    newPosFn = @(p) (p-oldTop) * (value / oldHeight) + newTop;
                    newHeightFn = @(h) h * (value / -(oldTop-oldBottom));
                else
                    newBottom = (oldTop+oldBottom) / 2 - value/2;
                        % build affine scaling fns for inner objects
                    newPosFn = @(p) (p-oldBottom) * (value / oldHeight) + newBottom;
                    newHeightFn = @(h) h * (value / (oldTop-oldBottom));
                end
                
                % loop over each object and shift its position by offset
                for i = 1:numel(hVec)
                   h = hVec(i);
                   t = ax.getCurrentPositionData(h, PositionType.Top);
                   he = ax.getCurrentPositionData(h, PositionType.Height);
                   ax.updatePositionData(h, PositionType.Height, newHeightFn(he));
                   ax.updatePositionData(h, PositionType.Top, newPosFn(t));
                end
            
                if preserveAspectRatio
                    oldRight = ax.getCurrentPositionData(hVec, PositionType.Right);
                    oldLeft = ax.getCurrentPositionData(hVec, PositionType.Left);
                    oldWidth = abs(oldRight - oldLeft);

                    newWidth = value / oldHeight * oldWidth;
                    ax.setAggregatePosition(hVec, PositionType.Width, newWidth, translateDontScale, fraction, false);
                end


            elseif posType == PositionType.Width
                % scale everything horizontally, but keep existing
                % hcenter (of bounding box) in place if anchored
                
                % first find the existing extrema of the objects
                oldRight = ax.getCurrentPositionData(hVec, PositionType.Right);
                oldLeft = ax.getCurrentPositionData(hVec, PositionType.Left);
                oldWidth = abs(oldRight - oldLeft);
                if oldWidth == 0
                    warning('Asked to set PositionType.Width for handles with width 0.')
                    return;
                end
                
                if ax.xReverse
                    newRight = (oldRight+oldLeft) / 2 - value/2;
                    % build affine scaling fns
                    newPosFn = @(p) (p-oldRight) * (value / oldWidth) + newRight;
                    newWidthFn = @(w) w * value / oldWidth;
                else
                    newLeft = (oldRight+oldLeft) / 2 - value/2;
                    % build affine scaling fns
                    newPosFn = @(p) (p-oldLeft) * (value / oldWidth) + newLeft;
                    newWidthFn = @(w) w * value / oldWidth;
                end

                % loop over each object and shift its position by offset
                for i = 1:numel(hVec)
                   h = hVec(i);
                   l = ax.getCurrentPositionData(h, PositionType.Left);
                   w = ax.getCurrentPositionData(h, PositionType.Width);
                   ax.updatePositionData(h, PositionType.Width, newWidthFn(w));
                   ax.updatePositionData(h, PositionType.Left, newPosFn(l));
                end

                if preserveAspectRatio
                    oldTop = ax.getCurrentPositionData(hVec, PositionType.Top);
                    oldBottom = ax.getCurrentPositionData(hVec, PositionType.Bottom);
                    oldHeight = abs(oldTop - oldBottom);
                
                    newHeight = value / oldWidth * oldHeight;
                    ax.setAggregatePosition(hVec, PositionType.Height, newHeight, translateDontScale, fraction, false);
                end
                
            elseif translateDontScale
                % simply shift each object by the same offset, thereby shifting the bounding box 
                offset = value - ax.getCurrentPositionData(hVec,  posType, fraction);
                for i = 1:numel(hVec)
                   h = hVec(i);
                   p = ax.getCurrentPositionData(h, posType, fraction);
                   ax.updatePositionData(h, posType, p + offset, translateDontScale, [], fraction);
                end
                
            elseif posType.isX()
                % first find the existing extrema of the objects
                oldLeft = ax.getCurrentPositionData(hVec, PositionType.Left);
                oldRight = ax.getCurrentPositionData(hVec, PositionType.Right);
                
                if posType == PositionType.Right
                    % keep existing Left, change Right to value
                    newRight = value;
                    newLeft = oldLeft;
                elseif posType == PositionType.Left
                    % keep existing Right, scale to set Left value
                    newRight = oldRight;
                    newLeft = value;
                elseif posType == PositionType.HFraction || posType == PositionType.HCenter
                    if posType == PositionType.HCenter
                        fraction = 0.5;
                    end

                    % stretch in the direction of value
                    if (~ax.xReverse && oldRight <= value) || (ax.xReverse && oldRight >= value)
                        % desired location is right of right, keep left in place and move right accordingly
                        assert(fraction ~= 0, 'fraction cannot be 0 when positioning, since the top is anchored and fraction == 0 refers to Bottom')
                        newLeft = oldLeft;
                        newRight = newLeft + (value - newLeft) / fraction;
                    else
                        % keep right in place and move left accordingly
                        assert(fraction ~= 1, 'fraction cannot be 1 when positioning, since the top is anchored and fraction == 1 refers to Top')
                        newRight = oldRight;
                        newLeft = newRight - (newRight - value) / (1-fraction);
                    end
                end
                
                scaleBy = (newRight-newLeft) / (oldRight-oldLeft);
                
                % build affine scaling fns for inner objects
                newLeftFn = @(p) (p-oldLeft)*scaleBy + newLeft;
                newRightFn = @(p) (p-oldLeft)*scaleBy + newLeft;
                
                % loop over each object and shift its position by offset
                for i = 1:numel(hVec)
                   h = hVec(i);
                   t = ax.getCurrentPositionData(h, PositionType.Right);
                   b = ax.getCurrentPositionData(h, PositionType.Left);
                   ax.updatePositionData(h, PositionType.Left, newLeftFn(b), true); % this will purely translate
                   ax.updatePositionData(h, PositionType.Right, newRightFn(t), false); % this will scale
                end
                
            elseif ~posType.isX()
                % first find the existing extrema of the objects
                oldTop = ax.getCurrentPositionData(hVec, PositionType.Top);
                oldBottom = ax.getCurrentPositionData(hVec, PositionType.Bottom);
                
                if posType == PositionType.Top
                    % keep existing bottom, change top to value
                    newTop = value;
                    newBottom = oldBottom;
                elseif posType == PositionType.Bottom
                    % keep existing Top, scale to set bottom to value
                    newTop = oldTop;
                    newBottom = value;
                elseif posType == PositionType.VFraction || posType == PositionType.VCenter
                    if posType == PositionType.VCenter
                        fraction = 0.5;
                    end

                    % stretch in the direction of value
                    if (~ax.yReverse && oldTop <= value) || (ax.yReverse && oldTop >= value)
                        % desired location is above top, keep bottom in place and move top accordingly
                        assert(fraction ~= 0, 'fraction cannot be 0 when positioning, since the top is anchored and fraction == 0 refers to Bottom')
                        newBottom = oldBottom;
                        newTop = newBottom + (value - newBottom) / fraction;
                    else
                        % keep top in place and move bottom accordingly
                        assert(fraction ~= 1, 'fraction cannot be 1 when positioning, since the top is anchored and fraction == 1 refers to Top')
                        newTop = oldTop;
                        newBottom = newTop - (newTop - value) / (1-fraction);
                    end
                end
                
                scaleBy = (newTop-newBottom) / (oldTop-oldBottom);
                
                % build affine scaling fns for inner objects
                newBottomFn = @(p) (p-oldBottom)*scaleBy + newBottom;
                newTopFn = @(p) (p-oldBottom)*scaleBy + newBottom;
                
                % loop over each object and shift its position by offset
                for i = 1:numel(hVec)
                   h = hVec(i);
                   t = ax.getCurrentPositionData(h, PositionType.Top);
                   b = ax.getCurrentPositionData(h, PositionType.Bottom);
                   ax.updatePositionData(h, PositionType.Bottom, newBottomFn(b), true); % this will purely translate
                   ax.updatePositionData(h, PositionType.Top, newTopFn(t), false); % this will scale
                end
                
            else
                error('Not sure how to handle posType %s', posType);
            end

            success = true;
        end
    end
    
    methods(Static)
        function str = bool2onoff(v)
            if v
                str = 'on';
            else
                str = 'off';
            end
        end
        
        function v = linspaceIntercept(start, gap, stop, intercept)
            % v = linspaceIntercept(start, gap, stop, intercept)
            %
            % like (start:gap:stop)', although proceed in either direction from intercept
            % so that the time vector is aligned with intercept, i.e. every entry is
            % equal to intercept + n*gap for integer n

            v = [fliplr((intercept-gap):-gap:start), intercept:gap:stop]';
            v = v(v >= start & v <= stop);
        end
        
        function newSet = setdiffHandles(set, drop)
            maskDrop = AutoAxisUtilities.falsevec(numel(set));
            for iD = 1:numel(drop)
                maskDrop( set == drop(iD) ) = true;
            end
            newSet = set(~maskDrop);
        end
            
        function mask = isvalidSafe(hvec)
            if isempty(hvec)
                mask = [];
            else
                mask = ishandle(hvec);
                mask(mask) = isvalid(hvec(mask));
            end
        end
        
        function hvec = filterValid(hvec)
            if isempty(hvec)
                hvec = gobjects(0, 1);
            else
                hvec = hvec(isvalid(hvec));
            end
        end
        
        function pos = plotboxpos(h)
            %PLOTBOXPOS Returns the position of the plotted axis region
            %
            % pos = plotboxpos(h)
            %
            % This function returns the position of the plotted region of an axis,
            % which may differ from the actual axis position, depending on the axis
            % limits, data aspect ratio, and plot box aspect ratio.  The position is
            % returned in the same units as the those used to define the axis itself.
            % This function can only be used for a 2D plot.  
            %
            % Input variables:
            %
            %   h:      axis handle of a 2D axis (if ommitted, current axis is used).
            %
            % Output variables:
            %
            %   pos:    four-element position vector, in same units as h

            % Copyright 2010 Kelly Kearney

            % Check input

            if nargin < 1
                h = gca;
            end

            if ~ishandle(h) || ~strcmp(get(h,'type'), 'axes')
                error('Input must be an axis handle');
            end

            % Get position of axis in pixels

            currunit = get(h, 'units');
            set(h, 'units', 'pixels');
            axisPos = get(h, 'Position');
            set(h, 'Units', currunit);

            % Calculate box position based axis limits and aspect ratios

            darismanual  = strcmpi(get(h, 'DataAspectRatioMode'),    'manual');
            pbarismanual = strcmpi(get(h, 'PlotBoxAspectRatioMode'), 'manual');

            if ~darismanual && ~pbarismanual

                pos = axisPos;

            else

                dx = diff(get(h, 'XLim'));
                dy = diff(get(h, 'YLim'));
                dar = get(h, 'DataAspectRatio');
                pbar = get(h, 'PlotBoxAspectRatio');

                limDarRatio = (dx/dar(1))/(dy/dar(2));
                pbarRatio = pbar(1)/pbar(2);
                axisRatio = axisPos(3)/axisPos(4);

                if darismanual
                    if limDarRatio > axisRatio
                        pos(1) = axisPos(1);
                        pos(3) = axisPos(3);
                        pos(4) = axisPos(3)/limDarRatio;
                        pos(2) = (axisPos(4) - pos(4))/2 + axisPos(2);
                    else
                        pos(2) = axisPos(2);
                        pos(4) = axisPos(4);
                        pos(3) = axisPos(4) * limDarRatio;
                        pos(1) = (axisPos(3) - pos(3))/2 + axisPos(1);
                    end
                elseif pbarismanual
                    if pbarRatio > axisRatio
                        pos(1) = axisPos(1);
                        pos(3) = axisPos(3);
                        pos(4) = axisPos(3)/pbarRatio;
                        pos(2) = (axisPos(4) - pos(4))/2 + axisPos(2);
                    else
                        pos(2) = axisPos(2);
                        pos(4) = axisPos(4);
                        pos(3) = axisPos(4) * pbarRatio;
                        pos(1) = (axisPos(3) - pos(3))/2 + axisPos(1);
                    end
                end
            end

            % Convert plot box position to the units used by the axis
            temp = axes('Units', 'Pixels', 'Position', pos, 'Visible', 'off', 'parent', get(h, 'parent'));
            set(temp, 'Units', currunit);
            pos = get(temp, 'position');
            delete(temp);
        end
    
        function [pos, outerPos] = axisPosInNormalizedFigureUnits(axh)
            if nargin < 1
                axh = gca;
            end

            if ~ishandle(axh) || ~strcmp(get(axh,'type'), 'axes')
                error('Input must be an axis handle');
            end

            % Get position of axis in pixels
            currunit = get(axh, 'units');
            set(axh, 'Units', 'normalized');
            pos = AutoAxis.plotboxpos(axh);
            outerPos = get(axh, 'OuterPosition');
            set(axh, 'Units', currunit);
        end

        function pos = convertNormFigureUnitsToAxisDataUnits(axh, pos, treatAsSize)
            if nargin < 3
                treatAsSize = false;
            end
            
            axpos = AutoAxis.axisPosInNormalizedFigureUnits(axh);

            %% Get limits
            axlim = axis(axh);
            axwidth = diff(axlim(1:2));
            axheight = diff(axlim(3:4));

            if treatAsSize
                assert(size(pos, 2) == 2);
                pos(:,1) = pos(:,1)*axwidth/axpos(3);
                pos(:,2) = pos(:,2)*axheight/axpos(4);        
            else
                pos(:,1) = (pos(:,1) - axpos(1))*axwidth/axpos(3) + axlim(1);
                pos(:,2) = (pos(:,2) - axpos(2))*axheight/axpos(4) + axlim(3);
                if size(pos, 2) > 2
                    pos(:,3) = pos(:,3)*axwidth/axpos(3);
                    pos(:,4) = pos(:,4)*axheight/axpos(4);        
                end
            end
        end
    end
end
