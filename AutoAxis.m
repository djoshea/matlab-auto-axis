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

    properties
        % units used by all properties and anchor measurements
        % set this before creating any anchors
        units = 'centimeters';
        
        % ticks and tick labels
        tickColor = [0 0 0];
        tickLength = 0.1; % 0.15
        tickLineWidth = 0.5; % not in centimeters, this is stroke width
        tickFontColor
        tickFontSize
        
        % size of marker diameter
        markerWidth = 0.15;
        markerHeight = 0.15;
        markerCurvature = 1; % 0 is rectangle, 1 is circle / oval, or can specify [x y] curvature
        
        % interval thickness. Note that intervals should be thinner than
        % the marker diameter for the vertical alignment to work correctly 
        % Note that interval location and label location is determined by
        % markerDiameter
        intervalThickness = 0.2;
        
        % this controls both the gap between tick lines and tick labels,
        % and between tick labels and axis label offset
        tickLabelOffset = 0.1; % cm
        
        markerLabelOffset = 0.1; % cm
        
        % axis x/y labels
        labelFontSize
        labelFontColor
        
        % plot title
        titleFontSize
        titleFontColor
        
        % scale bar 
        scaleBarThickness = 0.15; % cm
        xUnits = '';
        yUnits = '';
        
        scaleBarLenX
        scaleBarLenY
        
        keepAutoScaleBarsEqual = false;
        scaleBarColor
        scaleBarFontColor
        scaleBarFontSize
        
        debug = false;
        
        gridBackground = [0.92 0.92 0.95]; % copying seaborn
        gridColor = 'w';
        minorGridColor = [0.96 0.96 0.96];
    end
    
    properties(Hidden)
        % gap between axis limits (Position) and OuterPosition of axes
        % only used when axis is not managed by panel
%         axisMargin = [2.5 2.5 1.5 1.5]; % [left bottom right top] 
        axisMargin = [2 1.5 0.75 0.75]; % [left bottom right top] 
        % left: room for y-axis
        % bottom: room for x-axis
        % right: room for y-scale bar and label
        % top: room for title
        
        % spacing between axes and any ticks, lines, marks along each axis
        axisPadding = [0.1 0.1 0.1 0.1]; % [left bottom right top] 
     
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
    
    properties(SetAccess=protected)
        requiresReconfigure = true;
        installedCallbacks = false;
        hListeners = [];
        currentlyRepositioningAxes = false;
        
        hClaListener = [];
    end
      
    methods % Implementations for dependent properties above
        function set.axisPadding(ax, v)
            if numel(v) == 1
                ax.axisPadding = [v v v v];
            elseif numel(v) == 2 % assume horz, vert
                ax.axisPadding = [makerow(v), makerow(v)];
            else
                ax.axisPadding = makerow(v);
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
        
        function set.axisMargin(ax, v)
            if numel(v) == 1
                ax.axisMargin = [v v v v];
            elseif numel(v) == 2 % assume horz, vert
                ax.axisMargin = [makerow(v), makerow(v)];
            else
                ax.axisMargin = makerow(v);
            end
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
    end
        
    properties(Hidden, SetAccess=protected)
        axh % axis handle to which I am attached (client axis)
        
        usingOverlay = false;
        axhDraw % axis handle into which I am drawing (private axis, though may be the same as axh when usingOverlay is false)
        
        anchorInfo % array of AutoAxisAnchorInfo objects that I enforce on update()
        
        % contains a copy of the anchors in anchor info where all handle collection and property value references are looked up 
        % see .derefAnchorInfo
        anchorInfoDeref
        
        refreshNeeded = true;
        
        % map graphics to LocationCurrent objects
        mapLocationHandles
        mapLocationCurrent
        
        collections = struct(); % struct which contains named collections of handles
        
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
        
        xReverse % true/false if xDir is reverse
        yReverse % true/false if yDir is reverse
    end
    
    methods
        function ax = AutoAxis(axh)
            if nargin < 1 || isempty(axh)
                axh = gca;
            end
            
            ax = AutoAxis.createOrRecoverInstance(ax, axh);
        end
    end
    
    methods(Static)
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
            if AutoAxis.isMultipleCall(), return, end;
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
            elseif isa(axh, 'matlab.ui.Figure');
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
        
        function p = getPanelForFigure(figh)
            % return a handle to the panel object associated with figure
            % figh or [] if not associated with a panel
            try
                p = panel.recover(figh);
            catch
                p = [];
            end
%             if isempty(p)
%                 p = panel.recover(figh);
%             end
        end
        
        function axCell = recoverForFigure(figh)
            % recover the AutoAxis instances associated with all axes in
            % figure handle figh
            if nargin < 1, figh = gcf; end;
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
        end
        
        function ax = createOrRecoverInstance(ax, axh)
            % if an instance is stored in this axis' UserData.autoAxis
            % then return the existing instance, otherwise create a new one
            % and install it
            
            axTest = AutoAxis.recoverForAxis(axh);
            if isempty(axTest)
                % not installed, create new
                ax.initializeNewInstance(axh);
                ax.installInstanceForAxis(axh);
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
                disp('deleting auto axis');
                ax.uninstall();
            end
        end
    end
    
    methods(Static)
        function ax = loadobj(ax)
            % defer reconfiguring until we have our figure set as parent
            ax.hListeners = addlistener(ax.axh, {'Parent'}, 'PostSet', @(varargin) ax.reconfigurePostLoad);
        end
    end
    
    methods % Installation, callbacks, tagging, collections
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
            
            sz = get(ax.axh, 'FontSize');
            tc = get(ax.axh, 'DefaultTextColor');
            lc = get(ax.axh, 'DefaultLineColor');
            %ax.tickColor = lc;
            ax.tickFontSize = sz;
            ax.tickFontColor = tc;
            ax.labelFontColor = tc;
            ax.labelFontSize = sz;
            ax.titleFontSize = sz;
            ax.titleFontColor = tc;
            ax.scaleBarColor = lc;
            ax.scaleBarFontSize = sz;
            ax.scaleBarFontColor = tc;

            ax.mapLocationHandles = AutoAxis.allocateHandleVector(0);
            ax.mapLocationCurrent = {};
        end
        
        function restoreDefaults(ax)
            sz = get(0, 'DefaultAxesFontSize');
            tc = get(0, 'DefaultTextColor');
            lc = get(0, 'DefaultLineColor');
            
            ax.tickFontSize = sz;
            ax.tickFontColor = tc;
            ax.labelFontColor = tc;
            ax.labelFontSize = sz;
            ax.titleFontSize = sz;
            ax.titleFontColor = tc;
            ax.scaleBarColor = lc;
            ax.scaleBarFontSize = sz;
            ax.scaleBarFontColor = tc;
        end
             
        function installInstanceForAxis(ax, axh)
            setappdata(axh, 'AutoAxisInstance', ax); 
%             ax.addTitle();
%             ax.addXLabelAnchoredToAxis();
%             ax.addYLabelAnchoredToAxis();
            ax.installCallbacks();
            ax.installClaListener();
        end
        
        function installCallbacks(ax)
            figh = AutoAxis.getParentFigure(ax.axh);
           
            % these work faster than listening on xlim and ylim, but can
            % not update depending on how the axis limits are set
            set(zoom(ax.axh),'ActionPreCallback',@ax.prePanZoomCallback);
            set(pan(figh),'ActionPreCallback',@ax.prePanZoomCallback);
            set(zoom(ax.axh),'ActionPostCallback',@ax.postPanZoomCallback);
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
            hl(3) = addlistener(ax.axh, {'XGrid', 'YGrid', 'XMinorGrid', 'YMinorGrid'}, 'PostSet', @ax.axisCallback);
