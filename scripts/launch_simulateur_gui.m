function app = launch_simulateur_gui(modelName)
% launch_simulateur_gui
% Interface graphique MATLAB pour piloter le simulateur physique Simulink.
%
% Usage:
%   app = launch_simulateur_gui()
%   app = launch_simulateur_gui('Simulateur_VRemise_eq06')

    if nargin < 1 || strlength(string(modelName)) == 0
        modelName = "Simulateur_VRemise_eq06";
    end
    modelName = char(modelName);

    mdl = char(modelName);
    if ~bdIsLoaded(mdl)
        load_system(mdl);
    end

    cfg = default_simulateur_config();
    localPushConfigToBase(cfg);

    try
        update_simulateur_VRemise_eq06(mdl, cfg);
    catch ME
        warning('Mise à jour initiale incomplète: %s', ME.message);
    end

    app = struct();
    app.ModelName = mdl;
    app.Config = cfg;

    fig = uifigure( ...
        'Name', sprintf('Simulateur physique - %s', mdl), ...
        'Position', [80 60 1380 820], ...
        'Color', [0.98 0.98 0.98]);

    app.UIFigure = fig;

    gl = uigridlayout(fig, [1 2]);
    gl.ColumnWidth = {430, '1x'};
    gl.RowHeight = {'1x'};
    gl.Padding = [10 10 10 10];
    gl.ColumnSpacing = 10;

    leftPanel = uipanel(gl, 'Title', 'Pilotage et paramètres');
    rightPanel = uipanel(gl, 'Title', 'Visualisation');
    leftPanel.Layout.Row = 1; leftPanel.Layout.Column = 1;
    rightPanel.Layout.Row = 1; rightPanel.Layout.Column = 2;

    leftGrid = uigridlayout(leftPanel, [2 1]);
    leftGrid.RowHeight = {'1x', 220};
    leftGrid.Padding = [8 8 8 8];

    tabs = uitabgroup(leftGrid);
    tabs.Layout.Row = 1; tabs.Layout.Column = 1;

    tabParams = uitab(tabs, 'Title', 'Paramètres');
    tabControl = uitab(tabs, 'Title', 'Commande');
    tabTests = uitab(tabs, 'Title', 'Tests');
    tabInfo = uitab(tabs, 'Title', 'Infos');

    app = buildParametersTab(app, tabParams);
    app = buildControlTab(app, tabControl);
    app = buildTestsTab(app, tabTests);
    app = buildInfoTab(app, tabInfo);

    bottomPanel = uipanel(leftGrid, 'Title', 'Journal');
    bottomPanel.Layout.Row = 2; bottomPanel.Layout.Column = 1;
    app.LogArea = uitextarea(bottomPanel, ...
        'Position', [10 10 390 170], ...
        'Editable', 'off', ...
        'Value', {'Interface initialisée.'});

    rightGrid = uigridlayout(rightPanel, [2 2]);
    rightGrid.RowHeight = {'1x', '1x'};
    rightGrid.ColumnWidth = {'1x', '1x'};
    rightGrid.Padding = [8 8 8 8];

    app.AxPos = uiaxes(rightGrid);
    app.AxPos.Layout.Row = 1;
    app.AxPos.Layout.Column = 1;
    title(app.AxPos, 'Position de la lame');
    xlabel(app.AxPos, 'Temps [s]');
    ylabel(app.AxPos, 'Position [m]');
    grid(app.AxPos, 'on');


    app.AxMisc = uiaxes(rightGrid);
    app.AxMisc.Layout.Row = 2;
    app.AxMisc.Layout.Column = [1 2];
    title(app.AxMisc, 'Signal auxiliaire');
    xlabel(app.AxMisc, 'Temps [s]');
    ylabel(app.AxMisc, 'Amplitude');
    grid(app.AxMisc, 'on');

    fig.UserData = app;

    localLog(fig, sprintf('Modèle chargé: %s', mdl));
    localLog(fig, 'Interface prête.');

    if nargout == 0
        clear app
    end
end

