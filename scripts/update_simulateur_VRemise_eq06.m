function report = update_simulateur_VRemise_eq06(modelName, cfg)

    if nargin < 1 || strlength(string(modelName)) == 0
        modelName = "Simulateur_VRemise_eq06";
    end
    if nargin < 2 || isempty(cfg)
        cfg = default_simulateur_config();
    end

    modelName = char(modelName);

    if ~bdIsLoaded(modelName)
        load_system(modelName);
    end

    assignin('base','SIM_CFG',cfg);

    export = build_system_export_struct(cfg);
    f = fieldnames(export.workspace);
    for i = 1:numel(f)
        assignin('base',f{i},export.workspace.(f{i}));
    end

    report = struct();
    report.updated = {};
    report.failed = {};

    % ======================
    % SIMULATION
    % ======================
    trySetModelParam('StopTime', num2str(cfg.sim.stopTime,16));
    trySetModelParam('FixedStep', num2str(cfg.sim.fixedStep,16));
    trySetModelParam('SolverType','Fixed-step');

    % ======================
    % LAME
    % ======================
    tryBlockValue([modelName '/Lame/Longueur'], cfg.beam.L);
    tryBlockValue([modelName '/Lame/Hauteur'], cfg.beam.h);
    tryBlockValue([modelName '/Lame/Base'], cfg.beam.base);
    tryBlockValue([modelName '/Lame/Distance du plateau'], cfg.beam.plateauDistance);
    tryBlockValue([modelName '/Lame/Module de young'], cfg.beam.E);
    tryBlockValue([modelName '/Lame/densité'], cfg.beam.rho);
    tryBlockValue([modelName '/Lame/Amortissement'], cfg.beam.c);
    tryBlockValue([modelName '/Lame/Masse entrante'], cfg.mass.tipMass);

    % ======================
    % TO WORKSPACE (FIXÉ)
    % ======================
    trySetBlockParam([modelName '/Lame/To Workspace1'], ...
        'VariableName','Position_lame');

    trySetBlockParam([modelName '/Lame/To Workspace2'], ...
        'VariableName','Vitesse_actionneur');

    trySetBlockParam([modelName '/Actionneur/To Workspace'], ...
        'VariableName','courant_actionneur');

    % ======================
    % PID
    % ======================
    trySetPID([modelName '/ARDUINO/Régulateur De Position/Discrete PID Controller'], ...
        cfg.control.positionPID);

    trySetPID([modelName '/ARDUINO/Régulateur De Courant/Discrete PID Controller'], ...
        cfg.control.currentPID);

    % ======================
    % SAVE
    % ======================
    try
        save_system(modelName);
    catch
    end

    function trySetModelParam(p,v)
        try, set_param(modelName,p,v); end
    end

    function tryBlockValue(b,v)
        try, set_param(b,'Value',num2str(v,16)); end
    end

    function trySetBlockParam(b,p,v)
        try, set_param(b,p,v); end
    end

    function trySetPID(b,pid)
        trySetBlockParam(b,'P',num2str(pid.Kp,16));
        trySetBlockParam(b,'I',num2str(pid.Ki,16));
        trySetBlockParam(b,'D',num2str(pid.Kd,16));
    end

end