%             hl(3) = addlistener(ax.axh, {'Parent'}, 'PostSet',
%             @(varargin) ax.installCallbacks); % has issues with
%             AxesLayoutManager and zooming
            ax.hListeners = hl;
            
            p = AutoAxis.getPanelForFigure(figh);
            if ~isempty(p)
                p.setCallback(@(varargin) AutoAxis.figureCallback(figh));
            end
            
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
            
            p = AutoAxis.getPanelForFigure(figh);
            if ~isempty(p)
                p.setCallback([]);
            end
            
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
            ax.uninstallCallbacks();
            ax.uninstallClaListener();
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
            if ax.isMultipleCall(), return, end;
            
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
            if ax.isMultipleCall(), return, end;
            
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
            mask = isvalid(ax.handleTagObjects);
            ax.handleTagObjects = ax.handleTagObjects(mask);
            ax.handleTagStrings = ax.handleTagStrings(mask);
            names = ax.listHandleCollections();
            
            % remove invalid handles from all handle collections
            for i = 1:numel(names)
                hvec = ax.collections.(names{i});
                ax.collections.(names{i}) = hvec(isvalid(hvec));
            end
        end
        
        function addHandlesToCollection(ax, name, hvec)
            % add handles in hvec to the list ax.(name), updating all
            % anchors that involve that handle
            
            if ~isfield(ax.collections, name)
                oldHvec = [];
            else
                oldHvec = ax.collections.(name);
            end

            newHvec = makecol(union(oldHvec, hvec, 'stable'));
            
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
                name = names{i};
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

        function removeHandles(ax, hvec)
            % remove handles from all handle collections and from each
            % anchor that refers to it. Prunes anchors that become empty
            % after pruning.
            if isempty(hvec)
                return;
            end
            
            % remove from tag list
            mask = truevec(numel(ax.handleTagObjects));
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
                if ai.isHandleH % char would be collection reference, ignore
                    ai.h = AutoAxis.setdiffHandles(ai.h, hvec);
                    if isempty(ai.h), remove(i) = true; end
                end
                if ai.isHandleHa % char would be collection reference, ignore
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
        
        function ax = replaceScaleBars(varargin)
            % automatically replace title, axis labels, and ticks

            p = inputParser();
            p.addOptional('axh', gca, @ishandle);
            p.addOptional('xUnits', '', @ischar);
            p.addOptional('yUnits', '', @ischar);
            p.addParameter('axes', 'xy', @ischar);
            p.parse(varargin{:});

            ax = AutoAxis(p.Results.axh);
            %axis(p.Results.axh, 'off');
            ax.xUnits = p.Results.xUnits;
            ax.yUnits = p.Results.yUnits;
            if ismember('x', p.Results.axes)
                ax.addAutoScaleBarX();
            end
            if ismember('y', p.Results.axes)
                ax.addAutoScaleBarY();
            end
            ax.addTitle();
            
            ax.axisMarginLeft = 0.1;
            ax.axisMarginBottom = 1;
            ax.update();
            ax.installCallbacks();
        end
    end

    methods % Annotation configuration
        function reset(ax)
        	ax.removeAutoAxisX();
            ax.removeAutoAxisY();
            ax.removeAutoScaleBarX();
            ax.removeAutoScaleBarY();
            
            % delete all generated content
            if isfield(ax.collections, 'generated')
                generated = ax.collections.generated;
                ax.removeHandles(generated);
                delete(generated(isvalid(generated)));
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
        end
        
        function gridOff(ax)
            ax.axh.XGrid = 'off';
            ax.axh.YGrid = 'off';
            ax.axh.XMinorGrid = 'off';
            ax.axh.YMinorGrid = 'off';
        end
        
        function clearX(ax)
            ax.removeAutoAxisX();
            ax.removeAutoScaleBarX();
            
            % delete all generated content
            if isfield(ax.collections, 'belowX')
                generated = ax.collections.belowX;
                ax.removeHandles(generated);
                delete(generated(isvalid(generated)));
            end
            
            ax.xlabel('');
            
            % and update to prune anchors
            ax.update();
        end
        
        function clearY(ax)
            ax.removeAutoAxisY();
            ax.removeAutoScaleBarY();
            
            % delete all generated content
            if isfield(ax.collections, 'leftY')
                generated = ax.collections.leftY;
                ax.removeHandles(generated);
                delete(generated(isvalid(generated)));
            end
            
            ax.ylabel('');
            
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
            p.addOptional('xlabel', '', @ischar);
            p.addParameter('anchorToAxis', false, @islogical);
            p.parse(varargin{:});
            
            % remove any existing anchors with XLabel
            ax.removeHandles(get(ax.axh, 'XLabel'));
            
            if ~isempty(p.Results.xlabel)
                xlabel(ax.axh, p.Results.xlabel);
            end
            
            import AutoAxis.PositionType;
            
