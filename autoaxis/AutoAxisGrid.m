classdef AutoAxisGrid < handle
    % AutoAxisGrid

    properties(SetAccess=protected)
        rows
        cols
        Parent

        relHeight
        relWidth

        figure
        handles % rows x col cell

        axhOverlay % optional overlay axis, see add overlay axis
        
        PositionSpecified % in centimeters
        PositionCurrent % in centimeters
        
        isRoot = false;
        rootGrid_I
        
        spacing_x_I
        spacing_y_I
    end
    
    properties(Dependent)
        spacing_x % rows + 1 vector of spacing in cm including left and right edges, in cm, from the edges of Position box
        spacing_y % cols + 1 vector of spacing in cm including top and bottom edges, in cm, from the edges of Position box
    end

    properties(Dependent)
        N
        rootGrid
    end
    
    methods(Static)
        function updateFigure(figh)
            % call auto axis update for every managed axis in a figure
            if nargin < 1
                figh = gcf;
            end
            
            g = AutoAxisGrid.recoverForFigure(figh);
            if ~isempty(g) && isvalid(g)
                g.update;
            end
        end
        
        function ma = recoverForFigure(figh)
            % recover the MultiAxis instance associated with figure figh
            if nargin < 1, figh = gcf; end
            ma = getappdata(figh, 'AutoAxisGridInstance');
        end
    end

    methods
        function g = AutoAxisGrid(varargin)
            % AutoAxisGrid(figh, rows, cols, ...)
            % AutoAxisGrid(rows, cols, ...)
            % AutoAxisGrid(figh) to recover
            
            % fetch existing instance
            if numel(varargin) < 2
                if isempty(varargin)
                    figh = gcf;
                else
                    figh = varargin{1};
                end
                assert(isa(figh, 'matlab.ui.Figure'));
                
                g = AutoAxisGrid.recoverForFigure(figh);
                if isempty(g)
                    error('No AutoAxisGrid installed for figure. Install using AutoAxisGrid([figh], rows, cols, ...)');
                end
                return;
            end
                
            % install new instance
            if isa(varargin{1}, 'matlab.ui.Figure')
                figh = varargin{1};
                varargin = varargin(2:end);
            else
                figh = gcf;
            end
            rows = varargin{1};
            cols = varargin{2};
            varargin = varargin(3:end);
            
            if nargin < 2 || isempty(cols)
                N = rows;
                rows = floor(sqrt(N));
                cols = ceil(N / rows);
            end
            
            p = inputParser();
            p.addParameter('Parent', figh, @(x) isa(x, 'matlab.ui.Figure') || isa(x, 'AutoAxisGrid'));
            p.addParameter('Position', [], @(x) isempty(x) || isvector(x));
            p.addParameter('relHeight', [], @isvector);
            p.addParameter('relWidth', [], @isvector);
            p.parse(varargin{:});

            g.Parent = p.Results.Parent;
            if isa(g.Parent, 'matlab.ui.Figure')
                clf(g.Parent);
                g.figure = g.Parent;
                g.isRoot = true;
            elseif isa(g.Parent, 'AutoAxisGrid')
                g.figure = g.Parent.figure;
                g.isRoot = false;
                g.rootGrid_I = g.Parent.rootGrid;
            else
                error('Unknown Parent type');
            end

            g.PositionSpecified = p.Results.Position;
            if isempty(g.PositionSpecified)
                u = g.figure.Units;
                g.figure.Units = 'centimeters';
                g.PositionCurrent = [0 0 g.figure.Position(3:4)];
                g.figure.Units = u;
            else
                g.PositionCurrent = g.PositionSpecified;
            end
            g.rows = rows;
            g.cols = cols;
            g.handles = cell(g.rows, g.cols);
            
            g.spacing_x_I = nan(cols+1, 1);
            g.spacing_y_I = nan(rows+1, 1);

            function vals = distribute(vals, n)
                if isempty(vals)
                    vals = ones(n, 1) / n;
                elseif any(isnan(vals))
                    mask = isnan(vals);
                    rem = 1 - nansum(vals);
                    vals(mask) = rem / nnz(mask);
                else
                    vals = vals / sum(vals, 'omitnan');
                end
            end
            g.relHeight = distribute(p.Results.relHeight, g.rows);
            g.relWidth = distribute(p.Results.relWidth, g.cols);
            
            if isa(g.Parent, 'matlab.ui.Figure')
                setappdata(g.Parent, 'AutoAxisGridInstance', g);
            end
        end

        function N = get.N(g)
            N = g.rows * g.cols;
        end
        
        function rootGrid = get.rootGrid(g)
            if g.isRoot
                rootGrid = g;
            else
                g.rootGrid = g.rootGrid_I;
            end
        end

        function ax = axisAt(g, row, col, varargin)
            if nargin < 3 || isempty(col)
                [row, col] = g.indToRowCol(row);
            end
            p = inputParser();
            p.addParameter('polar', false, @islogical);
            p.parse(varargin{:});
            
            
            assert(row <= g.rows && col <= g.cols, 'Subscripts out of range');
            current = g.handles{row, col};

            if isa(current, 'matlab.graphics.axis.Axes') && isvalid(current)
                ax = g.handles{row, col};
                set(g.figure, 'CurrentAxes', ax);
            else
                if ~isempty(current)
                    delete(current);
                end
                pos = g.computePosition(row, col);
                if p.Results.polar
                    ax = polaraxes('Parent', g.figure);
                else
                    ax = axes('Parent', g.figure);
                end
                u = ax.Units;
                ax.Units = 'centimeters';
                ax.Position = pos;
                ax.LooseInset = ax.TightInset;
                ax.Units = u;
                set(ax.Parent, 'CurrentAxes', ax);
                g.handles{row, col} = ax;
            end
        end

        function aa = autoAxisAt(g, varargin)
            ax = g.axisAt(varargin{:});
            aa = AutoAxis(ax);
        end

        function gsub = gridAt(g, row, col, rows, cols, varargin)
            if isempty(col)
                [row, col] = g.indToRowCol(row);
            end
            assert(row <= g.rows && col <= g.cols, 'Subscripts out of range');
            current = g.handles{row, col};

            if isa(current, 'AutoAxisGrid') && isvalid(current)
                gsub = g.handles{row, col};
            else
                if ~isempty(current)
                    delete(current);
                end
                pos = g.computePosition(row, col);
                gsub = AutoAxisGrid(rows, cols, 'Parent', g, 'Position', pos, varargin{:});
                g.handles{row, col} = gsub;
            end
        end
        
        function axhOverlay = getOverlayAxis(g)
            if isempty(g.axhOverlay) || ~isvalid(g.axhOverlay)
                g.axhOverlay = axes('Parent', g.figure, 'Position', [0 0 1 1], 'Color', 'none', ...
                    'XLim', [0 1], 'YLim', [0 1], 'Tag', 'AutoAxisGrid Overlay', 'HitTest', 'off');
            
                uistack(g.axhOverlay, 'top');
                hold(g.axhOverlay, 'on');
                axis(g.axhOverlay, 'off');
            end
            axhOverlay = g.axhOverlay;
        end
        
        function updatePositions(g, position)
            % update my position
            if isempty(g.PositionSpecified)
                isRoot = true;
                % root, set to figure coords
                u = g.figure.Units;
                g.figure.Units = 'centimeters';
                g.PositionCurrent = [0 0 g.figure.Position(3:4)];
                g.figure.Units = u;
            else
                isRoot = false;
                g.PositionCurrent = position;
            end
                
            % ensure that spacing_x and spacing_y are up to date
            g.updateSpacing();
            
            for r = 1:g.rows
                for c = 1:g.cols
                    h = g.handles{r, c};
                    
                    if isa(h, 'matlab.graphics.axis.Axes') && ishandle(h) && isvalid(h)
                        u = h.Units;
                        h.Units = 'centimeters';
                        h.PositionConstraint = 'innerposition';
                        h.Position = g.computePosition(r, c, isRoot);
                        h.Units = u;
                        
                    elseif isa(h, 'AutoAxisGrid')
                        h.updatePositions(g.computePosition(r, c, true));
                    end
                end
            end
        end
        
        function v = get.spacing_x(g)
            v = g.spacing_x_I;
            v(isnan(v)) = 0;
        end
        
        function v = get.spacing_y(g)
            v = g.spacing_y_I;
            v(isnan(v)) = 0;
        end
        
        function set.spacing_x(g, v)
            % support 2 or 3 elements in lieu of specifying all of them
            assert(isvector(v));
            new = g.spacing_x_I;
            if isempty(new)
                new = zeros(g.rows, 1);
            end
            if numel(v) == 2
                new(1) = v(1);
                new(end) = v(2);
            elseif numel(v) == 3
                new(1) = v(1);
                new(2:end-1) = v(2);
                new(end) = v(3);
            else
                assert(numel(v) == g.cols + 1, 'Value must have 2, 3, or cols+1 elements');
                new = v;
            end
            g.spacing_x_I = new;
        end
        
        function set.spacing_y(g, v)
            % support 2 or 3 elements in lieu of specifying all of them
            assert(isvector(v));
            new = g.spacing_y_I;
            if isempty(new)
                new = zeros(g.cols, 1);
            end
            if numel(v) == 2
                new(1) = v(1);
                new(end) = v(2);
            elseif numel(v) == 3
                new(1) = v(1);
                new(2:end-1) = v(2);
                new(end) = v(3);
            else
                assert(numel(v) == g.rows + 1, 'Value must have 2, 3, or cols+1 elements');
                new = v;
            end
            g.spacing_y_I = new;
        end
    end
    
    methods(Hidden)
        function [row, col] = indToRowCol(g, n)
            % we move along rows first
            [col, row] = ind2sub([g.cols g.rows], n);
        end

        function pos = computePosition(g, row, col, includeOuterSpacing)
            % if includeOuterSpacing is false, the spacing around the edges
            % should be ignored, as though this spacing has already been
            % included in the computation of PositionCurrent, as is the
            % case for nested AutoAxisGrids
            
            if nargin < 4
                includeOuterSpacing = true;
            end
            
            spacing_x = g.spacing_x; %#ok<*PROPLC>
            spacing_y = g.spacing_y;
            spacing_x(isnan(spacing_x)) = 0;
            spacing_y(isnan(spacing_y)) = 0;
            
            if ~includeOuterSpacing
                spacing_x([1 end]) = 0;
                spacing_y([1 end]) = 0;
            end
            
            nonSpaceW = g.PositionCurrent(3) - sum(spacing_x);
            nonSpaceH = g.PositionCurrent(4) - sum(spacing_y);
            w = g.relWidth(col) * nonSpaceW;
            h = g.relHeight(row) * nonSpaceH;

            left = g.PositionCurrent(1) + sum(g.relWidth(1:col-1)) * nonSpaceW + sum(spacing_x(1:col));
            
            % top - heights of me and above me - spacing above me
            bottom = g.PositionCurrent(2) + g.PositionCurrent(4) - sum(g.relHeight(1:row)) * nonSpaceH - sum(spacing_y(1:row));

            MIN_SIZE = 0.5;
            if w < MIN_SIZE || h < MIN_SIZE
                warning('AutoAxisGrid elements do not fit within space respecting LooseInset, expanding');
                if w <  MIN_SIZE, w = MIN_SIZE; end
                if h <  MIN_SIZE, h = MIN_SIZE; end
            end
            
            pos = [left bottom w h];
        end
        
        function updateSpacing(g)
            % only need to update if any are left as nan meaning not yet
            % specified
            if ~any(isnan(g.spacing_x_I)) && ~any(isnan(g.spacing_y_I))
                return;
            end
            
            [top, bottom, left, right] = deal(nan(g.rows, g.cols));
            for r = 1:g.rows
                for c = 1:g.cols
                    h = g.handles{r, c};
                    
                    if isa(h, 'matlab.graphics.axis.Axes') && ishandle(h) && isvalid(h)
                        u = h.Units;
                        h.Units = 'centimeters';
                        
                        aa = AutoAxis.recoverForAxis(h);
                        if ~isempty(aa)
                            % cheaper than calling auto axis update()