function app = buildParametersTab(app, parent)
    mainGrid = uigridlayout(parent, [3 1]);
    mainGrid.RowHeight = {32, '1x', 42};
    mainGrid.ColumnWidth = {'1x'};
    mainGrid.Padding = [8 8 8 8];
    mainGrid.RowSpacing = 8;

    topGrid = uigridlayout(mainGrid, [1 2]);
    topGrid.Layout.Row = 1;
    topGrid.Layout.Column = 1;
    topGrid.ColumnWidth = {120, '1x'};
    topGrid.Padding = [0 0 0 0];
    topGrid.ColumnSpacing = 8;

    uilabel(topGrid, 'Text', 'Catégorie', 'HorizontalAlignment', 'left');

    dd = uidropdown(topGrid, ...
        'Items', {'Lame', 'Excitation / charges', 'Commande', 'Simulation / acquisition'}, ...
        'Value', 'Lame', ...
        'ValueChangedFcn', @(src,evt) onParameterCategoryChanged(app.UIFigure, src.Value));
    dd.Layout.Row = 1;
    dd.Layout.Column = 2;

    dynPanel = uipanel(mainGrid, 'Title', 'Paramètres');
    dynPanel.Layout.Row = 2;
    dynPanel.Layout.Column = 1;

    btnGrid = uigridlayout(mainGrid, [1 2]);
    btnGrid.Layout.Row = 3;
    btnGrid.Layout.Column = 1;
    btnGrid.ColumnWidth = {'1x', '1x'};
    btnGrid.RowHeight = {34};
    btnGrid.Padding = [0 0 0 0];
    btnGrid.ColumnSpacing = 10;

    btnApply = uibutton(btnGrid, 'Text', 'Appliquer au modèle', ...
        'ButtonPushedFcn', @(src,evt) onApply(app.UIFigure));
    btnApply.Layout.Row = 1;
    btnApply.Layout.Column = 1;

    btnReset = uibutton(btnGrid, 'Text', 'Remettre valeurs par défaut', ...
        'ButtonPushedFcn', @(src,evt) onReset(app.UIFigure));
    btnReset.Layout.Row = 1;
    btnReset.Layout.Column = 2;

    app.ParamCategoryDropdown = dd;
    app.ParamDynamicPanel = dynPanel;
    app.ParamControls = struct();
    app.BtnApply = btnApply;
    app.BtnReset = btnReset;

    app = buildParameterCategoryUI(app, 'Lame');
end

function app = buildControlTab(app, parent)
    g = uigridlayout(parent, [8 2]);
    g.RowHeight = {34,34,34,34,34,34,34,'1x'};
    g.ColumnWidth = {'1x','1x'};
    g.Padding = [10 10 10 10];

    btnOpen = uibutton(g, 'Text', 'Ouvrir le modèle', ...
        'ButtonPushedFcn', @(src,evt) open_system(app.ModelName));
    btnOpen.Layout.Row = 1; btnOpen.Layout.Column = [1 2];

    btnUpdate = uibutton(g, 'Text', 'Mettre à jour le modèle', ...
        'ButtonPushedFcn', @(src,evt) onApply(app.UIFigure));
    btnUpdate.Layout.Row = 2; btnUpdate.Layout.Column = [1 2];

    btnRun = uibutton(g, 'Text', 'Lancer simulation', ...
        'ButtonPushedFcn', @(src,evt) onRunSimulation(app.UIFigure));
    btnRun.Layout.Row = 3; btnRun.Layout.Column = [1 2];

    btnStop = uibutton(g, 'Text', 'Stop simulation', ...
        'ButtonPushedFcn', @(src,evt) onStopSimulation(app.UIFigure));
    btnStop.Layout.Row = 4; btnStop.Layout.Column = [1 2];

    btnRefresh = uibutton(g, 'Text', 'Rafraîchir les graphes', ...
        'ButtonPushedFcn', @(src,evt) refreshPlots(app.UIFigure));
    btnRefresh.Layout.Row = 5; btnRefresh.Layout.Column = [1 2];

    btnSave = uibutton(g, 'Text', 'Sauver config MAT', ...
        'ButtonPushedFcn', @(src,evt) onSaveConfig(app.UIFigure));
    btnSave.Layout.Row = 6; btnSave.Layout.Column = 1;

    btnLoad = uibutton(g, 'Text', 'Charger config MAT', ...
        'ButtonPushedFcn', @(src,evt) onLoadConfig(app.UIFigure));
    btnLoad.Layout.Row = 6; btnLoad.Layout.Column = 2;

    btnExport = uibutton(g, 'Text', 'Exporter paramètres pour système', ...
        'ButtonPushedFcn', @(src,evt) onExportSystemParams(app.UIFigure));
    btnExport.Layout.Row = 7; btnExport.Layout.Column = [1 2];
