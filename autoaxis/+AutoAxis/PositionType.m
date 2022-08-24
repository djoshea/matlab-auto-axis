classdef PositionType < uint32
    enumeration
        Unspecified(0)
        
        Top (1)
        Bottom (2)
        VCenter (3)
        Height (4)

        Left (5)
        Right (6) 
        HCenter (7)
        Width (8)
        
        Literal (9) % references an actual location in data coordinates on either X or Y axis. e.g. to implement a rightwards offset from X=20
        
        MarkerDiameter(10) % size the height/width of the marker on a line object

        VFraction (11) % fractional position along vertical axis, uses .frac or fraca in AnchorInfo to store the actual fraction
        HFraction (12) % fractional position along horizontal axis, uses .frac or fraca in AnchorInfo to store the actual fraction
    end

    methods

        function field = getDirectField(pos)
            import AutoAxis.PositionType;

            switch(pos)
                case PositionType.Top 
                    field = 'top';
                case PositionType.Bottom 
                    field = 'bottom';
                case PositionType.Height
                    field = 'height';
                case PositionType.VCenter
                    field = 'vcenter';
                
                case PositionType.Left
                    field = 'left';
                case PositionType.Right
                    field = 'right';
                case PositionType.Width
                    field = 'width';           
                case PositionType.HCenter
                    field = 'hcenter';
               
                otherwise
                    field = '';
            end
        end
        
        
        function tf = isX(pos)
            import AutoAxis.PositionType;
            tf = pos == PositionType.Left | pos == PositionType.Right | ...
                pos == PositionType.HCenter | pos == PositionType.Width | ...
                pos == PositionType.HFraction;
        end

        function tf = isY(pos)
            import AutoAxis.PositionType;
            tf = pos == PositionType.Bottom | pos == PositionType.Top | ...
                pos == PositionType.VCenter | pos == PositionType.Height | ...
                pos == PositionType.VFraction;
        end
        
        function tf = specifiesSize(pos)
            import AutoAxis.PositionType;
            tf = pos == PositionType.Width | pos == PositionType.Height;
        end

        function fields = getLocationFieldsAffected(pos)
            % list PositionType fields potentially affected by this type of anchor
            switch(pos)
                case {PositionType.Top, PositionType.Bottom, PositionType.VCenter, PositionType.Height, PositionType.VFraction}
                    fields = {'top', 'bottom', 'height'};
                case {PositionType.Left, PositionType.Right, PositionType.HCenter, PositionType.Width, PositionType.HFraction}
                    fields = {'left', 'right', 'width'};
            end
        end
        
        function out = flip(pos)
            import AutoAxis.PositionType;
            out = pos;
            for iP = 1:numel(pos)
                switch pos(iP)
                    case PositionType.HCenter
                        posInv = PositionType.HCenter;
                    case PositionType.HFraction
                        posInv = PositionType.HFraction;
                    case PositionType.Left
                        posInv = PositionType.Right;
                    case PositionType.Right
                        posInv = PositionType.Left;
                    case PositionType.VCenter
                        posInv = PositionType.VCenter;
                    case PositionType.VFraction
                        posInv = PositionType.VFraction;
                    case PositionType.Top
                        posInv = PositionType.Bottom;
                    case PositionType.Bottom
                        posInv = PositionType.Top;
                    
                    case {PositionType.Width, PositionType.Height, PositionType.Literal, PositionType.MarkerDiameter}
                        posInv = pos(iP);

                    otherwise
                        error('Not valid for flip');
                end
                out(iP) = posInv;
            end
        end
        
        function align = toHorizontalAlignment(pos)
            import AutoAxis.PositionType;
            switch pos
                case PositionType.HCenter
                    align = 'center';
                case PositionType.Left
                    align = 'left';
                case PositionType.Right
                    align = 'right';
                otherwise
                    error('Not valid for horizontal alignment');
            end
        end
        
        function align = toVerticalAlignment(pos)
            import AutoAxis.PositionType;
            switch pos
                case PositionType.VCenter
                    align = 'middle';
                case PositionType.Top
                    align = 'top';
                case PositionType.Bottom
                    align = 'bottom';
                otherwise
                    error('Not valid for vertical alignment');
            end
        end
    end
    
    methods(Static)
        function pos = horizontalAlignmentToPositionType(align)
            import AutoAxis.PositionType;
            switch align
                case 'center'
                    pos = PositionType.HCenter;
                case 'left'
                    pos = PositionType.Left;
                case 'right'
                    pos = PositionType.Right;
                otherwise
                    error('Unknown horizontal alignment string');
            end
        end
            
        function pos = verticalAlignmentToPositionType(align)
            import AutoAxis.PositionType;
            switch align
                case 'middle'
                    pos = PositionType.VCenter;
                case 'top'
                    pos = PositionType.Top;
                case 'bottom'
                    pos = PositionType.Bottom;
                otherwise
                    error('Unknown vertical alignment string');
            end
        end
    end
end