%                             aa.updateAxisInset();
                            inset = aa.axisMargin;
                        else
                            % left bottom right top
                            if strcmp(h.Visible, 'off') 
                                if strcmp(h.LooseInsetMode, 'manual')
                                    inset = h.LooseInset;
                                else
                                    inset = [0 0 0 0];
                                end
                            else
                                inset = max(h.LooseInset, h.TightInset);
                            end
                        end
                        left(r, c) = inset(1);
                        bottom(r,c) = inset(2);
                        right(r,c) = inset(3);
                        top(r,c) = inset(4);
                        
                        h.Units = u;
                        
                    elseif isa(h, 'AutoAxisGrid')
                        
                        h.updateSpacing();
                        left(r, c) = h.spacing_x(1);
                        right(r, c) = h.spacing_x(end);
                        top(r, c) = h.spacing_y(1);
                        bottom(r,c) = h.spacing_y(end);                        
                    end
                end
            end
                        
            spacing_x = [nanmax(left, [], 1), 0]' + [0, nanmax(right, [], 1)]'; %#ok<*PROP>
            spacing_y = [nanmax(top, [], 2); 0] + [0; nanmax(bottom, [], 2)];
            
            spacing_x(isnan(spacing_x)) = 0;
            spacing_y(isnan(spacing_y)) = 0;
            
            % use the computed values to update the nans in spacing_x and
            % spacing_y (considered unknown)
            g.spacing_x_I(isnan(g.spacing_x_I)) = spacing_x(isnan(g.spacing_x_I));
            g.spacing_y_I(isnan(g.spacing_y_I)) = spacing_y(isnan(g.spacing_y_I));
        end
        
        function update(g)
            g.rootGrid.updatePositions();
            AutoAxis.updateFigure();
        end
    end

    methods(Static)
        function g = demo()
            clf;
            g = AutoAxisGrid(3, 3);
            g.axisAt(1, 1);
            g.axisAt(1, 2);
            g.axisAt(1, 3);
            g.axisAt(2, 1);
            g.axisAt(2, 2); 
            g.axisAt(3, 1); 
            
            g1 = g.gridAt(3, 2, 3, 1);
            g1.axisAt(1); g1.axisAt(2); g1.axisAt(3);

            g2 = g.gridAt(2, 3, 1, 3);
            g2.axisAt(1); g2.axisAt(2); g2.axisAt(3);
            
            g3 = g.gridAt(3, 3, 3, 3);
            g3.axisAt(1); g3.axisAt(2); g3.axisAt(3); 
            g3.axisAt(4); g3.axisAt(5); g3.axisAt(6); 
            g3.axisAt(7); g3.axisAt(8); g3.axisAt(9);
            
%             hax = findobj(g.figure, 'Type', 'Axes');
%             for i = 1:numel(hax)
%                 hax(i).LooseInset = hax(i).TightInset;
%             end
            
            g.updatePositions();
        end
    end

end