end

function app = buildTestsTab(app, parent)
    g = uigridlayout(parent, [10 1]);
    g.RowHeight = {34,34,34,34,34,34,34,34,34,'1x'};
    g.Padding = [10 10 10 10];

    specs = {
        'Tout lancer', 'all'
        'Lame seule', 'beam_only'
        'Résonance vs analytique', 'resonance'
        'Déflexion statique vs analytique', 'static_deflection'
        'Lâcher à vide', 'drop_release'
        '100 g déposé', 'mass_100g'
        '1000 N force externe', 'force_1000N'
        '100 g + compensation', 'mass_100g_comp'
        'Calibration', 'calibration'
    };

    for k = 1:size(specs,1)
        b = uibutton(g, 'Text', specs{k,1}, ...
            'ButtonPushedFcn', @(src,evt) onRunTests(app.UIFigure, specs{k,2}));
        b.Layout.Row = k;
    end
end

function app = buildInfoTab(app, parent)
    txt = {
        'Ce panneau centralise les paramètres, les tests et les sorties.'
        ''
        'Les graphes lisent maintenant les signaux depuis le workspace'
        'ou depuis simOut_latest si nécessaire.'
        ''
        'Si certains chemins de blocs ont changé dans le .slx,'
        'mets à jour la fonction update_simulateur_VRemise_eq06.m.'
    };
    uitextarea(parent, 'Position', [10 10 380 520], 'Editable', 'off', 'Value', txt);
end

function [field, rowOut] = addNumericField(grid, rowIn, label, value)
    lbl = uilabel(grid, 'Text', label, 'HorizontalAlignment', 'left');
    lbl.Layout.Row = rowIn;
    lbl.Layout.Column = 1;

    field = uieditfield(grid, 'numeric', 'Value', value);
    field.Layout.Row = rowIn;
    field.Layout.Column = 2;

    rowOut = rowIn + 1;
end

function onApply(fig)
    app = localGetAppState(fig);
    cfg = app.Config;
    c = app.ParamControls;

    if isfield(c,'Length') && isvalid(c.Length), cfg.beam.L = c.Length.Value; end
    if isfield(c,'Width') && isvalid(c.Width), cfg.beam.b = c.Width.Value; end
    if isfield(c,'Thickness') && isvalid(c.Thickness), cfg.beam.h = c.Thickness.Value; end
    if isfield(c,'E') && isvalid(c.E), cfg.beam.E = c.E.Value; end
    if isfield(c,'Rho') && isvalid(c.Rho), cfg.beam.rho = c.Rho.Value; end
    if isfield(c,'Damping') && isvalid(c.Damping), cfg.beam.c = c.Damping.Value; end
    if isfield(c,'BaseHeight') && isvalid(c.BaseHeight), cfg.beam.base = c.BaseHeight.Value; end
    if isfield(c,'PlateauDistance') && isvalid(c.PlateauDistance), cfg.beam.plateauDistance = c.PlateauDistance.Value; end

    if isfield(c,'TipMass') && isvalid(c.TipMass), cfg.mass.tipMass = c.TipMass.Value; end
    if isfield(c,'MassStartTime') && isvalid(c.MassStartTime), cfg.mass.startTime = c.MassStartTime.Value; end
    if isfield(c,'ExternalForce') && isvalid(c.ExternalForce), cfg.force.value = c.ExternalForce.Value; end

    if isfield(c,'PositionSetpoint') && isvalid(c.PositionSetpoint), cfg.control.positionSetpoint = c.PositionSetpoint.Value; end
    if isfield(c,'CurrentSetpoint') && isvalid(c.CurrentSetpoint), cfg.control.currentSetpoint = c.CurrentSetpoint.Value; end

    if isfield(c,'SimStopTime') && isvalid(c.SimStopTime), cfg.sim.stopTime = c.SimStopTime.Value; end
    if isfield(c,'SimStep') && isvalid(c.SimStep), cfg.sim.fixedStep = c.SimStep.Value; end
    if isfield(c,'FsADC') && isvalid(c.FsADC), cfg.elec.fs_adc = c.FsADC.Value; end
    if isfield(c,'FsPWM') && isvalid(c.FsPWM), cfg.elec.fs_pwm = c.FsPWM.Value; end
    if isfield(c,'ADCBits') && isvalid(c.ADCBits), cfg.elec.adc_bits = round(c.ADCBits.Value); end

    app.Config = cfg;
    localSetAppState(fig, app);
    localPushConfigToBase(cfg);

    try
        update_simulateur_VRemise_eq06(app.ModelName, cfg);
        localLog(fig, 'Paramètres appliqués au modèle.');
    catch ME
        localLog(fig, ['Échec partiel de mise à jour: ' ME.message]);
        uialert(fig, ME.message, 'Mise à jour incomplète');
    end
