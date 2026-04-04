function report = update_simulateur_v7_eq06(modelName, cfg)
% update_simulateur_v7_eq06
% Met à jour les paramètres visibles du modèle Simulink.

    if nargin < 1 || strlength(string(modelName)) == 0
        modelName = "Simulateur_V7_eq06";
    end
    if nargin < 2 || isempty(cfg)
        cfg = default_simulateur_config();
    end

    modelName = char(modelName);
    if ~bdIsLoaded(modelName)
        load_system(modelName);
    end

    assignin('base', 'SIM_CFG', cfg);

    export = build_system_export_struct(cfg);
    exportFields = fieldnames(export.workspace);
    for i = 1:numel(exportFields)
        assignin('base', exportFields{i}, export.workspace.(exportFields{i}));
    end

    report = struct();
    report.model = modelName;
    report.updated = {};
    report.failed = {};
    report.notes = {};

    trySetModelParam('StopTime', num2str(cfg.sim.stopTime, 16));
    trySetModelParam('FixedStep', num2str(cfg.sim.fixedStep, 16));
    trySetModelParam('SolverType', 'Fixed-step');
    trySetModelParam('ReturnWorkspaceOutputs', 'on');
    trySetModelParam('SaveOutput', 'on');
    trySetModelParam('OutputSaveName', 'yout');

    tryBlockValue([modelName '/Lame/Longueur'], cfg.beam.L);
    tryBlockValue([modelName '/Lame/Hauteur'], cfg.beam.h);
    tryBlockValue([modelName '/Lame/Base'], cfg.beam.base);
    tryBlockValue([modelName '/Lame/Distance du plateau'], cfg.beam.plateauDistance);
    tryBlockValue([modelName '/Lame/Module de young'], cfg.beam.E);
    tryBlockValue([modelName '/Lame/densité'], cfg.beam.rho);
    tryBlockValue([modelName '/Lame/Amortissement'], cfg.beam.c);
    tryBlockValue([modelName '/Lame/Masse entrante'], cfg.mass.tipMass);
    tryBlockValue([modelName '/Lame/Force gravitationnelle'], 9.81);

    trySetBlockParam([modelName '/Lame/To Workspace1'], 'VariableName', 'positionlame');
    trySetBlockParam([modelName '/Lame/To Workspace1'], 'SaveFormat', 'Structure With Time');
    trySetBlockParam([modelName '/Lame/To Workspace2'], 'VariableName', 'vitesselame');
    trySetBlockParam([modelName '/Lame/To Workspace2'], 'SaveFormat', 'Structure With Time');

    trySetPID([modelName '/ARDUINO/Régulateur De Position/Discrete PID Controller'], cfg.control.positionPID);
    trySetPID([modelName '/ARDUINO/Régulateur De Courant/Discrete PID Controller'], cfg.control.currentPID);

    report.notes = {
        'Les chemins de blocs sont basés sur le modèle courant.'
        'Si un bloc a été renommé localement, ajuste simplement son chemin dans ce script.'
        'Les signaux positionlame et vitesselame sont forcés dans les To Workspace de la lame.'};

    try
        save_system(modelName);
    catch ME
        report.failed{end+1} = sprintf('save_system: %s', ME.message);
    end

    function trySetModelParam(paramName, paramValue)
        try
            set_param(modelName, paramName, paramValue);
            report.updated{end+1} = sprintf('Model param: %s', paramName);
        catch ME
            report.failed{end+1} = sprintf('Model param %s: %s', paramName, ME.message);
        end
    end

    function tryBlockValue(blockPath, val)
        try
            set_param(blockPath, 'Value', num2str(val, 16));
            report.updated{end+1} = sprintf('Value: %s', blockPath);
        catch ME
            report.failed{end+1} = sprintf('Value %s: %s', blockPath, ME.message);
        end
    end

    function trySetBlockParam(blockPath, paramName, paramValue)
        try
            set_param(blockPath, paramName, paramValue);
            report.updated{end+1} = sprintf('%s -> %s', blockPath, paramName);
        catch ME
            report.failed{end+1} = sprintf('%s (%s): %s', blockPath, paramName, ME.message);
        end
    end

    function trySetPID(blockPath, pidCfg)
        trySetBlockParam(blockPath, 'P', num2str(pidCfg.Kp, 16));
        trySetBlockParam(blockPath, 'I', num2str(pidCfg.Ki, 16));
        trySetBlockParam(blockPath, 'D', num2str(pidCfg.Kd, 16));
    end
end
