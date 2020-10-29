classdef AutoAxisDefaults
    methods(Static)
        function reset()
            % dont incorporate FIGURE_SIZE_SCALE here, will be handled inside AutoAxis
            AutoAxis.setenvNum('AutoAxis_TickLength', 0.05);
            AutoAxis.setenvNum('AutoAxis_TickLineWidth', 0.5); % not in centimeters, this is stroke width
            AutoAxis.setenvNum('AutoAxis_MarkerWidth', 0.0706);
            AutoAxis.setenvNum('AutoAxis_MarkerHeight', 0.12);
            AutoAxis.setenvNum('AutoAxis_MarkerCurvature', 0);
            AutoAxis.setenvNum('AutoAxis_IntervalThickness', 0.1);
            AutoAxis.setenvNum('AutoAxis_ScaleBarThickness', 0.08); % scale bars should be thinner than intervals since they sit on top
            AutoAxis.setenvNum('AutoAxis_TickLabelOffset', 0.1);
            AutoAxis.setenvNum('AutoAxis_MarkerLabelOffset', 0.1); % cm
            AutoAxis.setenvNum('AutoAxis_SmallFontSizeDelta', 1); % drop font size by 1 pt for ticks and scale bar labels
            AutoAxis.setenvNum('AutoAxis_ScaleBarLabelOffset', 0);
            setenv('AutoAxis_DefaultPadding', '');
            setenv('AutoAxis_DefaultMargins', ''); 
        end
    end
end