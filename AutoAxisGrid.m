classdef AutoAxisGrid < handle
    properties(SetAccess=protected)
        rows
        cols
        Parent
        axMat
    end

    properties(Dependent)
        N
    end
    
    methods
        function g = AutoAxisGrid(rows, cols, figh)
            narginchk(1, 2);
            if nargin < 2 || isempty(cols)
                N = rows;
                rows = floor(sqrt(N));
                cols = ceil(N / rows);
            end
            if nargin < 3
                figh = gcf;
            end
            g.Parent = figh;
            clf(g.Parent);
            g.rows = rows;
            g.cols = cols;
            g.axMat = gobjects(g.rows, g.cols);
        end
        
        function N = get.N(g)
            N = g.rows * g.cols;
        end
        
        function ax = axisAt(g, row, col)
            if nargin < 3
                [row, col] = g.indToRowCol(row);
            end
            assert(row <= g.rows && col <= g.cols, 'Subscripts out of range');
            
            if ishandle(g.axMat(row, col)) && isvalid(g.axMat(row, col))
                ax = g.axMat(row, col);
            else
                pos = g.computePosition(row, col);
                ax = axes('Parent', g.Parent, 'OuterPosition', pos);
                set(ax.Parent, 'CurrentAxes', ax);
                g.axMat(row, col) = ax;
            end
        end
        
        function aa = autoAxisAt(g, varargin)
            ax = g.axisAt(varargin{:});
            aa = AutoAxis(ax);
        end
        
        function [row, col] = indToRowCol(g, n) 
            % we move along rows first
            [col, row] = ind2sub([g.cols g.rows], n);
        end
       
        function pos = computePosition(g, row, col)
            h  = 1 / g.rows;
            w = 1 / g.cols;
            bottom = (g.rows-row) / g.rows;
            left = (col-1) / g.cols;
            pos = [left bottom w h];
        end
    end
        
end