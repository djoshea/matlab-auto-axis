classdef AutoAxisGrid < handle
    properties(SetAccess=protected)
        rows
        cols
        Parent
        
        relHeight
        relWidth
        
        figure
        handles % rows x col cell
        
        axDebug
        Position
    end

    properties(Dependent)
        N
    end
    
    methods
        function g = AutoAxisGrid(rows, cols, varargin)
            p = inputParser();
            p.addParameter('Parent', gcf, @(x) isa(x, 'matlab.ui.Figure') || isa(x, 'AutoAxisGrid'));
            p.addParameter('Position', [0 0 1 1], @isvector);
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
            elseif isa(g.Parent, 'AutoAxisGrid');
                g.figure = g.Parent.figure;
            else
                error('Unknown Parent type');
            end
            
            g.Position = p.Results.Position;
            g.rows = rows;
            g.cols = cols;
            g.handles = cell(g.rows, g.cols);
            
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
           
            if isa(current, 'matlab.graphics.axis.Axes') && ishandle(current) && isvalid(current)
                ax = g.handles{row, col};
            else
                if ~isempty(current)
                    delete(current);
                end
                pos = g.computePosition(row, col);
                ax = axes('Parent', g.figure, 'OuterPosition', pos);
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
           
            if isa(current, 'AutoAxisGrid') && ishandle(current) && isvalid(current)
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
        
        function [row, col] = indToRowCol(g, n) 
            % we move along rows first
            [col, row] = ind2sub([g.cols g.rows], n);
        end
       
        function pos = computePosition(g, row, col)
            w = g.relWidth(col) * g.Position(3);
            h = g.relHeight(row) * g.Position(4);
            
            left = g.Position(1) + sum(g.relWidth(1:col-1)) * g.Position(3);
            bottom = g.Position(2) + g.Position(4) - sum(g.relHeight(1:row)) * g.Position(4);
%             
%             bottom = (g.rows-row) / g.rows * g.Position(4) + g.Position(2);
%             left = (col-1) / g.cols * g.Position(3) + g.Position(1);
            pos = [left bottom w h];
        end
        
%         oldCA = gca; % cache gca
%                 ax.axhDraw = axes('Position', [0 0 1 1], 'Parent', figh);
%                 axis(ax.axhDraw, axis(ax.axh));
%                 axes(oldCA); % restore old gca
    end
    
    methods(Static)
        function g = demo()
            ax = gobjects(8, 1);
            g = AutoAxisGrid(2, 2);
            ax(1) = g.axisAt(1, 1);
            
            g1 = g.gridAt(2, 1, 1, 3);
            ax(2) = g1.axisAt(1); ax(3) = g1.axisAt(2); ax(4) = g1.axisAt(3);
            
            g2 = g.gridAt(1, 2, 3, 1);
            ax(5) = g2.axisAt(1); ax(6) = g2.axisAt(2); ax(7) = g2.axisAt(3);
            
            ax(8) = g.axisAt(2, 2);
            
            set(ax, 'LooseInset', get(ax(1), 'TightInset'));
        end
    end
        
end