end

function onReset(fig)
    app = localGetAppState(fig);
    app.Config = default_simulateur_config();
    localSetAppState(fig, app);

    currentCategory = app.ParamCategoryDropdown.Value;
    app = buildParameterCategoryUI(app, currentCategory);
    localPushConfigToBase(app.Config);
    localLog(fig, 'Valeurs par défaut rechargées.');
end

function onRunSimulation(fig)
    onApply(fig);
    app = localGetAppState(fig);

    mdl = app.ModelName;
    try
        localConfigureLogging(mdl);
        localLog(fig, 'Simulation lancée...');
        simOut = sim(mdl, ...
            'StopTime', num2str(app.Config.sim.stopTime), ...
            'ReturnWorkspaceOutputs', 'on');
        assignin('base', 'simOut_latest', simOut);
        localLog(fig, 'Simulation terminée.');
        refreshPlots(fig);
    catch ME
        localLog(fig, ['Erreur simulation: ' ME.message]);
        uialert(fig, ME.message, 'Erreur simulation');
    end
end

function onStopSimulation(fig)
    app = localGetAppState(fig);
    try
        set_param(app.ModelName, 'SimulationCommand', 'stop');
        localLog(fig, 'Commande stop envoyée.');
    catch ME
        localLog(fig, ['Impossible d''arrêter la simulation: ' ME.message]);
    end
end

function refreshPlots(fig)
    app = localGetAppState(fig);

    try
        [tPos, yPos] = localFetchSeries('positionlame');
        cla(app.AxPos);
        plot(app.AxPos, tPos, yPos, 'LineWidth', 1.5);
        grid(app.AxPos, 'on');
    catch ME
        localLog(fig, ['Position indisponible: ' ME.message]);
    end

    try
        [tVel, yVel] = localFetchSeries('vitesselame');
        cla(app.AxVel);
        plot(app.AxVel, tVel, yVel, 'LineWidth', 1.5);
        grid(app.AxVel, 'on');
    catch ME
        localLog(fig, ['Vitesse indisponible: ' ME.message]);
    end

    miscVars = {'courant_bobine', 'force_actionneur', 'commande_position', 'commande_courant'};
    cla(app.AxMisc);
    ok = false;
    legendEntries = {};

    for i = 1:numel(miscVars)
        try
            [t, y] = localFetchSeries(miscVars{i});
            plot(app.AxMisc, t, y, 'LineWidth', 1.2);
            hold(app.AxMisc, 'on');
            ok = true;
            legendEntries{end+1} = miscVars{i}; %#ok<AGROW>
        catch
        end
    end

    if ok
        legend(app.AxMisc, legendEntries, 'Interpreter', 'none', 'Location', 'best');
        hold(app.AxMisc, 'off');
    else
        text(app.AxMisc, 0.2, 0.5, 'Aucun signal auxiliaire exporté.', 'Units', 'normalized');
    end
    grid(app.AxMisc, 'on');
    localLog(fig, 'Graphes rafraîchis.');
end

function onRunTests(fig, whichTest)
    onApply(fig);
    app = localGetAppState(fig);
    try
        localLog(fig, ['Tests demandés: ' char(whichTest)]);
        results = run_required_tests_simulateur(app.ModelName, whichTest, app.Config);
        assignin('base', 'test_results_latest', results);
        localLog(fig, 'Tests terminés. Résultats exportés dans test_results_latest.');
    catch ME
        localLog(fig, ['Erreur tests: ' ME.message]);
        uialert(fig, ME.message, 'Erreur de tests');
    end
end

