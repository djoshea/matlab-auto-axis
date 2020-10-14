classdef FixedAxisGrid < handle
    % replacement for subplot where the sizes of all axes (InnerPosition) are determined either by:
    % - absolute size in paper units
    % - relative sizes given total size
    % - 
    properties(SetAccess=protected)
        figh
        units = 'centimeters';
        
        axes % rows x col cell

        row_span % rows x cols
        col_span % rows x cols

        rows
        cols

        axOverlaya
    end

    properties
        height_spec (:, 1) % R - vector of fixed sizes for a subset of rows, NaN indicates unspecified
        height_data_scale_spec (:, :, :) % R x C x nScales - each column specifies factors applying consistent scaling across rows, NaN indicates unspecified
        vspacing_spec (:, 1) % top, rows-1 spacing between rows
        total_height_spec (1, 1) % if not NaN, specifies the 
        
        width_spec (:, 1) % R - vector of fixed sizes for a subset of rows, NaN indicates unspecified
        width_data_scale_spec (:, :, :) % R x C x nScales  
        hspacing_spec (:, 1) % left, cols-1 spacing between columns, right
        total_width_spec (1,1) % if not NaN, specifies the 
        
        valid_handle
        occupied % rows x cols logical
        occupiedBy % returns ind into handles
        total_height % overall figure height
        total_width % overall figure width
    end
    
    properties(Dependent, SetAccess=protected)
        height % R 
        width
        row_spacing % top, rows-1 spacing between rows
        col_spacing % left, cols-1 spacing between columns, right
    end

    methods
        function g = FixedAxisGrid(varargin)
            p = inputParser();
            p.addOptional('figh', gcf, @(x) isa(x, 'matlab.ui.Figure'));
            
            p.addParameter('height', [], @isvector);
            p.addParameter('height_data_scale', [], @ismatrix); % R x C
            p.addParameter('total_height', NaN, @isscalar);
            p.addParameter('hspacing', [], @isvector);
            
            p.addParameter('width', [], @isvector);
            p.addParameter('width_data_scale', [], @ismatrix); % R x 
            p.addParameter('total_width', NaN, @isscalar);
            p.addParameter('vspacing', [], @isvector);
            
            p.parse(varargin{:});

            figh = p.Results.figh;
            assert(isa(figh, 'matlab.ui.Figure'));
            
            % fetch existing instance
            if numel(varargin) < 1
                g = FixedAxisGrid.recoverForFigure(figh);
                if isempty(g)
                    error('No FixedAxisGrid installed for figure.)');
                end
                return;
            end
 
            g.height_spec = p.Results.height;
            g.height_data_scale_spec = p.Results.height_data_scale;
            g.total_height_spec = p.Results.total_height;
            g.vspacing_spec = p.Results.vspacing;
            
            g.width_spec = p.Results.width;
            g.width_data_scale_spec = p.Results.width_data_scale;
            g.total_width_spec = p.Results.total_width;
            g.hspacing_spec = p.Results.hspacing;
            
            g.checkSpec();
            
            g.figh = figh;

            g.axes = gobjects(g.rows, g.cols);
            g.row_span = zeros(g.rows, g.cols); % rows x cols 
            g.col_span = zeros(g.rows, g.cols);
            
            setappdata(g.figh, 'FixedAxisGridInstance', g);
        end
        
        function checkSpec(g)
            % check that we can unambiguously determine the size of each row and column, given the axes limits
            
            % determine the number of rows and columns
            if isempty(g.height_spec)
                % rows must all be specified via row_data_scale
                assert(~isempty(g.height_data_scale_spec), 'Must specify either height or row_data_scale');
                g.rows = size(g.height_data_scale_spec, 1);
            else
                g.rows = numel(g.height_spec);
            end
            if isempty(g.width_spec)
                % rows must all be specified via row_data_scale
                assert(~isempty(g.width_data_scale_spec), 'Must specify either width or width_data_scale');
                g.cols = size(g.width_data_scale_spec, 1);
            else 
                g.cols = numel(g.width_spec);
            end
            
            % fill in unspecified props
            if isempty(g.height_spec)
                g.height_spec = nan(g.rows, 1);
            else
                g.height_spec = FixedAxisGrid.expandSizeVec(g.rows, g.height_spec, 'height');
            end
            if isempty(g.height_data_scale_spec)
                g.height_data_scale_spec = nan(g.rows, g.cols, 1);
            end
            if isempty(g.vspacing_spec)
                g.vspacing_spec = nan(g.rows-1);
            else
                g.vspacing_spec = FixedAxisGrid.expandSpacingVec(g.rows, g.vspacing_spec, 'vspacing');
            end
            if isempty(g.width_spec)
                g.width_spec = nan(g.cols, 1);
            else
                g.width_spec = FixedAxisGrid.expandSizeVec(g.cols, g.width_spec, 'height');
            end
            if isempty(g.width_data_scale_spec)
                g.width_data_scale_spec = nan(g.rows, g.cols, 1);
            end
            if isempty(g.hspacing_spec)
                g.hspacing_spec = nan(g.cols-1);
            else
                g.hspacing_spec = FixedAxisGrid.expandSpacingVec(g.cols, g.hspacing_spec, 'hspacing');
            end

            % check sizes match expectation
            assert(numel(g.height_spec) == g.rows, 1);
            assert(isequal(size(g.height_data_scale_spec, [1 2]), [g.rows, g.cols]));
            assert(numel(g.width_spec) == g.cols, 1);
            assert(isequal(size(g.width_data_scale_spec, [1 2]), [g.rows, g.cols]));
            
            % check that size of each row and column is inferrable
            % we can infer the size of a given row/col if:
            % - it is specified directly
            % - it has at least one col/row with a data scale specified and the data scale is determined

            % a data scale is determined if at least one row/col has both scale and absolute size specified, or if all row/cols share the same scale and the total height/width is specified
