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

        axDebug
        PositionSpecified % in centimeters
        PositionCurrent % in centimeters
        
        spacing_x % rows + 1 vector of spacing in cm including left and right edges, in cm, from the edges of Position box
        spacing_y % cols + 1 vector of spacing in cm including top and bottom edges, in cm, from the edges of Position box
    end

    properties(Dependent)
        N
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
                
                g = getappdata(figh, 'AutoAxisGridInstance');
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
            
            p = inputParser();
            p.addParameter('Parent', figh, @(x) isa(x, 'matlab.ui.Figure') || isa(x, 'AutoAxisGrid'));
            p.addParameter('Position', [], @(x) isempty(x) || isvector(x));
            p.addParameter('relHeight', [], @isvector);
            p.addParameter('relWidth', [], @isvector);
            p.parse(varargin{:});

            if nargin < 2 || isempty(cols)
                N = rows;
                rows = floor(sqrt(N));
                cols = ceil(N / rows);
            end

            g.Parent = p.Results.Parent;
            if isa(g.Parent, 'matlab.ui.Figure')
                clf(g.Parent);
                g.figure = g.Parent;
            elseif isa(g.Parent, 'AutoAxisGrid')
                g.figure = g.Parent.figure;
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
            
            % set spacing to reasonable defualts, [left bottom right top]
%             inset = get(g.figure, 'defaultAxesLooseInset');
%             g.spacing_x = [inset(1); repmat(inset(1)+inset(3), rows-1, 1); inset(3)];
%             g.spacing_y = [inset(4); repmat(inset(4)+inset(2), cols-1, 1); inset(2)];

            g.spacing_x = zeros(cols+1, 1);
            g.spacing_y = zeros(rows+1, 1);

            function vals = distribute(vals, n)
                if isempty(vals)
                    vals = ones(n, 1) / n;
                elseif any(isnan(vals))
                    mask = isnan(vals);
                    rem = 1 - nansum(vals);
                    vals(mask) = rem / nnz(mask);
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

        function ax = axisAt(g, row, col)
            if nargin < 3 || isempty(col)
                [row, col] = g.indToRowCol(row);
            end
            assert(row <= g.rows && col <= g.cols, 'Subscripts out of range');
            current = g.handles{row, col};

            if isa(current, 'matlab.graphics.axis.Axes') && isvalid(current)
                ax = g.handles{row, col};
            else
                if ~isempty(current)
                    delete(current);
                end
                pos = g.computePosition(row, col);
                ax = axes('Parent', g.figure);
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

        function gsub = gridAt(g, row, col, rows, cols)
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
                gsub = AutoAxisGrid(rows, cols, 'Parent', g, 'Position', pos);
                g.handles{row, col} = gsub;
            end
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
                        h.Position = g.computePosition(r, c, isRoot);
                        h.Units = u;
                        
                    elseif isa(h, 'AutoAxisGrid')
                        h.updatePositions(g.computePosition(r, c, true));
                    end
                end
            end
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
        
        function [spacing_x, spacing_y] = updateSpacing(g)
            [top, bottom, left, right] = deal(nan(g.rows, g.cols));
            for r = 1:g.rows
                for c = 1:g.cols
                    h = g.handles{r, c};
                    
                    if isa(h, 'matlab.graphics.axis.Axes') && ishandle(h) && isvalid(h)
                        u = h.Units;
                        h.Units = 'centimeters';
                        
                        % left bottom right top
                        inset = max(h.LooseInset, h.TightInset);
                        left(r, c) = inset(1);
                        bottom(r,c) = inset(2);
                        right(r,c) = inset(3);
                        top(r,c) = inset(4);
                        
                        h.Units = u;
                        
                    elseif isa(h, 'AutoAxisGrid')
                        
                        [sx, sy] = h.updateSpacing();
                        left(r, c) = sx(1);
                        right(r, c) = sx(end);
                        top(r, c) = sy(1);
                        bottom(r,c) = sy(end);                        
                    end
                end
            end
                        
            spacing_x = [nanmax(left, [], 1), 0]' + [0, nanmax(right, [], 1)]';
            spacing_y = [nanmax(top, [], 2); 0] + [0; nanmax(bottom, [], 2)];
            
            spacing_x(isnan(spacing_x)) = 0;
            spacing_y(isnan(spacing_y)) = 0;
            
            g.spacing_x = spacing_x;
            g.spacing_y = spacing_y;
        end
        
        function update(g)
            g.updateSpacing();
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