function onSaveConfig(fig)
    app = localGetAppState(fig);
    [file, path] = uiputfile('*.mat', 'Sauver la configuration', 'sim_config.mat');
    if isequal(file,0)
        return
    end
    cfg = app.Config; %#ok<NASGU>
    save(fullfile(path,file), 'cfg');
    localLog(fig, ['Configuration sauvegardée: ' fullfile(path,file)]);
end

function onLoadConfig(fig)
    app = localGetAppState(fig);
    [file, path] = uigetfile('*.mat', 'Charger une configuration');
    if isequal(file,0)
        return
    end

    S = load(fullfile(path,file), 'cfg');
    if ~isfield(S, 'cfg')
        uialert(fig, 'Le fichier MAT ne contient pas de variable cfg.', 'Chargement impossible');
        return
    end

    app.Config = S.cfg;
    localSetAppState(fig, app);
    currentCategory = app.ParamCategoryDropdown.Value;
    app = buildParameterCategoryUI(app, currentCategory);
    localPushConfigToBase(app.Config);
    localLog(fig, ['Configuration chargée: ' fullfile(path,file)]);
end

function onExportSystemParams(fig)
    app = localGetAppState(fig);
    cfg = app.Config;
    export = build_system_export_struct(cfg); %#ok<NASGU>
    assignin('base', 'simulateur_system_export', export);

    [file, path] = uiputfile('*.mat', 'Exporter les paramètres système', 'simulateur_system_export.mat');
    if ~isequal(file,0)
        save(fullfile(path,file), 'export');
        localLog(fig, ['Paramètres système exportés: ' fullfile(path,file)]);
    else
        localLog(fig, 'Paramètres système générés dans le workspace: simulateur_system_export');
    end
end

function localPushConfigToBase(cfg)
    assignin('base', 'SIM_CFG', cfg);
    assignin('base', 'L_beam', cfg.beam.L);
    assignin('base', 'b_beam', cfg.beam.b);
    assignin('base', 'h_beam', cfg.beam.h);
    assignin('base', 'E_beam', cfg.beam.E);
    assignin('base', 'rho_beam', cfg.beam.rho);
    assignin('base', 'c_beam', cfg.beam.c);
    assignin('base', 'm_tip', cfg.mass.tipMass);
    assignin('base', 'F_ext', cfg.force.value);
    assignin('base', 'x_ref', cfg.control.positionSetpoint);
    assignin('base', 'i_ref', cfg.control.currentSetpoint);
end

function localLog(fig, msg)
    app = localGetAppState(fig);
    stamp = datestr(now, 'HH:MM:SS');
    app.LogArea.Value = [app.LogArea.Value; {sprintf('[%s] %s', stamp, msg)}];
    drawnow limitrate
end

function localConfigureLogging(mdl)
    try
        set_param([mdl '/Lame/To Workspace1'], 'VariableName', 'position_lame');
        set_param([mdl '/Lame/To Workspace1'], 'SaveFormat', 'Structure With Time');
    catch
    end
    try
        set_param([mdl '/Lame/To Workspace2'], 'VariableName', 'vitesse_lame');
        set_param([mdl '/Lame/To Workspace2'], 'SaveFormat', 'Structure With Time');
    catch
    end
end

function [t, y] = localFetchSeries(varName)
    data = [];

    if evalin('base', sprintf('exist(''%s'',''var'')', varName)) ~= 0
        data = evalin('base', varName);
    elseif evalin('base', 'exist(''simOut_latest'',''var'')') ~= 0
        simOut = evalin('base', 'simOut_latest');
        try
            data = simOut.get(varName);
        catch
            error('Variable %s absente du workspace et de simOut_latest.', varName);
        end
    else
        error('Variable %s absente du workspace.', varName);
    end

    if isa(data, 'timeseries')
        t = data.Time;
        y = data.Data;
    elseif isstruct(data) && isfield(data, 'time') && isfield(data, 'signals')
        t = data.time;
        y = data.signals.values;
    elseif isstruct(data) && isfield(data, 'Time') && isfield(data, 'Data')
        t = data.Time;
        y = data.Data;
    else
        error('Format non géré pour %s.', varName);
    end

    y = squeeze(y);
end

function app = localGetAppState(fig)
    data = fig.UserData;

    if isempty(data)
        error('fig.UserData est vide.');
    end

    if isstruct(data) && isfield(data, 'Config')
        app = data;
        return
    end

    error('fig.UserData n''a pas le format attendu.');