%             if ~isempty(ax.hXLabel)
%                 return;
%             end
            
            hlabel = get(ax.axh, 'XLabel');
            set(hlabel, 'Visible', 'on', ...
                'FontSize', ax.labelFontSize, ...
                'Margin', 0.1, ...
                'Color', ax.labelFontColor, ...
                'HorizontalAlign', 'center', ...
                'VerticalAlign', 'top');
            if ax.debug
                set(hlabel, 'EdgeColor', 'r');
            end
            
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
            ax.addAnchor(ai);
            
            % and in the middle of the x axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.HCenter, ...
                ax.axh, PositionType.HCenter, 0, 'xLabel centered on x axis');
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
            p.addOptional('ylabel', '', @ischar);
            p.addParameter('anchorToAxis', false, @islogical);
            p.parse(varargin{:});
            
            % remove any existing anchors with XLabel
            ax.removeHandles(get(ax.axh, 'YLabel'));
            
            if ~isempty(p.Results.ylabel)
                ylabel(ax.axh, p.Results.ylabel);
            end
            
            hlabel = get(ax.axh, 'YLabel');
            set(hlabel, 'Visible', 'on', ...
                'FontSize', ax.labelFontSize, ...
                'Rotation', 90, 'Margin', 0.1, 'Color', ax.labelFontColor, ...
                'HorizontalAlign', 'center', 'VerticalAlign', 'bottom');
            if ax.debug
                set(hlabel, 'EdgeColor', 'r');
            end

            if p.Results.anchorToAxis
                % anchor directly left of axis
                ai = AutoAxis.AnchorInfo(hlabel, PositionType.Right, ...
                    ax.axh, PositionType.Left, 'axisLabelOffsetLeft', ...
                    'ylabel left of axis');
            else
                % anchor below the belowX objects
                ai = AutoAxis.AnchorInfo(hlabel, PositionType.Right, ...
                    'leftY', PositionType.Left, 'decorationLabelOffsetLeft', ...
                    'ylabel left of leftY');
            end
            
            ax.addAnchor(ai);
            
            % and in the middle of the y axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.VCenter, ...
                ax.axh, PositionType.VCenter, 0, 'yLabel centered on y axis');
            ax.addAnchor(ai);
            
            ax.hYLabel = hlabel;
        end
        
        function ylabel(ax, varargin)
            if nargin == 2
                str = varargin{1};
            else
                str = sprintf(varargin{:});
            end
            ylabel(ax.axh, str);
        end
        
        function addAutoAxisX(ax, varargin)
            import AutoAxis.PositionType;
            if ~isempty(ax.autoAxisX)
                firstTime = false;
                
                % delete the old axes
                try delete(ax.autoAxisX.h); catch, end
                remove = ax.autoAxisX.h;
            else
                firstTime = true;
                remove = [];
            end
            
            hlist = ax.addTickBridge('x', ...
                'useAutoAxisCollections', true, ...
                'addAnchors', firstTime);
            ax.autoAxisX.h = hlist;
            
            % remove after the new ones are added by addTickBridge
            % so that anchors aren't deleted
            ax.removeHandles(remove);
            
            if firstTime
                ax.addXLabel();
            end
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
            import AutoAxis.PositionType;
            if ~isempty(ax.autoAxisY)
                firstTime = false;
                % delete the old objects
                try
                    delete(ax.autoAxisY.h);
                catch
                end
                
                % remove from handle collection
                remove = ax.autoAxisY.h;
            else
                firstTime = true;
                remove = [];
            end
            
            firstTime = true;
            
            hlist = ax.addTickBridge('y', ...
                'useAutoAxisCollections', true, ...
                'addAnchors', firstTime);
            ax.autoAxisY.h = hlist;
            
            % remove after the new ones are added by addTickBridge
            % so that anchors aren't deleted
            ax.removeHandles(remove);
            
            if firstTime
                ax.addYLabel();
            end
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
        
        function addAutoScaleBarX(ax, varargin)
            p = inputParser;
            p.addParameter('units', ax.xUnits, @ischar);
            p.addParameter('length', ax.scaleBarLenX, @isscalar);
            p.parse(varargin{:});
            
            ax.xUnits = p.Results.units;
            ax.scaleBarLenX = p.Results.length;
            
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
            
            ax.autoScaleBarX.h = ax.addScaleBar('x', ...
                'units', ax.xUnits, 'length', ax.scaleBarLenX, ...
                'useAutoScaleBarCollection', true, 'addAnchors', firstTime);
            
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
            p.addParameter('units', ax.yUnits, @ischar);
            p.addParameter('length', ax.scaleBarLenY, @isscalar);
            p.parse(varargin{:});
            
            ax.yUnits = p.Results.units;
            ax.scaleBarLenY = p.Results.length;
            
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
            
            ax.autoScaleBarY.h = ax.addScaleBar('y', 'units', ax.yUnits, ...
                'useAutoScaleBarCollections', true, 'addAnchors', firstTime, ...
                'length', ax.scaleBarLenY);
            
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
            p.addOptional('title', '', @ischar);
            p.parse(varargin{:});
            
            if ~isempty(p.Results.title)
                title(ax.axh, p.Results.title);
            end
            
            hlabel = get(ax.axh, 'Title');
            set(hlabel, 'FontSize', ax.titleFontSize, 'Color', ax.titleFontColor, ...
                'Margin', 0.1, 'HorizontalAlign', 'center', ...
                'VerticalAlign', 'bottom');
            if ax.debug
                set(hlabel, 'EdgeColor', 'r');
            end
            
            % anchor title vertically above axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.Bottom, ...
                ax.axh, PositionType.Top, ...
                'axisPaddingTop', 'Title above axis');
            ax.addAnchor(ai);
            
            % anchor title horizontally centered on axis
            ai = AutoAxis.AnchorInfo(hlabel, PositionType.HCenter, ...
                ax.axh, PositionType.HCenter, ...
                0, 'Title centered on axis');
            ax.addAnchor(ai);
            
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
        
        function addTicklessLabels(ax, varargin)
            % add labels to x or y axis where ticks would appear but
            % without the tick marks, i.e. positioned labels
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @ischar);
            p.addParameter('tick', [], @isvector);
            p.addParameter('tickLabel', {}, @(x) isempty(x) || iscellstr(x));
            p.addParameter('tickAlignment', [], @(x) isempty(x) || iscellstr(x));
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh;
            useX = strcmp(p.Results.orientation, 'x');
            if ~isempty(p.Results.tick)
                ticks = p.Results.tick;
                labels = p.Results.tickLabel;
            else
                ticks = get(axh, 'XTick');
                labels = get(axh, 'XTickLabel');
                labels = strtrim(mat2cell(labels, ones(size(labels,1),1), size(labels, 2)));
            end
            
            if isempty(labels)
                labels = sprintfc('%g', ticks);
            end
            
            if isempty(p.Results.tickAlignment)
                if useX
                    tickAlignment = repmat({'center'}, numel(ticks), 1);
                else
                    tickAlignment = repmat({'middle'}, numel(ticks), 1);
                end
            else
                tickAlignment = p.Result.tickAlignment;
            end
            
            color = ax.tickColor;
            fontSize = ax.tickFontSize;
            
            % generate line, ignore length here, we'll anchor that later
            if useX
                xtext = ticks;
                ytext = 0 * ticks;
                ha = tickAlignment;
                va = repmat({'top'}, numel(ticks), 1);
                offset = 'axisPaddingBottom';
                
            else
                % y axis labels
                xtext = 0* ticks;
                ytext = ticks;
                ha = repmat({'right'}, numel(ticks), 1);
                va = tickAlignment;
                offset = 'axisPaddingLeft';
            end
            
            ht = AutoAxis.allocateHandleVector(numel(ticks));
            for i = 1:numel(ticks)
                ht(i) = text(xtext(i), ytext(i), labels{i}, ...
                    'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                    'Interpreter', 'none', 'Parent', ax.axhDraw);
            end
            set(ht, 'Clipping', 'off', 'Margin', 0.1, 'FontSize', fontSize, ...
                    'Color', color);
                
            if ax.debug
                set(ht, 'EdgeColor', 'r');
            end
            
            % build anchor for labels to axis
            if useX
                ai = AnchorInfo(ht, PositionType.Top, ax.axh, ...
                    PositionType.Bottom, offset, 'xTicklessLabels below axis');
                ax.addAnchor(ai);
            else
                ai = AnchorInfo(ht, PositionType.Right, ...
                    ax.axh, PositionType.Left, offset, 'yTicklessLabels left of axis');
                ax.addAnchor(ai);
            end
            
            % add handles to handle collections
            ht = makecol(ht);
            if useX
                ax.addHandlesToCollection('belowX', ht);
            else
                ax.addHandlesToCollection('leftY', ht);
            end
            
            % list as generated content
            ax.addHandlesToCollection('generated', ht);
        end
        
        function [hlist] = addTickBridge(ax, varargin)
            % add line and text objects to the axis that replace the normal
            % axes
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @ischar);
            p.addParameter('tick', [], @isvector);
            p.addParameter('tickLabel', {}, @(x) isempty(x) || iscellstr(x));
            p.addParameter('tickAlignment', [], @(x) isempty(x) || iscellstr(x));
            p.addParameter('tickRotation', 0, @isscalar);
            p.addParameter('useAutoAxisCollections', false, @islogical);
            p.addParameter('addAnchors', true, @islogical);
            p.addParameter('otherSide', false, @islogical);
            
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh; %#ok<*PROPLC,*PROP>
            useX = strcmp(p.Results.orientation, 'x');
            otherSide = p.Results.otherSide;
            
            if ~isempty(p.Results.tick)
                ticks = p.Results.tick;
                labels = p.Results.tickLabel;
            else
                if useX
                    ticks = get(axh, 'XTick');
                else
                    ticks = get(axh, 'YTick');
                end
                labels = {};
                %labels = arrayfun(@num2str, ticks, 'UniformOutput', false);
%                 labels = strtrim(mat2cell(labels, ones(size(labels,1),1), size(labels, 2)));
            end
            
            if isempty(labels)
                ticks(abs(ticks) < 10*eps) = 0;
                labels = sprintfc('%g', ticks);
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
            
            ticks = sort(ticks);
            