%             height_scale_set_any_col = any(~isnan(g.height_data_scale_spec));
%             height_scale_determined = height_scale_set_any_col & ~isnan(g.height_spec), 2) | all(g.height_data); % R x 1 x nHeightScales

% 
%             specified_by_scale = any(~isnan(g.row_data_scale_spec, 2));
%             specified_absolute = ~isnan(g.height_spec);
%             assert(all(specified_by_scale | specified_absolute), 'all rows must be specified by height or row_data_scale');
%             
%             scales_anchored =  
        end

        function [yspan, xspan] = get_data_span(g)
            R = g.rows;
            C = g.cols;
            [yspan, xspan] = deal(nan(R, C));
            occupied = g.occupied;
            for r = 1:R
                for c = 1:C
                    if occupied(r, c)
                        ax = g.axes(r, c);
                        xspan(r, c) = ax.XLim(2) - ax.XLim(1);
                        yspan(r, c) = ax.YLim(2) - ax.YLim(1);
                    end
                end
            end
        end

        function [hspacing, yspacing] = get_spacing_from_insets(g)
            R = g.rows;
            C = g.cols;
            [yspan, xspan] = deal(nan(R, C));
            occupied = g.occupied;
            for r = 1:R
                for c = 1:C
                    if occupied(r, c)
                        ax = g.axes(r, c);
                        xspan(r, c) = ax.XLim(2) - ax.XLim(1);
                        yspan(r, c) = ax.YLim(2) - ax.YLim(1);
                    end
                end
            end
        end

        function compute_absolute_sizes(g)
        end
        
       
        function v = get.total_height(g)
            v = sum(g.row_spacing) + sum(g.height);
        end
        
        function v = get.total_width(g)
            v = sum(g.col_spacing) + sum(g.width);
        end

        function tf = get.valid_handle(g)
            R = g.rows;
            C = g.cols;
            tf = false(R, C);
            for r = 1:R
                for c = 1:C 
                    if ~isa(g.axes(r,c), 'matlab.graphics.GraphicsPlaceholder') && isvalid(g.handles(r, c))
                        tf(r,c) = true;
                    end
                end
            end
        end

        function tf = get.occupied(g)
            R = g.rows;
            C = g.cols;
            tf = false(R, C);
            valid_handle = g.valid_handle; %#ok<*PROP>
            for r = 1:R
                for c = 1:C 
                    if valid_handle(r, c)
                        tf(r : r + g.row_span(r, c)-1, c : c + g.col_span(r, c)-1) = true;
                    end
                end
            end
        end

        function ind = get.occupiedBy(g)
            R = g.rows;
            C = g.cols;
            ind = nan(R, C);
            for r = 1:R
                for c = 1:C 
                    if isa(g.handles(r,c), 'matlab.graphics.GraphicsPlaceholder')
                        continue;
                    end
                    ind(r : r + g.row_span(r, c)-1, c : c + g.col_span(r, c)-1) = sub2ind([R, C], r, c);
                end
            end
        end
           
        function ax = axisAt(g, row, col, varargin)
            p = inputParser();
            p.addParameter('row_span', 1, @isscalar);
            p.addParameter('col_span', 1, @isscalar);
            p.addParameter('polar', false, @islogical);
            p.parse(varargin{:});
            row_span = p.Results.row_span; %#ok<*PROPLC>
            col_span = p.Results.col_span;
            assert(row + row_span - 1 <= g.rows && col + col_span - 1 <= g.cols, 'Subscripts or span out of range');
            current = g.axes(row, col);
            
            if ~isa(current, 'matlab.graphics.GraphicsPlaceholder') && isvalid(current)
                ax = current;
                set(g.figh, 'CurrentAxes', ax);
                return;
            end

            % check for occupied
            occupiedBlock = g.occupied(row:row+row_span-1, col:col+col_span-1);
            if any(occupiedBlock)
                inds = g.occupiedBy(occupiedBlock);
                [ro, co] = ind2sub([g.rows, g.cols], inds(1));
                error('This axis location overlaps with another axis installed at (%d, %d)', ro, co);
            end

            pos = g.computeAxisPosition(row, col, p.Results.row_span, p.Results.col_span);
            if p.Results.polar
                ax = polaraxes('Parent', g.figh);
            else
                ax = axes('Parent', g.figh);
            end
            %u = ax.Units;
            ax.Units = g.units;
            ax.Position = pos;
            ax.LooseInset = ax.TightInset;
            %ax.Units = u;
            set(g.figh, 'CurrentAxes', ax);
            g.handles(row, col) = ax;
            g.row_span(row, col) = row_span;
            g.col_span(row, col) = col_span;
        end

        function aa = autoAxisAt(g, varargin)
            ax = g.axisAt(varargin{:});
            aa = AutoAxis(ax);
        end

        function pos = computeAxisPosition(g, row, col, row_span, col_span)
            if nargin < 4
                row_span = g.row_span(row, col);
            end
            if nargin < 5
                col_span = g.col_span(row, col);
            end
            
            left = sum(g.width(1:col-1)) + sum(g.col_spacing(1:col));
            bottom = sum(g.height(row+row_span:end)) + sum(g.row_spacing(row+row_span:end));
            height = sum(g.height(row : row + row_span - 1)) + sum(g.row_spacing(row : row + row_span - 2));
            width = sum(g.width(col : col + col_span - 1)) + sum(g.col_spacing(col : col + col_span - 2));

            pos = [left bottom width height];
        end

        function updatePositions(g)
            valid_handle = g.valid_handle;
            row_span = g.row_span;
            col_span = g.col_span;
            for r = 1:g.rows
                for c = 1:g.cols
                    if valid_handle(r, c)
                        h = g.handles(r, c);
                    
                        u = h.Units;
                        h.Units = 'centimeters';
                        h.Position = g.computeAxisPosition(r, c, row_span(r, c), col_span(r, c));
                        h.Units = u;
                    end
                end
            end
            
            % update overlay if present
            if ~isempty(g.axOverlay) && isvalid(g.axOverlay)
                g.axOverlay.Position = [0 0 g.total_width g.total_height];
            end
            
            % update figure size
            g.figh.Units = g.units;
            if strcmp(g.figh.WindowStyle, 'normal')
                g.figh.Position(3) = g.total_width;
                g.figh.Position(4) = g.total_height;
            end
        end

        function update(g)
            g.updatePositions();
            AutoAxis.updateFigure(g.figh);
        end

        function overlayDebug(g)
            g.update();
            g.clearOverlay();
            ax = g.createOverlay();
            R = g.rows;
            C = g.cols;
            valid_handle = g.valid_handle;
            row_span = g.row_span;
            col_span = g.col_span;

            for r = 1:R
                for c = 1:C
                    if valid_handle(r, c)
                        pos = g.computeAxisPosition(r, c, row_span(r, c), col_span(r, c));
                        rectangle('Position', pos, 'Parent', ax, 'FaceColor', [0 0.45 0.75 0.5], 'EdgeColor', [0.5 0.5 0.5]);
                        hold(ax, 'on');
                    end
                end
            end
        end

        function axOverlay = createOverlay(g)
            if isempty(g.axOverlay) || ~isvalid(g.axOverlay)
                g.figh.Units = g.units;
                g.axOverlay = axes('Units', g.units, 'Position', [0 0 g.total_width g.total_height], 'Parent', g.figh, ...
                    'Color', 'none', 'XLim', [0 g.total_width], 'YLim', [0 g.total_height], ...
                    'Tag', 'overlay', 'HitTest', 'off');

                uistack(g.axOverlay, 'top');
                hold(g.axOverlay, 'on');
            end
            
            axOverlay = g.axOverlay;
        end

        function clearOverlay(g)
            if ~isempty(g.axOverlay) && isvalid(g.axOverlay)
                delete(g.axOverlay)
            end
            g.axOverlay = [];
        end