end

function localSetAppState(fig, app)
    if ~isstruct(app) || ~isfield(app, 'Config')
        error('Tentative d''écriture d''un état applicatif invalide.');
    end
    fig.UserData = app;
end

function app = buildParameterCategoryUI(app, category)
    parent = app.ParamDynamicPanel;

    delete(parent.Children);

    controls = struct();
    cfg = app.Config;

    switch category
        case 'Lame'
            g = uigridlayout(parent, [8 2]);
            g.RowHeight = repmat({30}, 1, 8);
            g.ColumnWidth = {185, '1x'};
            g.Padding = [10 10 10 10];
            g.RowSpacing = 8;
            g.ColumnSpacing = 10;

            [controls.Length, ~]          = addNumericField(g, 1, 'Longueur lame L [m]',      cfg.beam.L);
            [controls.Width, ~]           = addNumericField(g, 2, 'Largeur lame b [m]',       cfg.beam.b);
            [controls.Thickness, ~]       = addNumericField(g, 3, 'Épaisseur lame h [m]',     cfg.beam.h);
            [controls.E, ~]               = addNumericField(g, 4, 'Young E [Pa]',             cfg.beam.E);
            [controls.Rho, ~]             = addNumericField(g, 5, 'Densité rho [kg/m^3]',     cfg.beam.rho);
            [controls.Damping, ~]         = addNumericField(g, 6, 'Amortissement c [N.s/m]',  cfg.beam.c);
            [controls.BaseHeight, ~]      = addNumericField(g, 7, 'Base / offset [m]',        cfg.beam.base);
            [controls.PlateauDistance, ~] = addNumericField(g, 8, 'Distance plateau [m]',     cfg.beam.plateauDistance);

        case 'Excitation / charges'
            g = uigridlayout(parent, [3 2]);
            g.RowHeight = repmat({30}, 1, 3);
            g.ColumnWidth = {185, '1x'};
            g.Padding = [10 10 10 10];
            g.RowSpacing = 8;
            g.ColumnSpacing = 10;

            [controls.TipMass, ~]       = addNumericField(g, 1, 'Masse ponctuelle [kg]', cfg.mass.tipMass);
            [controls.MassStartTime, ~] = addNumericField(g, 2, 'Temps dépôt masse [s]', cfg.mass.startTime);
            [controls.ExternalForce, ~] = addNumericField(g, 3, 'Force externe [N]',     cfg.force.value);

        case 'Commande'
            g = uigridlayout(parent, [2 2]);
            g.RowHeight = repmat({30}, 1, 2);
            g.ColumnWidth = {185, '1x'};
            g.Padding = [10 10 10 10];
            g.RowSpacing = 8;
            g.ColumnSpacing = 10;

            [controls.PositionSetpoint, ~] = addNumericField(g, 1, 'Consigne position [m]', cfg.control.positionSetpoint);
            [controls.CurrentSetpoint, ~]  = addNumericField(g, 2, 'Consigne courant [A]',  cfg.control.currentSetpoint);

        case 'Simulation / acquisition'
            g = uigridlayout(parent, [5 2]);
            g.RowHeight = repmat({30}, 1, 5);
            g.ColumnWidth = {185, '1x'};
            g.Padding = [10 10 10 10];
            g.RowSpacing = 8;
            g.ColumnSpacing = 10;

            [controls.SimStopTime, ~] = addNumericField(g, 1, 'Durée simulation [s]', cfg.sim.stopTime);
            [controls.SimStep, ~]     = addNumericField(g, 2, 'Pas simulation [s]',   cfg.sim.fixedStep);
            [controls.FsADC, ~]       = addNumericField(g, 3, 'Fs ADC [Hz]',          cfg.elec.fs_adc);
            [controls.FsPWM, ~]       = addNumericField(g, 4, 'Fs PWM [Hz]',          cfg.elec.fs_pwm);
            [controls.ADCBits, ~]     = addNumericField(g, 5, 'Bits ADC',             cfg.elec.adc_bits);
    end

    app.ParamControls = controls;
    localSetAppState(app.UIFigure, app);
end

function onParameterCategoryChanged(fig, category)
    onApply(fig);
    app = localGetAppState(fig);
    app = buildParameterCategoryUI(app, category);
    localLog(fig, ['Catégorie affichée: ' category]);
end