%             tickLen = ax.tickLength;
            lineWidth = ax.tickLineWidth;
            tickRotation = p.Results.tickRotation;
            color = ax.tickColor;
            fontSize = ax.tickFontSize;
            
            % generate line, ignore length here, we'll anchor that later
            if useX
                hi = 1;
                lo = 0;
                
                % to get nice line caps on the edges, merge the edge ticks
                % with the bridge
                if numel(ticks) > 2
                    xvals = [makerow(ticks(2:end-1)); makerow(ticks(2:end-1))];
                    yvals = repmat([hi; lo], 1, numel(ticks)-2);
                end
                
                xbridge = [ticks(1); ticks(1); ticks(end); ticks(end)];
                ybridge = [lo; hi; hi; lo];
                
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
                lo = 0;
                hi = 1;
                
                if numel(ticks) > 2
                    yvals = [makerow(ticks(2:end-1)); makerow(ticks(2:end-1))];
                    xvals = repmat([hi; lo], 1, numel(ticks)-2);
                end
                
                xbridge = [lo; hi; hi; lo];
                ybridge = [ticks(1); ticks(1); ticks(end); ticks(end)];
                
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
            if numel(ticks) > 2
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
            for i = 1:numel(ticks)
                hl(i) = text(xtext(i), ytext(i), labels{i}, ...
                    'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                    'Rotation', tickRotation, ...
                    'Parent', ax.axhDraw, 'Interpreter', 'none');
            end
            set(hl, 'Clipping', 'off', 'Margin', 0.1, 'FontSize', fontSize, ...
                    'Color', color);
                
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
                    hbRef = 'autoAxisXBridge';
                    htRef = 'autoAxisXTicks';
                    hlRef = 'autoAxisXTickLabels';
                else
                    ax.addHandlesToCollection('autoAxisYBridge', hb);
                    if ~isempty(ht)
                        ax.addHandlesToCollection('autoAxisYTicks', ht);
                    end
                    ax.addHandlesToCollection('autoAxisYTickLabels', hl);
                    hbRef = 'autoAxisYBridge';
                    htRef = 'autoAxisYTicks';
                    hlRef = 'autoAxisYTickLabels';
                end
            else
                hbRef = hb;
                htRef = ht;
                hlRef = hl;
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
                        ai = AnchorInfo(hbRef, PositionType.Top, ax.axh, ...
                            PositionType.Bottom, offset, 'xTickBridge below axis');
                        ax.addAnchor(ai);
                        % anchor the height of the bridge which includes
                        % the outermost ticks
                        ai = AnchorInfo(hbRef, PositionType.Height, ...
                            [], 'tickLength', 0, 'xTickBridge height for outermost ticks');
                        ax.addAnchor(ai);
                        
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
                            hbRef, PositionType.Bottom, ax.tickLabelOffset, ...
                            'xTickLabels below ticks');
                        ax.addAnchor(ai);
                    else
                        % top side
                        ai = AnchorInfo(hbRef, PositionType.Bottom, ax.axh, ...
                            PositionType.Top, offset, 'xTickBridge above axis');
                        ax.addAnchor(ai);
                        ai = AnchorInfo(hbRef, PositionType.Height, ...
                            [], 'tickLength', 0, 'xTickBridge height for outermost ticks');
                        ax.addAnchor(ai);
                        
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
                            hbRef, PositionType.Top, ax.tickLabelOffset, ...
                            'xTickLabels above ticks');
                        ax.addAnchor(ai);
                    end

                else
                    if ~otherSide
                        ai = AnchorInfo(hbRef, PositionType.Right, ...
                            ax.axh, PositionType.Left, offset, 'yTickBridge left of axis');
                        ax.addAnchor(ai);
                        ai = AnchorInfo(hbRef, PositionType.Width, ...
                            [], 'tickLength', 0, 'yTickBridge width for outermost ticks');
                        ax.addAnchor(ai);
                        
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
                            hbRef, PositionType.Left, ax.tickLabelOffset, ...
                            'yTickLabels left of ticks');
                        ax.addAnchor(ai);
                    else
                        % right side
                        ai = AnchorInfo(hbRef, PositionType.Left, ...
                            ax.axh, PositionType.Right, offset, 'yTickBridge right of axis');
                        ax.addAnchor(ai);
                        ai = AnchorInfo(hbRef, PositionType.Width, ...
                            [], 'tickLength', 0, 'yTickBridge width for outermost ticks');
                        ax.addAnchor(ai);
                        
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
                            hbRef, PositionType.Right, ax.tickLabelOffset, ...
                            'yTickLabels right of ticks');
                        ax.addAnchor(ai);
                    end
                end
            end
            
            % add handles to handle collections
            hlist = cat(1, makecol(ht), makecol(hl), hb);
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
            p.addOptional('label', '', @ischar);
            p.addParameter('labelColor', ax.tickFontColor, @(x) isvector(x) || isempty(x) || ischar(x));
            p.addParameter('marker', 'o', @(x) isempty(x) || ischar(x));
            p.addParameter('markerColor', [0.1 0.1 0.1], @(x) isvector(x) || ischar(x) || isempty(x));
            p.addParameter('alpha', 1, @isscalar);
            p.addParameter('interval', [], @(x) isempty(x) || isvector(x)); % add a rectangle interval behind the marker to indicate a range of locations
            p.addParameter('intervalColor', [0.5 0.5 0.5], @(x) isvector(x) || ischar(x) || isempty(x));
            p.addParameter('textOffsetY', 0, @isscalar);
            p.addParameter('textOffsetX', 0, @isscalar);
            p.addParameter('horizontalAlignment', 'center', @ischar);
            p.addParameter('verticalAlignment', 'top', @ischar);
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            label = p.Results.label;
            
            yl = get(ax.axh, 'YLim');
            
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
            
            % plot marker
