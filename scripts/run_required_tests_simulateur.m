function results = run_required_tests_simulateur(modelName, whichTest, cfg)
% run_required_tests_simulateur
% Lance les cas exigés par la grille de manière simple et reproductible.

    if nargin < 1 || strlength(string(modelName)) == 0
        modelName = "Simulateur_VRemise_eq06";
    end
    if nargin < 2 || strlength(string(whichTest)) == 0
        whichTest = "all";
    end
    if nargin < 3 || isempty(cfg)
        cfg = default_simulateur_config();
    end

    modelName = char(modelName);
    whichTest = char(whichTest);

    if ~bdIsLoaded(modelName)
        load_system(modelName);
    end

    update_simulateur_VRemise_eq06(modelName, cfg);

    allTests = { ...
        'beam_only', ...
        'resonance', ...
        'static_deflection', ...
        'drop_release', ...
        'mass_100g', ...
        'force_1000N', ...
        'mass_100g_comp', ...
        'calibration'};

    if strcmpi(whichTest, 'all')
        testsToRun = allTests;
    else
        testsToRun = {whichTest};
    end

    results = struct();
    results.model = modelName;
    results.request = whichTest;
    results.timestamp = datestr(now);
    results.cases = struct([]);

    for k = 1:numel(testsToRun)
        caseName = testsToRun{k};
        caseCfg = cfg;

        switch lower(caseName)
            case 'beam_only'
                caseCfg.mass.tipMass = 0;
                caseCfg.force.value = 0;
                caseCfg.control.positionSetpoint = 0;
                caseCfg.control.currentSetpoint = 0;

            case 'resonance'
                caseCfg.mass.tipMass = 0;
                caseCfg.force.value = 0;
                caseCfg.control.positionSetpoint = 0;
                caseCfg.control.currentSetpoint = 0;

            case 'static_deflection'
                caseCfg.mass.tipMass = 0.05;
                caseCfg.force.value = 0;
                caseCfg.control.positionSetpoint = 0;
                caseCfg.control.currentSetpoint = 0;

            case 'drop_release'
                caseCfg.mass.tipMass = 0;
                caseCfg.force.value = 0;
                caseCfg.control.positionSetpoint = 0;
                caseCfg.control.currentSetpoint = 0;

            case 'mass_100g'
                caseCfg.mass.tipMass = 0.1;
                caseCfg.mass.startTime = 0.5;
                caseCfg.force.value = 0;

            case 'force_1000n'
                caseCfg.mass.tipMass = 0;
                caseCfg.force.value = 1000;

            case 'mass_100g_comp'
                caseCfg.mass.tipMass = 0.1;
                caseCfg.mass.startTime = 0.5;
                caseCfg.force.value = -0.1 * 9.81;

            case 'calibration'
                caseCfg.mass.tipMass = cfg.calibration.mass50g;
                caseCfg.force.value = 0;

            otherwise
                error('Cas de test non reconnu: %s', caseName);
        end

        update_simulateur_v7_eq06(modelName, caseCfg);
        simOut = sim(modelName, ...
            'StopTime', num2str(caseCfg.sim.stopTime), ...
            'ReturnWorkspaceOutputs', 'on');

        pos = localTryGetSeries(simOut, 'position_lame');
        vel = localTryGetSeries(simOut, 'vitesse_actionneur');

        beamExport = build_system_export_struct(caseCfg);

        caseResult = struct();
        caseResult.name = caseName;
        caseResult.cfg = caseCfg;
        caseResult.prediction_f_n_hz = beamExport.beam.f_n_hz;
        caseResult.prediction_static_tip_deflection = beamExport.beam.static_deflection_tip_mass;
        caseResult.prediction_static_external_force_deflection = beamExport.beam.static_deflection_external_force;
        caseResult.position = pos;
        caseResult.velocity = vel;

        if strcmpi(caseName, 'calibration')
            caseResult.calibration_points = struct( ...
                'mass10g', cfg.calibration.mass50g, ...
                'mass20g', cfg.calibration.mass20g, ...
                'mass50g', cfg.calibration.mass50g, ...
                'mass70g', cfg.calibration.mass70g);
        end

        results.cases(end+1) = caseResult; %#ok<AGROW>
    end
end

function series = localTryGetSeries(simOut, varName)
    series = struct('time', [], 'values', []);

    try
        data = simOut.get(varName);
    catch
        return
    end

    if isa(data, 'timeseries')
        series.time = data.Time;
        series.values = squeeze(data.Data);
    elseif isstruct(data) && isfield(data, 'time') && isfield(data, 'signals')
        series.time = data.time;
        series.values = squeeze(data.signals.values);
    elseif isstruct(data) && isfield(data, 'Time') && isfield(data, 'Data')
        series.time = data.Time;
        series.values = squeeze(data.Data);
    end
end
