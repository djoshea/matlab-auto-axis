classdef AutoAxisDefaults
    methods(Static)
        function reset()
            scale = getenv('FIGURE_SIZE_SCALE');
            if isempty(scale)
                scale = 1;
            else
                scale = str2double(scale);
            end
            
            AutoAxis.setenvNum('AutoAxis_TickLength', 0.05 * scale);
            AutoAxis.setenvNum('AutoAxis_TickLineWidth', 0.5 * scale); % not in centimeters, this is stroke width
            AutoAxis.setenvNum('AutoAxis_MarkerWidth', 0.0706 * scale);
            AutoAxis.setenvNum('AutoAxis_MarkerHeight', 0.12 * scale);
            AutoAxis.setenvNum('AutoAxis_MarkerCurvature', 0);
            AutoAxis.setenvNum('AutoAxis_IntervalThickness', 0.1 * scale);
            AutoAxis.setenvNum('AutoAxis_ScaleBarThickness', 0.08* scale); % scale bars should be thinner than intervals since they sit on top
            AutoAxis.setenvNum('AutoAxis_TickLabelOffset', 0.1 * scale);
            AutoAxis.setenvNum('AutoAxis_MarkerLabelOffset', 0.1 * scale); % cm
            AutoAxis.setenvNum('AutoAxis_SmallFontSizeDelta', 1 * scale); % drop font size by 1 pt for ticks and scale bar labels
            
            setenv('AutoAxis_DefaultPadding', '');
            setenv('AutoAxis_DefaultMargins', ''); 
        end
    end
end