%         function v = get.row_spacing(g)
%             v = g.row_spacing_I;
%         end
%         function set.row_spacing(g, v)
%             g.row_spacing_I = FixedAxisGrid.expandSpacingVec(g.rows, v, 'row_spacing');
%         end
%         
%         function v = get.col_spacing(g)
%             v = g.col_spacing_I;
%         end
%         function set.col_spacing(g, v)
%             g.col_spacing_I = FixedAxisGrid.expandSpacingVec(g.cols, v, 'col_spacing');
%         end
% 
%         function v = get.height(g)
%             v = g.height_I;
%         end
%         function set.height(g, v)
%             g.height_I = FixedAxisGrid.expandSizeVec(g.rows, v, 'height');
%         end
%         
%         function v = get.width(g)
%             v = g.width_I;
%         end
%         function set.width(g, v)
%             g.width_I = FixedAxisGrid.expandSizeVec(g.cols, v, 'width');
%         end
    end
    methods(Static)
        function updateFigure(figh)
            % call auto axis update for every managed axis in a figure
            if nargin < 1
                figh = gcf;
            end
            
            g = FixedAxisGrid.recoverForFigure(figh);
            if ~isempty(g) && isvalid(g)
                g.update();
            end
        end
        
        function ma = recoverForFigure(figh)
            % recover the MultiAxis instance associated with figure figh
            if nargin < 1, figh = gcf; end
            ma = getappdata(figh, 'FixedAxisGridInstance');
        end
        
        function vec = expandSpacingVec(n, spacing, name)
            spacing = makecol(spacing);
            if isscalar(spacing)
                vec = repmat(spacing, n+1, 1);
            elseif numel(spacing) == 2 % outside inside
                vec = [spacing(1); repmat(spacing(2), n-1, 1), spacing(1)];
            elseif numel(spacing) == 3 % pre inside post
                vec = [spacing(1); repmat(spacing(2), n-1, 1), spacing(3)];
            elseif numel(spacing) == n+1 % full specification with n+1 entries
                vec = spacing;
            else
                if nargin < 3
                    name = 'spacing';
                end
                error('Invalid specification for %s', name);
            end
        end

        function vec = expandSizeVec(n, sizes, name)
            sizes = makecol(sizes);
            if isscalar(sizes)
                vec = repmat(sizes, n, 1);
            elseif numel(sizes) == n % full size vec with n entries
                vec = sizes;
            else
                if nargin < 3
                    name = 'spacing';
                end
                error('Invalid specification for %s', name);
            end
        end
    end

    
    methods(Hidden)
        function [row, col] = indToRowCol(g, n)
            % we move along rows first
            [col, row] = ind2sub([g.cols g.rows], n);
        end

    end

    methods(Static)
        function g = demo()
            clf;
            C = 3;
            R = 4;
            height = 3;
            width = 5;
            g = FixedAxisGrid('height', repmat(height, R, 1), 'width', repmat(width, C, 1), 'vspacing', 1, 'hspacing', 1);
            for r = 1:R
                for c = 1:C
                    if r == 2 && c == 1
                        g.axisAt(r, c, 'col_span', 2);
                    elseif r == 2 && c == 2
                        continue;
                    elseif r == 3 && c == 3
                        g.axisAt(r, c, 'row_span', 2);
                    elseif r == 4 && c == 3
                        continue;
                    else
                        g.axisAt(r, c);
                    end
                end
            end
            
            g.update();
            g.overlayDebug();
        end
    end

end