%             holdState = ishold(ax.axhDraw);
%             hold(ax.axhDraw, 'on');
%             hm = plot(ax.axhDraw, p.Results.x, yl(1), 'Marker', p.Results.marker, ...
%                 'MarkerSize', 1, 'MarkerFaceColor', p.Results.markerColor, ...
%                 'MarkerEdgeColor', 'none', 'YLimInclude', 'off', 'XLimInclude', 'off', ...
%                 'Clipping', 'off');   
            
            hm = rectangle('Position', [p.Results.x - ax.markerWidth/2, yl(1) ax.markerWidth, ax.markerHeight], 'Curvature', ax.markerCurvature, ...
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
            ai = AutoAxis.AnchorInfo(hm, PositionType.Height, ...
                [], 'markerHeight', 0, sprintf('markerX label ''%s'' height', label));
            ax.addAnchor(ai);
            
%             % anchor marker width
            ai = AutoAxis.AnchorInfo(hm, PositionType.Width, ...
                [], 'markerWidth', 0, sprintf('markerX label ''%s'' width', label));
            ax.addAnchor(ai);
            
            % anchor marker to axis
            ai = AutoAxis.AnchorInfo(hm, PositionType.Top, ...
                ax.axh, PositionType.Bottom, 'axisPaddingBottom', ...
                sprintf('markerX ''%s'' to bottom of axis', label));
            ax.addAnchor(ai); 
            
            % anchor label to bottom of axis factoring in marker size,
            % this makes it consistent with how addIntervalX's label is
            % anchored
            offY = p.Results.textOffsetY;
            pos = PositionType.verticalAlignmentToPositionType(p.Results.verticalAlignment);  
            ai = AutoAxis.AnchorInfo(ht, pos, ...
                ax.axh, PositionType.Bottom, @(ax, varargin) ax.axisPaddingBottom + ax.markerHeight + ax.markerLabelOffset + offY, ...
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
                        
            % add to belowX handle collection to update the dependent
            % anchors
            hlist = [hr; hm; ht]; % order here matters, place error interval below marker
            ax.addHandlesToCollection('belowX', hlist);
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
            
            % put in top layer
            ax.addHandlesToCollection('markers', hlist);
            
%             if ~holdState
%                 hold(ax.axhDraw, 'off');
%             end
        end
        
        function ht = addLabelX(ax, varargin)
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('x', @isscalar);
            p.addRequired('label', @ischar);
            p.addParameter('labelColor', ax.tickFontColor, @(x) isvector(x) || isempty(x) || ischar(x));
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            label = p.Results.label;
            
            yl = get(ax.axh, 'YLim');
            
            ht = text(p.Results.x, yl(1), p.Results.label, ...
                'FontSize', ax.tickFontSize, 'Color', p.Results.labelColor, ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                'Parent', ax.axhDraw, 'Interpreter', 'none');
            
            ai = AutoAxis.AnchorInfo(ht, PositionType.Top, ...
                ax.axh, PositionType.Bottom, 'axisPaddingBottom', ...
                sprintf('labelX ''%s'' to bottom of axis', label));
            ax.addAnchor(ai);
            
            % add to belowX handle collection to update the dependent
            % anchors
            ax.addHandlesToCollection('belowX', ht);
        end
        
        function hlist = addScaleBar(ax, varargin)
            % add rectangular scale bar with text label to either the x or
            % y axis, at the lower right corner
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @ischar);
            p.addParameter('length', [], @(x) isscalar(x) || isempty(x));
            p.addParameter('units', '', @(x) isempty(x) || ischar(x));
            p.addParameter('manualLabel', '', @(x) isempty(x) || ischar(x));
            p.addParameter('useAutoScaleBarCollections', false, @islogical);
            p.addParameter('addAnchors', true, @islogical);
            p.addParameter('color', ax.scaleBarColor, @(x) ischar(x) || isvector(x));
            p.addParameter('fontColor', ax.scaleBarFontColor, @(x) ischar(x) || isvector(x));
            p.addParameter('fontSize', ax.scaleBarFontSize, @(x) isscalar(x));
            p.addParameter('manualPositionAlongAxis', [], @(x) isempty(x) || isscalar(x));
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh; %#ok<*PROP>
            useX = strcmp(p.Results.orientation, 'x');
            if ~isempty(p.Results.length)
                len = p.Results.length;
            else
                if ax.keepAutoScaleBarsEqual && p.Results.useAutoScaleBarCollections
                    xticks = get(ax.axh, 'XTick');
                    yticks = get(ax.axh, 'YTick');
                    len = min([xticks(end) - xticks(end-1), yticks(end) - yticks(end-1)]);
                else
                    if useX
                        ticks = get(ax.axh, 'XTick');
                    else
                        ticks = get(ax.axh, 'YTick');
                    end
                    if isempty(ticks)
                        xl = get(ax.axh, 'XLim');
                        len = floor(xl/5);
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
            if ismember('manualLabel', p.UsingDefaults) % allow '' to be specified too
                if isempty(units)
                    label = sprintf('%g', len);
                else
                    label = sprintf('%g %s', len, units);
                end
            else
                label = p.Results.manualLabel;
            end
           
            color = p.Results.color;
            fontColor = p.Results.fontColor;
            fontSize = p.Results.fontSize;
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
                    ht = text(xpos, yl(1), label, 'HorizontalAlignment', 'right', ...
                        'VerticalAlignment', 'top', 'Parent', ax.axhDraw, 'BackgroundColor', 'none');
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
                    ht = text(xl(2), ypos, label, 'HorizontalAlignment', 'right', ...
                        'VerticalAlignment', 'bottom', 'Parent', ax.axhDraw, ...
                        'Rotation', -90, 'BackgroundColor', 'none');
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
                    
                    
                else
                    ax.addHandlesToCollection('autoScaleBarYRect', hr);
                    hrRef = 'autoScaleBarYRect';
                    
                    if ~isempty(ht)
                        ax.addHandlesToCollection('autoScaleBarYText', ht);
                        htRef = 'autoScaleBarYText';
                    end
                end
            else 
                hrRef = hr;
                htRef = ht;
            end
            
            % build anchor for rectangle and label
            if p.Results.addAnchors
                if useX
                    ai = AnchorInfo(hrRef, PositionType.Height, [], 'scaleBarThickness', ...
                        0, 'xScaleBar thickness');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(hrRef, PositionType.Top, ax.axh, ...
                        PositionType.Bottom, 'axisPaddingBottom', ...
                        'xScaleBar at bottom of axis');
                    ax.addAnchor(ai);
                    if isempty(p.Results.manualPositionAlongAxis)
                        ai = AnchorInfo(hrRef, PositionType.Right, ax.axh, ...
                            PositionType.Right, @(a, varargin) a.axisPaddingBottom + a.scaleBarThickness, ...
                            'xScaleBar flush with right edge of yScaleBar at right of axis');
                        ax.addAnchor(ai);
                    end
                    if ~isempty(ht)
                        ai = AnchorInfo(htRef, PositionType.Top, hrRef, PositionType.Bottom, 0, ...
                            'xScaleBarLabel below xScaleBar');
                        ax.addAnchor(ai);
                        ai = AnchorInfo(htRef, PositionType.Right, hrRef, PositionType.Right, 0, ...
                            'xScaleBarLabel flush with left edge of xScaleBar');
                        ax.addAnchor(ai);
                    end
                else
                    ai = AnchorInfo(hrRef, PositionType.Width, [], 'scaleBarThickness', 0, ...
                        'yScaleBar thickness');
                    ax.addAnchor(ai);
                    ai = AnchorInfo(hrRef, PositionType.Left, ax.axh, ...
                        PositionType.Right, 'axisPaddingRight', ...
                        'yScaleBar at right of axis');
                    ax.addAnchor(ai);
                    if isempty(p.Results.manualPositionAlongAxis)
                        ai = AnchorInfo(hrRef, PositionType.Bottom, ax.axh, ...
                            PositionType.Bottom, @(a, varargin) a.axisPaddingBottom + a.scaleBarThickness, ...
                            'yScaleBar flush with bottom of xScaleBar at bottom of axis');
                        ax.addAnchor(ai);
                    end
                    if ~isempty(ht)
                        ai = AnchorInfo(htRef, PositionType.Left, hrRef, PositionType.Right, 0, ...
                            'yScaleBarLabel right of yScaleBar');
                        ax.addAnchor(ai);
                        ai = AnchorInfo(htRef, PositionType.Bottom, hrRef, PositionType.Bottom, 0, ...
                            'yScaleBarLabel bottom edge of xScaleBar');
                        ax.addAnchor(ai);
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
            p.addOptional('label', '', @ischar);
            p.addParameter('labelColor', ax.tickFontColor, @(x) isvector(x) || isempty(x) || ischar(x));
            p.addParameter('color', [0.1 0.1 0.1], @(x) isvector(x) || ischar(x) || isempty(x));    
            p.addParameter('errorInterval', [], @(x) isempty(x) || (isvector(x) && numel(x) == 2)); % a background rectangle drawn to indicate error in the placement of the main interval
            p.addParameter('errorIntervalColor', [0.5 0.5 0.5], @(x) isvector(x) || isempty(x) || ischar(x));
            p.addParameter('leaveInPlace', false, @islogical); % if true, don't anchor overall position, only internal relationships
            p.addParameter('manualPos', 0, @isscalar); % when leaveInPlace is true, where to place overall top along y
            p.addParameter('textOffsetY', 0, @isscalar);
            p.addParameter('textOffsetX', 0, @isscalar);
            p.addParameter('horizontalAlignment', 'center', @ischar);
            p.addParameter('verticalAlignment', 'top', @ischar);
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            axh = ax.axh; %#ok<*PROP>
            %leaveInPlace = p.Results.leaveInPlace;
            %manualPos = p.Results.manualPos;
            
            interval = p.Results.interval;
            color = p.Results.color;
            label = p.Results.label;
            errorInterval = p.Results.errorInterval;
            errorIntervalColor = p.Results.errorIntervalColor;
            fontSize = ax.tickFontSize;
            
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
            set(ht, 'FontSize', fontSize, 'Margin', 0.1, 'Color', p.Results.labelColor);
            
            set(hri, 'FaceColor', color, 'EdgeColor', 'none', 'Clipping', 'off', ...
                'XLimInclude', 'off', 'YLimInclude', 'off');
           
            if ax.debug
                set(ht, 'EdgeColor', 'r');
            end
            
            % build anchor for rectangle and label
            ai = AnchorInfo(hri, PositionType.Height, [], 'intervalThickness', 0, ...
                sprintf('interval ''%s'' thickness', label));
            ax.addAnchor(ai);
            
            % we'd like the VCenters of the markers (height = markerDiameter)
            % to match the VCenters of the intervals (height =
            % intervalThickness). Marker tops sit at axisPaddingBottom from the
            % bottom of the axis. Note that this assumes markerDiameter >
            % intervalThickness.
            ai = AnchorInfo(hri, PositionType.VCenter, ax.axh, ...
                PositionType.Bottom, @(ax,varargin) ax.axisPaddingBottom + ax.markerHeight/2, ...
                sprintf('interval ''%s'' below axis', label));
            ax.addAnchor(ai);

            % add custom or default y offset from bottom of rectangle
            textOffsetY = p.Results.textOffsetY;
            pos = PositionType.verticalAlignmentToPositionType(p.Results.verticalAlignment);
            ai = AnchorInfo(ht, pos, ...
                ax.axh, PositionType.Bottom, @(ax, varargin) ax.axisPaddingBottom + ax.markerHeight + ax.markerLabelOffset + textOffsetY, ...
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
        
        function [hl, ht] = addLabeledSpan(ax, varargin)
            % add line and text objects to the axis that replace the normal
            % axes. 'span' is 2 x N matrix
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            p = inputParser();
            p.addRequired('orientation', @ischar);
            p.addParameter('span', [], @ismatrix); % 2 X N matrix of [ start; stop ] limits
            p.addParameter('label', {}, @(x) isempty(x) || ischar(x) || iscell(x));
            p.addParameter('color', [0 0 0], @(x) ischar(x) || iscell(x) || ismatrix(x));
            p.addParameter('leaveInPlace', false, @islogical);
            p.addParameter('manualPos', 0, @isscalar); % position to place along non-orientation axis, when leaveInPlace is true
            p.CaseSensitive = false;
            p.parse(varargin{:});
            
            useX = strcmp(p.Results.orientation, 'x');
            span = p.Results.span;
            label = p.Results.label;
            fontSize = ax.tickFontSize;
            lineWidth = ax.tickLineWidth;
            color = p.Results.color;
            leaveInPlace = p.Results.leaveInPlace;
            manualPos = p.Results.manualPos;
            
            % check sizes
            nSpan = size(span, 2);
            assert(size(span, 1) == 2, 'span must be 2 x N matrix of limits');
            if ischar(label)
                label = {label};
            end
            assert(numel(label) == nSpan, 'numel(label) must match size(span, 2)');
            
            if ischar(color)
                color = {color};
            end
            if isscalar(color) && nSpan > 1
                color = repmat(color, nSpan, 1);
            end
            
            % generate line, ignore length here, we'll anchor that later
            if useX
                % x axis lines
                xvals = [span(1, :); span(2, :)];
                yvals = ones(size(xvals)) * manualPos;
                xtext = mean(span, 1);
                ytext = zeros(size(xtext));
                ha = repmat({'center'}, size(xtext));
                va = repmat({'top'}, size(xtext));
                offset = 'axisPaddingBottom';
                
            else
                % y axis lines
                yvals = [span(1, :); span(2, :)];
                xvals = ones(size(yvals)) * manualPos;
                ytext = mean(span, 1);
                xtext = zeros(size(ytext));
                ha = repmat({'right'}, size(xtext));
                va = repmat({'middle'}, size(xtext));
                offset = 'axisPaddingLeft';
            end
            
            hl = line(xvals, yvals, 'LineWidth', lineWidth, 'Parent', ax.axhDraw);
            if iscell(color)
                nc = numel(color);
            else
                nc = size(color, 1);
            end
            wrap = @(i) mod(i-1, nc) + 1;
            for i = 1:nSpan
                if iscell(color)
                    set(hl(i), 'Color', color{wrap(i)});
                else
                    set(hl(i), 'Color', color(wrap(i), :));
                end
            end
            AutoAxis.hideInLegend(hl);
            set(hl, 'Clipping', 'off', 'YLimInclude', 'off', 'XLimInclude', 'off');
            ht = AutoAxis.allocateHandleVector(nSpan);
            keep = truevec(nSpan);
            for i = 1:nSpan
                if isempty(label{i})
                    keep(i) = false;
                    continue;
                end
                ht(i) = text(xtext(i), ytext(i), label{i}, ...
                    'HorizontalAlignment', ha{i}, 'VerticalAlignment', va{i}, ...
                    'Parent', ax.axhDraw, 'Interpreter', 'none', 'BackgroundColor', 'none');
                if iscell(color)
                    set(ht(i), 'Color', color{wrap(i)});
                else
                    set(ht(i), 'Color', color(wrap(i), :));
                end
            end
            ht = ht(keep);
            
            if ~isempty(ht)
                set(ht, 'Clipping', 'off', 'Margin', 0.1, 'FontSize', fontSize);
                
                if ax.debug
                    set(ht, 'EdgeColor', 'r');
                end
            end
            
            if ~leaveInPlace
                % build anchor for lines
                if useX
                    ai = AnchorInfo(hl, PositionType.Top, ax.axh, ...
                        PositionType.Bottom, offset, 'xLabeledSpan below axis');
                    ax.addAnchor(ai);
                else
                    ai = AnchorInfo(hl, PositionType.Right, ...
                        ax.axh, PositionType.Left, offset, 'yLabeledSpan left of axis');
                    ax.addAnchor(ai);
                end
            end

            if ~isempty(ht)
                % anchor labels to lines (always)
                if useX
                    ai = AnchorInfo(ht, PositionType.Top, ...
                        hl, PositionType.Bottom, 'tickLabelOffset', ...
                        'xLabeledSpan below ticks');
                    ax.addAnchor(ai);
                else
                    ai = AnchorInfo(ht, PositionType.Right, ...
                        hl, PositionType.Left, 'tickLabelOffset', ...
                        'yLabeledSpan left of ticks');
                    ax.addAnchor(ai);
                end
            end
            
            ht = makecol(ht);
            hl = makecol(hl);
            hlist = [hl; ht];
            if ~leaveInPlace
                % add handles to handle collections
                if useX
                    ax.addHandlesToCollection('belowX', hlist);
                else
                    ax.addHandlesToCollection('leftY', hlist);
                end
            end
            
            % list as generated content
            ax.addHandlesToCollection('generated', hlist);
            
            % put in top layer
            ax.addHandlesToCollection('topLayer', hlist);
        end 
        
        function addColoredLabels(ax, labels, colors, varargin)
            import AutoAxis.PositionType;
            import AutoAxis.AnchorInfo;
            
            p = inputParser();
            p.addParameter('posX', PositionType.Right, @(x) isa(x, 'AutoAxis.PositionType'));
            p.addParameter('posY', PositionType.Top, @(x) isa(x, 'AutoAxis.PositionType'));
            p.addParameter('fontSize', ax.labelFontSize, @isscalar);
            p.addParameter('spacing', 'tickLabelOffset', @(x) true);
            p.addParameter('fillColor', 'none', @(x) true);
            p.addParameter('fillAlpha', 1, @isscalar);
            p.parse(varargin{:});
            posX = p.Results.posX;
            posY = p.Results.posY;
            
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
            
            top = posY == PositionType.Top;
            if top
                root = 1;
                anchorToOffset = -1;
            else
                root = N;
                anchorToOffset = 1;
            end  
            
            for i = 1:N
                label = labels{i};
                if iscell(colors)
                    c = colors{i};
                else
                    c = colors(i, :);
                end
 
                hvec(i) = text(0, (~rev * -i), label, 'FontSize', p.Results.fontSize, ...
                    'Color', c, 'HorizontalAlignment', posX.toHorizontalAlignment(), ...
                    'VerticalAlignment', posY.flip().toVerticalAlignment());
                if isempty(p.Results.fillColor) || (ischar(p.Results.fillColor) && strcmp(p.Results.fillColor, 'none'))
                    set(hvec(i), 'BackgroundColor', 'none');
                else
                    set(hvec(i), 'BackgroundColor', p.Results.fillColor);
                    if p.Results.fillAlpha < 1
                        hvec(i).BackgroundColor(4) = p.Results.fillAlpha;
                    end  
                end
                    
            end
            
             
            for i = 1:N
                if i == root
                    % anchor to axis
                    ai = AnchorInfo(hvec(i), posY, ax.axh, posY, 0, ...
                        sprintf('colorLabel %s %s to axis %s', labels{i}, char(posY), char(posY)));
                else
                    % anchor to text above/below
                    ai = AnchorInfo(hvec(i), posY, hvec(i+anchorToOffset), posY.flip(), p.Results.spacing, ...
                        sprintf('colorLabel %s %s to %s %s', labels{i}, char(posY), labels{i+anchorToOffset}, char(posY.flip())));
                end
                ax.addAnchor(ai);
            end
            
            ai = AnchorInfo(hvec, posX, ax.axh, posX, 0, ...
                sprintf('colorLabels to axis %s', char(posX), char(posX)));
            ax.addAnchor(ai);
            
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
    end
    
    methods
        function addAnchor(ax, info)
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
            
            % force an update of the dependency graph and reordering of the
            % anchors
            ax.refreshNeeded = true;
           
        end
        
        function update(ax)
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
            if gridActive
                % dont turn the grid off, instead hide the rulers
                axis(ax.axh, 'on');
                box(ax.axh, 'off');
                ax.axh.XRuler.Visible = 'off';
                ax.axh.YRuler.Visible = 'off';
                
                % use a dark background with light grid lines
                ax.axh.Color = ax.gridBackground;
                ax.axh.GridColor = ax.gridColor;
                ax.axh.GridAlpha = 1;
                ax.axh.MinorGridColor = ax.minorGridColor;
                ax.axh.MinorGridAlpha = 1;
                ax.axh.MinorGridLineStyle = '-';
                figh = AutoAxis.getParentFigure(ax.axh);
                figh.InvertHardcopy = 'off';
                % other properties will be set in deferred updates
            else
                axis(ax.axh, 'off');
            end
            if ax.usingOverlay
                axis(ax.axhDraw, 'off');
                set(ax.axhDraw, 'Color', 'none');
            end
            
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
                ax.prioritizeAnchorOrder();
                ax.refreshNeeded = false;
            end
            
            % recreate the auto axes and scale bars if installed
            if ~isempty(ax.autoAxisX)
                ax.addAutoAxisX();
            end
            if ~isempty(ax.autoAxisY)
                ax.addAutoAxisY();
            end
            if ~isempty(ax.autoScaleBarX)
                ax.addAutoScaleBarX();
            end
            if ~isempty(ax.autoScaleBarY)
                ax.addAutoScaleBarY();
            end
            
            % restore the X and Y label handles and make them visible since
            % they have a tendency to get hidden (presumably by axis off)
            if ~isempty(ax.hXLabel)
                ax.hXLabel = get(ax.axh, 'XLabel');
                set(ax.hXLabel, 'Visible', 'on');
            end
            if ~isempty(ax.hYLabel)
                ax.hYLabel = get(ax.axh, 'YLabel');
                set(ax.hYLabel, 'Visible', 'on');
            end

            if ~isempty(ax.anchorInfo)                
                % dereference all anchors into .anchorInfoDeref
                % i.e. replace collection names with handle vectors
                ax.derefAnchors();
                
                % query the locations of each handle and put them into the
                % handle to LocationInfo map
                ax.updateLocationCurrentMap();
            
                % process all dereferenced anchors in order
                for i = 1:numel(ax.anchorInfoDeref)
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
        
        function updateAxisStackingOrder(ax)
            % update the visual stacking order for annotations that are
            % added to ensure visual consistency
            
            % intervals, then on top of that markers, then on top of that
            % topLayer
            
            hvec = ax.getHandlesInCollection('intervals');
            if ~isempty(hvec)
                hvec = hvec(isvalid(hvec));
                bringToTop(hvec);
            end
            
            hvec = ax.getHandlesInCollection('markers');
            if ~isempty(hvec)
                hvec = hvec(isvalid(hvec));
                bringToTop(hvec);
            end
            
            hvec = ax.getHandlesInCollection('topLayer');
            if ~isempty(hvec)
                hvec = hvec(isvalid(hvec));
                bringToTop(hvec);
            end
            
            function bringToTop(hvec)
                % hvec is listed in order of their creation, last created
                % is last in the array, but should be at the top of the
                % stacking order, hence flipud.
                % we do this directly because repeated calls to uistack are
                % slow and uistack doesn't preserve the order of the
                % handles passed in sometimes
                
                children = ax.axh.Children;
                mask = ismember(children, hvec);
                hvecMask = ismember(hvec, children);
                children = [flipud(hvec(hvecMask)); children(~mask)];
                ax.axh.Children = children;
                
%                 for i = 1:numel(hvec)
%                     uistack(hvec(i), 'top');
%                 end
            end
        end
        
        function doDeferredGraphicsUpdates(ax) 
            % deferred set rectangle face clipping off
            hvec = ax.getHandlesInCollection('markers');
            for i = 1:numel(hvec)
                if isa(hvec(i), 'matlab.graphics.primitive.Rectangle')
                    if isempty(hvec(i).Face)
                        drawnow;
                    end
                    hvec(i).Face.Clipping = 'off';
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

        function updateAxisScaling(ax)
            % set x/yDataToUnits scaling from data to paper units
            axh = ax.axh;
            axUnits = get(axh, 'Units');

            set(axh,'Units','centimeters');
            set(axh, 'LooseInset', ax.axisMargin);
            
            axlim = axis(axh);
            axwidth = diff(axlim(1:2));
            axheight = diff(axlim(3:4));
%             axpos = get(axh,'Position');
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
            
            ax.xReverse = strcmp(get(axh, 'XDir'), 'reverse');
            ax.yReverse = strcmp(get(axh, 'YDir'), 'reverse');
            
            set(axh, 'Units', axUnits);
        end
        
        function derefAnchors(ax)
            % go through .anchorInfo, dereference all referenced handle
            % collections and property values, and store in
            % .anchorInfoDeref
            
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
                
                % lookup margin as property value or function handle
                if ischar(info.margin)
                    info.margin = ax.(info.margin);
                elseif isa(info.margin, 'function_handle')
                    info.margin = info.margin(ax, info);
                end
                
                % look property or eval fn() for .pos or .posa
                if ischar(info.pos)
                    info.pos = ax.(info.pos);
                elseif isa(info.pos, 'function_handle')
                    info.pos = info.pos(ax, info);
                end
                
                if ischar(info.posa)
                    info.posa = ax.(info.posa);
                elseif isa(info.posa, 'function_handle')
                    info.posa = info.posa(ax, info);
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
                    locCell{iH}.queryPosition(ax.xDataToPoints, ax.yDataToPoints, ...
                        ax.xReverse, ax.yReverse);
                end
            end
            
            % and build a LocationCurrent for missing handles
            missing = AutoAxis.setdiffHandles(hvec, ax.mapLocationHandles);
            for iH = 1:numel(missing)
                ax.setLocationCurrent(missing(iH), ...
                    AutoAxis.LocationCurrent.buildForHandle(missing(iH), ...
                    ax.xDataToPoints, ax.yDataToPoints, ax.xReverse, ax.yReverse));
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
                pAnchor = ax.getCurrentPositionData(info.ha, info.posa);
            end

            % add margin to anchor in the correct direction if possible
            if ~isempty(info.ha) && ~isempty(info.margin) && ~isnan(info.margin)
                offset = 0;
                
                if info.posa == PositionType.Top
                    offset = info.margin / ax.yDataToUnits;
                elseif info.posa == PositionType.Bottom
                    offset = -info.margin / ax.yDataToUnits;
                elseif info.posa == PositionType.Left
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
            ax.updatePositionData(info.h, info.pos, pAnchor, info.translateDontScale, info.applyToPointsWithinLine);
            
            valid = true;
        end
        
        function prioritizeAnchorOrder(ax)
            % re-order .anchorInfo so that they can be processed in order, 
            % such that later anchors are dependent only on the positions
            % of objects positioned by earlier (and thus already processed)
            % anchors
            
            import AutoAxis.PositionType;
            
            ax.derefAnchors();
            nA = numel(ax.anchorInfoDeref);
               
            % gather info about each anchor once up front to save time
            [specifiesSize, isX] = nanvec(nA);
            [isHandleH, isHandleHa] = falsevec(nA);
            posSpecified(nA) = PositionType.Top;
            posSpecified = posSpecified';
            for iA = 1:nA
                a = ax.anchorInfoDeref(iA);
                specifiesSize(iA) = a.pos.specifiesSize();
                isX(iA) = a.pos.isX();
                isHandleH(iA) = a.isHandleH;
                isHandleHa(iA) = a.isHandleHa;
                posSpecified(iA) = a.pos;
            end
            
            % first loop through and build a matrix of direct handle
            % dependendencies to speed things up. 
            [hCat, hWhichPartial] = TensorUtils.catWhichIgnoreEmpty(1, ax.anchorInfoDeref(isHandleH).h);
            hWhich = TensorUtils.indicesIntoMaskToOriginalIndices(hWhichPartial, isHandleH);
            [haCat, haWhichPartial] = TensorUtils.catWhichIgnoreEmpty(1, ax.anchorInfoDeref(isHandleHa).ha);
            haWhich = TensorUtils.indicesIntoMaskToOriginalIndices(haWhichPartial, isHandleHa);
                
            % now build matrix hDepMat(i, j) = true if anchorInfo i uses as an
            % anchor a handle that is positioned/resized by anchorInfo j,
            % such that i may depend on j
            hDepMat = false(nA, nA);
            for iH = 1:numel(hCat)    
                hDepMat(haWhich(haCat == hCat(iH)), hWhich(iH)) = true;
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
            for iA = 1:nA
                if ~isHandleH(iA)
                    continue; % must specify a literal since it's already dereferenced
                end
                
                if isHandleHa(iA)
                    % add dependencies on any anchor that determines the
                    % corresponding position (posa) of this anchor's anchor
                    % object (ha)
%                     dependencyMat(iA, :) = ax.findAnchorsSpecifying(anchor.ha, anchor.posa);
                    
                    dependencyMat(iA, :) = hDepMat(iA, :) & posSpecified' == posSpecified(iA);
                end
                
                % if this anchor sets the position of h, add dependencies
                % on any anchors which affect the size of the same object so
                % that sizing happens before positioning
                if ~specifiesSize(iA)
                    if isX(iA)
                        dependencyMat(iA, :) = dependencyMat(iA, :) | (hAffectSameMat(iA, :)' & specifiesSize & isX)';
                    else
                        dependencyMat(iA, :) = dependencyMat(iA, :) | (hAffectSameMat(iA, :)' & specifiesSize & ~isX)';
                    end
                end

                % add dependencies on anchors such that MarkerDiameter is
                % always specified before size or position
                if posSpecified(iA) ~= PositionType.MarkerDiameter
%                     dependencyMat(i, :) = dependencyMat(i, :) | ax.findAnchorsSpecifying(anchor.h, PositionType.MarkerDiameter);
                    dependencyMat(iA, :) = dependencyMat(iA, :) | (hDepMat(iA, :) & posSpecified' == PositionType.MarkerDiameter);
                end
            end
            
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
        
        function mask = findAnchorsSpecifying(ax, hVec, posType)
            % returns a list of AnchorInfo which could specify position posa of object h
            % this includes 
            import AutoAxis.PositionType;
            
            % first find any anchors that specify any subset of the handles in
            % hVec
            
            % not using strings anymore since we do this all on
            % dereferenced anchors
            
%             if ischar(hVec)
%                 maskH = cellfun(@(v) isequal(hVec, v), {ax.anchorInfoDeref.h});
%             else
                maskH = arrayfun(@(info) info.isHandleH && any(ismember(hVec, info.h)), ax.anchorInfoDeref);
%             end
            
            if ~any(maskH)
                mask = maskH;
                return;
            end
            
            % then search for any directly or indirectly specifying anchors
            info = ax.anchorInfoDeref(maskH); % | maskExact);

            maskTop = [info.pos] == PositionType.Top;
            maskBottom = [info.pos] == PositionType.Bottom;
            maskVCenter = [info.pos] == PositionType.VCenter;
            maskLeft = [info.pos] == PositionType.Left;
            maskRight = [info.pos] == PositionType.Right;
            maskHCenter = [info.pos] == PositionType.HCenter;
            maskHeight = [info.pos] == PositionType.Height; 
            maskWidth = [info.pos] == PositionType.Width;

            % directly specified anchors
            maskDirect = [info.pos] == posType;

            % placeholder for implicit "combination" specifying anchors,
            % e.g. height and/or bottom specifying the top position
            maskImplicit = false(size(info));

            switch posType
                case PositionType.Top
                    if sum([any(maskBottom) any(maskHeight) any(maskVCenter)]) >= 1 % specifying any of these will affect the top
                        maskImplicit = maskBottom | maskHeight | maskVCenter; 
                    end

                case PositionType.Bottom
                    if sum([any(maskTop) any(maskHeight) any(maskVCenter)]) >= 1
                        maskImplicit = maskTop | maskHeight | maskVCenter; 
                    end

                case PositionType.Height
                    if sum([any(maskTop) any(maskBottom) any(maskVCenter)]) >= 2 % specifying any 2 of these will dictate the height, specifying only one will keep the height as is
                        maskImplicit = maskTop | maskBottom | maskVCenter;
                    end

                case PositionType.VCenter
                    if sum([any(maskTop) any(maskBottom) any(maskHeight)]) >= 1
                        maskImplicit = maskTop | maskBottom | maskHeight;
                    end

                case PositionType.Left
                    if sum([any(maskRight) any(maskWidth) any(maskHCenter)]) >= 1
                        maskImplicit = maskRight | maskWidth | maskHCenter;
                    end

                case PositionType.Right
                    if sum([any(maskLeft) any(maskWidth) any(maskHCenter)]) >= 1
                        maskImplicit = maskLeft | maskWidth | maskHCenter; 
                    end

                case PositionType.Width
                    if sum([any(maskLeft) && any(maskRight) any(maskHCenter)]) >= 2
                        maskImplicit = maskLeft | maskRight | maskHCenter;
                    end

                case PositionType.HCenter
                    if sum([any(maskLeft) && any(maskRight) any(maskWidth)]) >= 1
                        maskImplicit = maskLeft | maskRight | maskWidth;
                    end
            end
            
            %info = info(maskDirect | maskImplicit);
            idx = find(maskH);
            idx = idx(maskDirect | maskImplicit);
            mask = false(size(maskH));
            mask(idx) = true;
        end
        
        function pos = getCurrentPositionData(ax, hvec, posType)
            % grab the specified position / size value for object h, in figure units
            % when hvec is a vector of handles, uses the outer bounding
            % box for the objects instead
            
            import AutoAxis.PositionType;
            import AutoAxis.LocationCurrent;
            
            if isempty(hvec)
                % pass thru for specifying length or width directly
                pos = posa;
                return;
            end
            
            % grab all current values from LocationCurrent for each handle
            clocVec = arrayfun(@(h) ax.getLocationCurrent(h), hvec, 'UniformOutput', false);
            clocVec = cat(1, clocVec{:});

            % and compute aggregate value across all handles
            pos = LocationCurrent.getAggregateValue(clocVec, posType, ax.xReverse, ax.yReverse);
        end
        
        function updatePositionData(ax, hVec, posType, value, translateDontScale, applyToPointsWithinLine)
            % update the position of handles in vector hVec using the LocationCurrent in 
            % ax.locMap. When hVec is a vector of handles, linearly shifts
            % each object to maintain the relative positions and to
            % shift the bounding box of the objects
            
            value = double(value);
            import AutoAxis.*;
            
            if ~exist('translateDontScale', 'var')
                translateDontScale = true;
            end
            if ~exist('applyToPointsWithinLine', 'var')
                applyToPointsWithinLine = [];
            end
            
            if ~isscalar(hVec)
                % here we linearly scale / translate the bounding box
                % in order to maintain internal anchoring, scaling should
                % be done before any "internal" anchorings are computed,
                % which should be taken care of by findAnchorsSpecifying
                %
                % note that this will recursively call updatePositionData, so that
                % the corresponding LocationCurrent objects will be updated
                
                if posType == PositionType.Height
                    % scale everything vertically, but keep existing
                    % vcenter (of bounding box) in place
                    
                    % first find the existing extrema of the objects
                    oldTop = ax.getCurrentPositionData(hVec, PositionType.Top);
                    oldBottom = ax.getCurrentPositionData(hVec, PositionType.Bottom);
                    newBottom = (oldTop+oldBottom) / 2 - value/2;
                    
                    % build affine scaling fns for inner objects
                    newPosFn = @(p) (p-oldBottom) * (value / (oldTop-oldBottom)) + newBottom;
                    newHeightFn = @(h) h * (value / (oldTop-oldBottom));
                    
                    % loop over each object and shift its position by offset
                    for i = 1:numel(hVec)
                       h = hVec(i);
                       t = ax.getCurrentPositionData(h, PositionType.Top);
                       he = ax.getCurrentPositionData(h, PositionType.Height);
                       ax.updatePositionData(h, PositionType.Height, newHeightFn(he));
                       ax.updatePositionData(h, PositionType.Top, newPosFn(t));
                    end
                
                elseif posType == PositionType.Width
                    % scale everything horizontally, but keep existing
                    % hcenter (of bounding box) in place if anchored
                    
                    % first find the existing extrema of the objects
                    oldRight = ax.getCurrentPositionData(hVec, PositionType.Right);
                    oldLeft = ax.getCurrentPositionData(hVec, PositionType.Left);
 
                    newLeft = (oldRight+oldLeft) / 2 - value/2;
                    
                    % build affine scaling fns
                    newPosFn = @(p) (p-oldLeft) * (value / (oldRight-oldLeft)) + newLeft;
                    newWidthFn = @(w) w * value / (oldRight-oldLeft);
                    
                    % loop over each object and shift its position by offset
                    for i = 1:numel(hVec)
                       h = hVec(i);
                       l = ax.getCurrentPositionData(h, PositionType.Left);
                       w = ax.getCurrentPositionData(h, PositionType.Width);
                       ax.updatePositionData(h, PositionType.Width, newWidthFn(w));
                       ax.updatePositionData(h, PositionType.Left, newPosFn(l));
                    end
                    
                else
                    % simply shift each object by the same offset, thereby shifting the bounding box 
                    offset = value - ax.getCurrentPositionData(hVec,  posType);
                    for i = 1:numel(hVec)
                       h = hVec(i);
                       p = ax.getCurrentPositionData(h, posType);
                       ax.updatePositionData(h, posType, p + offset);
                    end
                end

            else
                % scalar handle, move it directly via the LocationCurrent
                % handle 
                h = hVec(1);
                
                % use the corresponding LocationCurrent for this single
                % object to move the graphics object
                cloc = ax.getLocationCurrent(h);
                cloc.setPosition(posType, value, ...
                    ax.xDataToPoints, ax.yDataToPoints, ax.xReverse, ax.yReverse, translateDontScale, applyToPointsWithinLine);
            end
        end
    end
    
    methods(Static)
        function newSet = setdiffHandles(set, drop)
            maskDrop = falsevec(numel(set));
            for iD = 1:numel(drop)
                maskDrop( set == drop(iD) ) = true;
            end
            newSet = set(~maskDrop);
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
    end
end
