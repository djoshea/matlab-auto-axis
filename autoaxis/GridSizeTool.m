classdef GridSizeTool < handle
% encapsulates comptuations related to determining axes sizing within FixedAxisGrid
% one GridSizeTool will be used for rows and cols separately

    properties
        N % this dimension size
        M % other dimension size

        % these are specifications (NaN where left unspecified)
        total (1, 1)
        rel (:, 1)
        abs (:, 1)
        data_scale (:, :, :) % typically N x M 

        spacing (:, 1) % N+1
    end

    methods 
        function gst = GridSizeTool(N, M, varargin)
            % TODO add a quick set 
            p = inputParser();
            p.addParameter('total', NaN, @isscalar);
            p.addParameter('rel', [], @(x) isempty(x) || isvector(x));
            p.addParameter('abs', [], @(x) isempty(x) || isvector(x));
            p.addParameter('data_scale', [], @(x) isempty(x) || isnumeric(x));
            p.addParameter('spacing', [], @(x) isempty(x) || isvector(x));
            p.parse(varargin{:});

            gst.N = N;
            gst.M = M;

            gst.total = p.Results.total;
            gst.rel = p.Results.rel;
            gst.abs = p.Results.abs;
            gst.data_scale = p.Results.data_scale;
            gst.spacing = p.Results.spacing;
        end

        function vec = expandSpacingVec(gst, spacing, name)
            n = gst.N;
            spacing = spacing(:);
            if isempty(spacing)
                vec = nan(n+1, 1);
            elseif isscalar(spacing)
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

        function vec = expandSizeVec(gst, sizes, name)
            n = gst.N;
            sizes = sizes(:);
            if isempty(sizes)
                vec = nan(n, 1);
            elseif isscalar(sizes)
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
        
        function s = expandDataScale(gst, scale, name)
            if isempty(scale)
                s = nan(gst.N, gst.M);
            elseif isvector(scale) && numel(scale) == gst.N
                s = repmat(scale(:), 1, gst.M);
            elseif size(scale, 1) == gst.N && size(scale, 2) == gst.M && ndims(scale) <= 3
                s = scale;
            else
                if nargin < 3
                    name = 'data_scale';
                end
                error('Invalid specification for %s', name);
            end
        end
        
        function set.rel(gst, v) 
            gst.rel = gst.expandSizeVec(v, 'rel');
        end

        function set.abs(gst, v) 
            gst.abs = gst.expandSizeVec(v, 'abs');
        end

        function set.spacing(gst, v) 
            gst.spacing = gst.expandSpacingVec(v, 'spacing');
        end

        function set.data_scale(gst, v)
            gst.data_scale = gst.expandDataScale(v, 'data_scale');
        end
        
        function [sizes, spacing] = compute_sizes(gst, current_total, current_data_spans)
            % computes current sizes of each element given:
            % - the current total extent (will be used only if the total size cannot be specified)
            % - the data spans of element (as N x M) 

            assert(isscalar(current_total) && ~isnan(current_total));
            assert(isequal(ddsize(current_data_spans), [gst.M, gst.N]));

            % start with absolutely specified sizes
            sizes = gst.abs; 
            spacing = gst.spacing;
            
            % data_scale is a 3d array where each page is M x N. For each o, Where the value data_scale(:, :, o) is not NaN,
            % all of these axes should be presented in a common scale. The actual value determines the relative size of that
            % particular axis relative to the others, but typically the values are 1 or true if the sizes should match the 
            % data span (XLim or YLim).
            

            % compute the data to paper scale factor for each individual scale (dim 3 of data_scale)

            %  each data scale define relative scal
                        
            
            % then compute relative sizes, considering both rel and data_scale

        end

    end


end
