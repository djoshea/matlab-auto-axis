classdef FullPositionSpec
    % this class specifies the full location of an object relative to
    % another box's boundaries, e.g. relative to the axis.
    
    properties
        posX AutoAxis.PositionType = AutoAxis.PositionType.Left
        outsideX logical = false;
        matchSizeY logical = false;
        offsetX = 0;
        
        posY AutoAxis.PositionType = AutoAxis.PositionType.Top
        outsideY logical = false;
        matchSizeX logical = false;
        offsetY = 0;
    end
    
    properties(Dependent)
        negOffsetX 
        negOffsetY
    end
   
    methods(Static)
        function spec = outsideRightFullHeight(padding)
            if nargin < 1
                padding = 'axisPaddingRight';
            end
            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Right;
            spec.outsideX = true;
            spec.posY = AutoAxis.PositionType.HCenter;
            spec.matchSizeY = 1;
            spec.offsetX = padding;
        end
        
        function spec = insideRightFullHeight(padding)
            if nargin < 1
                padding = 'axisPaddingRight';
            end
            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Right;
            spec.outsideX = false;
            spec.posY = AutoAxis.PositionType.HCenter;
            spec.matchSizeY = 1;
            spec.offsetX = padding;
        end
        
        function spec = insideBottomRight(paddingX, paddingY)
            if nargin < 1
                paddingX = 'tickLabelOffset';
            end
            if nargin < 2
                paddingY = paddingX;
            end
            
            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Right;
            spec.outsideX = false;
            spec.offsetX = paddingX;
            spec.posY = AutoAxis.PositionType.Bottom;
            spec.offsetY = paddingY;
            spec.outsideY = false;
        end

        function spec = outsideTopRight(paddingX, paddingY)
            if nargin < 1
                paddingX = 0;
            end
            if nargin < 2
                paddingY = 'tickLabelOffset';
            end
            
            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Right;
            spec.outsideX = false;
            spec.offsetX = paddingX;
            spec.posY = AutoAxis.PositionType.Top;
            spec.offsetY = paddingY;
            spec.outsideY = true;
        end

        function spec = outsideTopFullWidth(paddingX, paddingY)
            if nargin < 1
                paddingX = 0;
            end
            if nargin < 2
                paddingY = 'tickLabelOffset';
            end
            
            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Right;
            spec.outsideX = false;
            spec.offsetX = paddingX;
            spec.matchSizeX = true;
            spec.posY = AutoAxis.PositionType.Top;
            spec.offsetY = paddingY;
            spec.outsideY = true;
        end
        
        function spec = outsideRightBottom(paddingX)
            if nargin < 1
                paddingX = 'axisPaddingRight';
            end

            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Right;
            spec.outsideX = true;
            spec.posY = AutoAxis.PositionType.Bottom;
            spec.matchSizeY = false;
            spec.offsetX = paddingX;
        end
        
        function spec = insideRightTop(paddingX)
            if nargin < 1
                paddingX = 'axisPaddingRight';
            end

            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Right;
            spec.outsideX = false;
            spec.posY = AutoAxis.PositionType.Top;
            spec.matchSizeY = false;
            spec.offsetX = paddingX;
        end
        
        function spec = outsideRightTop(paddingX)
            if nargin < 1
                paddingX = 'axisPaddingRight';
            end

            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Right;
            spec.outsideX = true;
            spec.posY = AutoAxis.PositionType.Top;
            spec.matchSizeY = false;
            spec.offsetX = paddingX;
        end
        
        function spec = leftOutside(paddingX)
            if nargin < 1
                paddingX = 'axisPaddingLeft';
            end
            
            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Left;
            spec.outsideX = true;
            spec.offsetX = paddingX;
            
            spec = spec.unspecifyY();
        end
           
        function spec = leftInside(paddingX)
            if nargin < 1
                paddingX = 0;
            end
            
            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Left;
            spec.outsideX = false;
            spec.offsetX = paddingX;
            
            spec = spec.unspecifyY();
        end
        
        function spec = insideLeftTop(paddingX)
            if nargin < 1
                paddingX = 'axisPaddingLeft';
            end

            spec = AutoAxis.FullPositionSpec;
            spec.posX = AutoAxis.PositionType.Left;
            spec.outsideX = false;
            spec.posY = AutoAxis.PositionType.Top;
            spec.matchSizeY = false;
            spec.offsetX = paddingX;
        end
    end
    
    methods
        function spec = unspecifyY(spec)
            assert(nargout == 1);
            spec.posY = AutoAxis.PositionType.Unspecified;
            spec.offsetY = 0;
            spec.matchSizeY = 0;
            spec.outsideY = false;
        end
        function v = get.negOffsetX(spec)
            if isscalar(spec.offsetX)
                v = -spec.offsetX;
            elseif ischar(spec.offsetX)
                if strncmp(spec.offsetX, '-', 1)
                    v = spec.offsetX(2:end);
                else
                    v = ['-' spec.offsetX];
                end
            end
        end
        
        function v = get.negOffsetY(spec)
            if isscalar(spec.offsetY)
                v = -spec.offsetY;
            elseif ischar(spec.offsetY)
                if strncmp(spec.offsetY, '-', 1)
                    v = spec.offsetY(2:end);
                else
                    v = ['-' spec.offsetY];
                end
            end
        end
                    
        function ai = buildAnchors(spec, h, ha, varargin)
            p = inputParser();
            p.addParameter('desc', '', @ischar);
            p.parse(varargin{:});
            desc = p.Results.desc;
            
            % build all anchors which anchor object h to ha
            import AutoAxis.AnchorInfo;
            import AutoAxis.PositionType;
            
            if spec.matchSizeY
                ai = AnchorInfo(h, PositionType.Top, ha, PositionType.Top, 0, desc, 'translateDontScale', true);
                ai(end+1) = AnchorInfo(h, PositionType.Bottom, ha, PositionType.Bottom, 0, desc, 'translateDontScale', false);
            elseif ~spec.outsideY
                ai = AnchorInfo(h, spec.posY, ha, spec.posY, spec.negOffsetY, desc);
            else
                ai = AnchorInfo(h, spec.posY.flip(), ha, spec.posY, spec.offsetY, desc);
            end
            
            if spec.matchSizeX
                ai(end+1) = AnchorInfo(h, PositionType.Left, ha, PositionType.Left, 0, desc, 'translateDontScale', true);
                ai(end+1) = AnchorInfo(h, PositionType.Right, ha, PositionType.Right, 0, desc, 'translateDontScale', false);
            elseif ~spec.outsideX
                ai(end+1) = AnchorInfo(h, spec.posX, ha, spec.posX, spec.negOffsetX, desc);
            else
                ai(end+1) = AnchorInfo(h, spec.posX.flip(), ha, spec.posX, spec.offsetX, desc);
            end  
        end
    end
end
