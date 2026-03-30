
classdef SimulinkBladeInterface < handle
    % Interface Simulink plus fonctionnelle pour le projet Design 2.
    % Version orientée "banc de test" :
    % - pilotage de la simulation
    % - réglages principaux
    % - panneau calibration
    % - scénarios d'essais
    % - indicateurs temps réel
    % - sauvegarde/chargement JSON
    % - export CSV
    %
    % Utilisation:
    %   app = SimulinkBladeInterface("Simulateur_V6_eq06");

    properties
        ModelName (1,1) string = "Simulateur_V6_eq06"
        Figure matlab.ui.Figure

        % Containers
        MainGrid matlab.ui.container.GridLayout
        LeftScroll matlab.ui.container.Panel
        CenterPanel matlab.ui.container.Panel
        RightScroll matlab.ui.container.Panel

        % Left side controls
        RunButton matlab.ui.control.Button
        StopButton matlab.ui.control.Button
        ApplyButton matlab.ui.control.Button
        SyncButton matlab.ui.control.Button

        StopTimeField matlab.ui.control.NumericEditField
        SolverDropDown matlab.ui.control.DropDown
        AsservissementSwitch matlab.ui.control.StateButton

        PositionEquilibriumField matlab.ui.control.NumericEditField
        CommandBiasField matlab.ui.control.NumericEditField
        SampleTimeField matlab.ui.control.NumericEditField

        ParamFields struct = struct()
        ParamPanel matlab.ui.container.Panel

        % Calibration and regulation
        CalibSlopeField matlab.ui.control.NumericEditField
        CalibOffsetField matlab.ui.control.NumericEditField
        CalibSignalDropDown matlab.ui.control.DropDown

        KpField matlab.ui.control.NumericEditField
        KiField matlab.ui.control.NumericEditField
        KdField matlab.ui.control.NumericEditField

        % Scenario buttons
        ScenarioDropDown matlab.ui.control.DropDown

        % Status/metrics
        MassField matlab.ui.control.NumericEditField
        CommandField matlab.ui.control.NumericEditField
        PositionField matlab.ui.control.NumericEditField
        CurrentField matlab.ui.control.NumericEditField
        StabilityLamp matlab.ui.control.Lamp
        ValidityLamp matlab.ui.control.Lamp
        StatusArea matlab.ui.control.TextArea
        PerfTable matlab.ui.control.Table

        % Plots
        Ax1 matlab.ui.control.UIAxes
        Ax2 matlab.ui.control.UIAxes
        Ax3 matlab.ui.control.UIAxes
        Ax4 matlab.ui.control.UIAxes

        % Signal browser
        SignalList matlab.ui.control.ListBox
        PlotButton matlab.ui.control.Button
        Tree matlab.ui.container.Tree

        % internal
        LastSimulationOutput = []
        LastScenarioName (1,1) string = "Manuel"
        LastSignalCache struct = struct()
        LastExportTable table = table()

        % maps
        ParameterMap cell = {
            'b',    'Amortissement b'
            'q',    'Distance du plateau q'
            'l',    'Largeur l'
            'L',    'Longueur L'
            'E',    'Module de Young E'
            'dens', 'Densité'
            'h',    'Épaisseur h'
        }

        OptionalControlVars cell = {
            'Kp',  'Gain proportionnel'
            'Ki',  'Gain intégral'
            'Kd',  'Gain dérivé'
            'equilibrium_position', 'Position d''équilibre'
            'command_bias', 'Biais commande'
            'Ts',  'Temps d''échantillonnage'
        }

        CandidateSignalNames cell = { ...
            'positionlame','simout','tout','logsout', ...
            'capteur_position','capteurPosition','position_capteur','Vposition', ...
            'capteur_courant','capteurCourant','currentSensor','Vcourant', ...
            'commande','actionneur','u','commande_actionneur','actionuator_cmd', ...
            'mesure_valide','mesureValide','valid_measure','valid', ...
            'masse','mass','mass_est','masse_estimee','massEstimate' ...
        }
    end

    methods
        function app = SimulinkBladeInterface(modelName)
            if nargin >= 1 && strlength(string(modelName)) > 0
                app.ModelName = string(modelName);
            end
            app.ensureModelLoaded();
            app.buildUI();
            app.populateSubsystemTree();
            app.refreshParameters();
            app.refreshSignalsList();
            app.logStatus("Interface prête.");
        end

        function ensureModelLoaded(app)
            if ~bdIsLoaded(app.ModelName)
                load_system(app.ModelName);
            end
        end

        function buildUI(app)
            app.Figure = uifigure( ...
                'Name', sprintf('Simulateur Design 2 - %s', app.ModelName), ...
                'Position', [40 40 1680 920], ...
                'Color', [0.98 0.98 0.98]);

            app.MainGrid = uigridlayout(app.Figure,[1 3]);
            app.MainGrid.ColumnWidth = {520,'1x',360};
            app.MainGrid.Padding = [10 10 10 10];
            app.MainGrid.ColumnSpacing = 10;

            %% LEFT
            app.LeftScroll = uipanel(app.MainGrid,'Title','Contrôle et réglages');
            app.LeftScroll.Layout.Column = 1;
            left = uigridlayout(app.LeftScroll,[11 1]);
            left.RowHeight = {42,58,105,185,140,165,135,42,'1x',38,38};
            left.Padding = [8 8 8 8];

            g1 = uigridlayout(left,[1 4]); g1.ColumnWidth = {'1x','1x','1x','1x'};
            app.RunButton  = uibutton(g1,'Text','Lancer','ButtonPushedFcn',@(~,~)app.runSimulation());
            app.StopButton = uibutton(g1,'Text','Stop','ButtonPushedFcn',@(~,~)app.stopSimulation());
            app.ApplyButton = uibutton(g1,'Text','Appliquer','ButtonPushedFcn',@(~,~)app.applyParameters());
            app.SyncButton  = uibutton(g1,'Text','Sync','ButtonPushedFcn',@(~,~)app.refreshParameters());

           g2 = uigridlayout(left,[2 4]);
            g2.ColumnWidth = {120,110,110,'1x'};
            g2.RowHeight = {26,26};
            g2.ColumnSpacing = 8;
            g2.RowSpacing = 6;
            g2.Padding = [4 4 4 4];
            uilabel(g2,'Text','StopTime');
            app.StopTimeField = uieditfield(g2,'numeric','Value',10);
            uilabel(g2,'Text','Solveur');
            app.SolverDropDown = uidropdown(g2,'Items',{'auto','ode45','ode23t','ode15s','FixedStepAuto'},'Value','auto');
            uilabel(g2,'Text','Asservissement');
            app.AsservissementSwitch = uibutton(g2,'state','Text','OFF','Value',false, ...
                'ValueChangedFcn',@(src,~)set(src,'Text', ternary(src.Value,'ON','OFF')));
            uilabel(g2,'Text','Scénario');
            app.ScenarioDropDown = uidropdown(g2,'Items',{'Manuel','Calibration','Échelon 50 g','Échelon 100 g gauche','Échelon 100 g droite','Tare','Échelon 1 mm','Robustesse'}, ...
                'Value','Manuel');

            g3 = uipanel(left,'Title','Réglages de conduite');
           gg3 = uigridlayout(g3,[3 4]);
            gg3.ColumnWidth = {110,110,110,'1x'};
            gg3.RowHeight = {28,28,28};
            gg3.ColumnSpacing = 8;
            gg3.RowSpacing = 6;
            gg3.Padding = [6 6 6 6];
            uilabel(gg3,'Text','Équilibre');
            app.PositionEquilibriumField = uieditfield(gg3,'numeric','Value',0);
            uilabel(gg3,'Text','Biais');
            app.CommandBiasField = uieditfield(gg3,'numeric','Value',0);
            uilabel(gg3,'Text','Ts');
            app.SampleTimeField = uieditfield(gg3,'numeric','Value',0.002);
            uilabel(gg3,'Text','Preset');
            uibutton(gg3,'Text','Charger','ButtonPushedFcn',@(~,~)app.applyScenarioPreset());

            app.ParamPanel = uipanel(left,'Title','Paramètres mécaniques');
            pg = uigridlayout(app.ParamPanel,[size(app.ParameterMap,1) 2]);
            pg.ColumnWidth = {180,120};
            pg.RowHeight = repmat({26},1,size(app.ParameterMap,1));
            pg.ColumnSpacing = 8;
            pg.RowSpacing = 6;
            pg.Padding = [6 6 6 6];
            for i = 1:size(app.ParameterMap,1)
                key = app.ParameterMap{i,1};
                label = app.ParameterMap{i,2};
                uilabel(pg,'Text',label);
                app.ParamFields.(matlab.lang.makeValidName(key)) = uieditfield(pg,'numeric','Value',0);
            end

            calPanel = uipanel(left,'Title','Calibration masse');
          cg = uigridlayout(calPanel,[4 4]);
            cg.ColumnWidth = {105,110,105,'1x'};
            cg.RowHeight = {28,28,28,32};
            cg.ColumnSpacing = 8;
            cg.RowSpacing = 6;
            cg.Padding = [6 6 6 6];
            uilabel(cg,'Text','Signal source');
            app.CalibSignalDropDown = uidropdown(cg,'Items',{'masse','positionlame','commande','capteur_position'},'Value','masse');
            uilabel(cg,'Text','Pente [g/V]');
            app.CalibSlopeField = uieditfield(cg,'numeric','Value',1);
            uilabel(cg,'Text','Offset [g]');
            app.CalibOffsetField = uieditfield(cg,'numeric','Value',0);
            uibutton(cg,'Text','Estimer depuis 2 pts','ButtonPushedFcn',@(~,~)app.estimateCalibrationFromDialog());
            uibutton(cg,'Text','Appliquer calibration','ButtonPushedFcn',@(~,~)app.recomputeDerivedSignals());

            regPanel = uipanel(left,'Title','Régulateur');
            rg = uigridlayout(regPanel,[2 4]);
            rg.ColumnWidth = {40,120,40,120};
            rg.RowHeight = {28,32};
            rg.ColumnSpacing = 8;
            rg.RowSpacing = 6;
            rg.Padding = [6 6 6 6];
            uilabel(rg,'Text','Kp'); app.KpField = uieditfield(rg,'numeric','Value',0);
            uilabel(rg,'Text','Ki'); app.KiField = uieditfield(rg,'numeric','Value',0);
            uilabel(rg,'Text','Kd'); app.KdField = uieditfield(rg,'numeric','Value',0);
            uibutton(rg,'Text','Appliquer PID','ButtonPushedFcn',@(~,~)app.applyControllerGains());
            uibutton(rg,'Text','Lire PID','ButtonPushedFcn',@(~,~)app.readControllerGains());

            statusPanel = uipanel(left,'Title','État');
            sg = uigridlayout(statusPanel,[3 4]);
            sg.ColumnWidth = {95,105,95,105};
            sg.RowHeight = {28,28,28};
            sg.ColumnSpacing = 8;
            sg.RowSpacing = 6;
            sg.Padding = [6 6 6 6];
            uilabel(sg,'Text','Masse [g]'); app.MassField = uieditfield(sg,'numeric','Editable','off','Value',0);
            uilabel(sg,'Text','Commande [V]'); app.CommandField = uieditfield(sg,'numeric','Editable','off','Value',0);
            uilabel(sg,'Text','Position'); app.PositionField = uieditfield(sg,'numeric','Editable','off','Value',0);
            uilabel(sg,'Text','Courant'); app.CurrentField = uieditfield(sg,'numeric','Editable','off','Value',0);
            uilabel(sg,'Text','Stable'); app.StabilityLamp = uilamp(sg,'Color',[1 0.4 0.2]);
            uilabel(sg,'Text','Mesure valide'); app.ValidityLamp = uilamp(sg,'Color',[1 0.4 0.2]);

            btnGrid = uigridlayout(left,[1 4]); btnGrid.ColumnWidth = {'1x','1x','1x','1x'};
            uibutton(btnGrid,'Text','Save JSON','ButtonPushedFcn',@(~,~)app.saveJson());
            uibutton(btnGrid,'Text','Load JSON','ButtonPushedFcn',@(~,~)app.loadJson());
            uibutton(btnGrid,'Text','Export CSV','ButtonPushedFcn',@(~,~)app.exportSignals());
            uibutton(btnGrid,'Text','Export rapport','ButtonPushedFcn',@(~,~)app.exportScenarioReport());

            app.StatusArea = uitextarea(left,'Editable','off','Value',{'Prêt.'});

            uibutton(left,'Text','Ouvrir le modèle','ButtonPushedFcn',@(~,~)open_system(app.ModelName));
            uibutton(left,'Text','Mettre à jour signaux','ButtonPushedFcn',@(~,~)app.refreshSignalsList());

            %% CENTER
            app.CenterPanel = uipanel(app.MainGrid,'Title','Oscilloscope / résultats');
            app.CenterPanel.Layout.Column = 2;
            center = uigridlayout(app.CenterPanel,[3 2]);
            center.RowHeight = {'1x','1x',160};
            center.ColumnWidth = {'1x','1x'};
            center.Padding = [8 8 8 8];

            app.Ax1 = uiaxes(center); app.Ax1.Layout.Row = 1; app.Ax1.Layout.Column = 1;
            title(app.Ax1,'Capteur de position'); xlabel(app.Ax1,'Temps [s]'); ylabel(app.Ax1,'V'); grid(app.Ax1,'on');

            app.Ax2 = uiaxes(center); app.Ax2.Layout.Row = 1; app.Ax2.Layout.Column = 2;
            title(app.Ax2,'Capteur de courant'); xlabel(app.Ax2,'Temps [s]'); ylabel(app.Ax2,'V'); grid(app.Ax2,'on');

            app.Ax3 = uiaxes(center); app.Ax3.Layout.Row = 2; app.Ax3.Layout.Column = 1;
            title(app.Ax3,'Commande actionneur'); xlabel(app.Ax3,'Temps [s]'); ylabel(app.Ax3,'V'); grid(app.Ax3,'on');

            app.Ax4 = uiaxes(center); app.Ax4.Layout.Row = 2; app.Ax4.Layout.Column = 2;
            title(app.Ax4,'Masse estimée / validité'); xlabel(app.Ax4,'Temps [s]'); ylabel(app.Ax4,'g'); grid(app.Ax4,'on');

            app.PerfTable = uitable(center);
            app.PerfTable.Layout.Row = 3;
            app.PerfTable.Layout.Column = [1 2];
            app.PerfTable.ColumnName = {'Indicateur','Valeur'};
            app.PerfTable.Data = {
                'Scénario','Manuel';
                'Temps de stabilisation [s]',NaN;
                'Erreur finale',NaN;
                'Écart-type fenêtre stable',NaN;
                'Mesure valide à t = [s]',NaN
            };

            %% RIGHT
            app.RightScroll = uipanel(app.MainGrid,'Title','Structure et accès aux signaux');
            app.RightScroll.Layout.Column = 3;
            right = uigridlayout(app.RightScroll,[5 1]);
            right.RowHeight = {'1x',130,34,34,'fit'};
            right.Padding = [8 8 8 8];

            app.Tree = uitree(right,'SelectionChangedFcn',@(~,evt)app.onTreeSelected(evt));
            app.SignalList = uilistbox(right,'Items',{'positionlame','simout'},'ValueChangedFcn',@(~,~)app.previewSignal());
            app.PlotButton = uibutton(right,'Text','Tracer signal sélectionné','ButtonPushedFcn',@(~,~)app.previewSignal());
            uibutton(right,'Text','Calculer performances','ButtonPushedFcn',@(~,~)app.computeAndDisplayPerformance());

            helpText = sprintf(['Fonctions utiles:\n' ...
                '- Interface graphique\n' ...
                '- Start / stop de la simulation\n' ...
                '- Position d''équilibre\n' ...
                '- Réglage PID\n' ...
                '- Voyants stabilité / validité\n' ...
                '- Affichage masse et commande\n' ...
                '- Export CSV et rapport de scénario\n' ...
                '- Calibration via pente / offset']);
            uitextarea(right,'Editable','off','Value',splitlines(helpText));
        end

        function refreshParameters(app)
            for i = 1:size(app.ParameterMap,1)
                key = app.ParameterMap{i,1};
                fn = matlab.lang.makeValidName(key);
                v = app.tryReadVariable(key);
                if isnumeric(v) && isscalar(v) && isfinite(v), app.ParamFields.(fn).Value = double(v); else, app.ParamFields.(fn).Value = 0; end
            end
            app.StopTimeField.Value = app.readStopTime();
            app.KpField.Value = app.safeScalar(app.tryReadVariable('Kp'), app.KpField.Value);
            app.KiField.Value = app.safeScalar(app.tryReadVariable('Ki'), app.KiField.Value);
            app.KdField.Value = app.safeScalar(app.tryReadVariable('Kd'), app.KdField.Value);
            app.PositionEquilibriumField.Value = app.safeScalar(app.tryReadVariable('equilibrium_position'), app.PositionEquilibriumField.Value);
            app.CommandBiasField.Value = app.safeScalar(app.tryReadVariable('command_bias'), app.CommandBiasField.Value);
            app.SampleTimeField.Value = app.safeScalar(app.tryReadVariable('Ts'), app.SampleTimeField.Value);
            app.logStatus('Paramètres relus depuis le modèle.');
        end

        function applyParameters(app)
            for i = 1:size(app.ParameterMap,1)
                key = app.ParameterMap{i,1};
                fn = matlab.lang.makeValidName(key);
                app.tryWriteVariable(key, app.ParamFields.(fn).Value);
            end
            app.tryWriteVariable('equilibrium_position', app.PositionEquilibriumField.Value);
            app.tryWriteVariable('command_bias', app.CommandBiasField.Value);
            app.tryWriteVariable('Ts', app.SampleTimeField.Value);

            set_param(app.ModelName,'StopTime',num2str(app.StopTimeField.Value));
            solver = string(app.SolverDropDown.Value);
            if solver ~= "auto"
                set_param(app.ModelName,'Solver',char(solver));
            end
            app.tryToggleAsservissement(app.AsservissementSwitch.Value);
            app.applyControllerGains(false);
            app.logStatus('Réglages appliqués.');
        end

        function runSimulation(app)
            app.applyScenarioPreset();
            app.applyParameters();
            app.logStatus("Simulation en cours...");
            drawnow;
            try
                simOut = sim(app.ModelName, 'ReturnWorkspaceOutputs', 'on');
                app.LastSimulationOutput = simOut;
                assignin('base','lastSimOut_Interface',simOut);
                app.harvestSignals(simOut);
                app.recomputeDerivedSignals();
                app.updateRealtimeIndicators();
                app.plotDashboardSignals();
                app.computeAndDisplayPerformance();
                app.refreshSignalsList();
                app.logStatus("Simulation terminée.");
            catch ME
                app.logStatus("Erreur simulation : " + string(ME.message));
                warning('%s',ME.getReport());
            end
        end

        function stopSimulation(app)
            try
                set_param(app.ModelName,'SimulationCommand','stop');
                app.logStatus('Arrêt demandé.');
            catch ME
                app.logStatus("Stop impossible : " + string(ME.message));
            end
        end

        function applyScenarioPreset(app)
            scenario = string(app.ScenarioDropDown.Value);
            app.LastScenarioName = scenario;
            switch scenario
                case "Calibration"
                    app.StopTimeField.Value = max(app.StopTimeField.Value, 8);
                case "Échelon 50 g"
                    app.StopTimeField.Value = max(app.StopTimeField.Value, 10);
                case {"Échelon 100 g gauche","Échelon 100 g droite"}
                    app.StopTimeField.Value = max(app.StopTimeField.Value, 12);
                case "Tare"
                    app.StopTimeField.Value = max(app.StopTimeField.Value, 8);
                case "Échelon 1 mm"
                    app.StopTimeField.Value = max(app.StopTimeField.Value, 8);
                case "Robustesse"
                    app.StopTimeField.Value = max(app.StopTimeField.Value, 15);
                otherwise
            end
            app.logStatus("Scénario sélectionné : " + scenario);
        end

        function applyControllerGains(app, logMsg)
            if nargin < 2, logMsg = true; end
            app.tryWriteVariable('Kp', app.KpField.Value);
            app.tryWriteVariable('Ki', app.KiField.Value);
            app.tryWriteVariable('Kd', app.KdField.Value);
            if logMsg
                app.logStatus(sprintf('PID appliqué. Kp=%.4g Ki=%.4g Kd=%.4g', app.KpField.Value, app.KiField.Value, app.KdField.Value));
            end
        end

        function readControllerGains(app)
            app.KpField.Value = app.safeScalar(app.tryReadVariable('Kp'), app.KpField.Value);
            app.KiField.Value = app.safeScalar(app.tryReadVariable('Ki'), app.KiField.Value);
            app.KdField.Value = app.safeScalar(app.tryReadVariable('Kd'), app.KdField.Value);
            app.logStatus('PID relu depuis le workspace.');
        end

        function estimateCalibrationFromDialog(app)
            prompt = {'Signal point 1 [V]','Masse point 1 [g]','Signal point 2 [V]','Masse point 2 [g]'};
            titleDlg = 'Calibration 2 points';
            dims = [1 45];
            definput = {'0','0','1','100'};
            answer = inputdlg(prompt,titleDlg,dims,definput);
            if isempty(answer), return; end
            x1 = str2double(answer{1}); y1 = str2double(answer{2});
            x2 = str2double(answer{3}); y2 = str2double(answer{4});
            if any(isnan([x1 y1 x2 y2])) || x1 == x2
                uialert(app.Figure,'Valeurs invalides pour la calibration.','Erreur');
                return;
            end
            m = (y2-y1)/(x2-x1);
            b = y1 - m*x1;
            app.CalibSlopeField.Value = m;
            app.CalibOffsetField.Value = b;
            app.recomputeDerivedSignals();
            app.logStatus(sprintf('Calibration mise à jour: masse = %.4g * signal + %.4g', m, b));
        end

        function recomputeDerivedSignals(app)
            cache = app.LastSignalCache;
            if isempty(fieldnames(cache))
                return;
            end

            source = matlab.lang.makeValidName(string(app.CalibSignalDropDown.Value));
            if isfield(cache, source)
                baseSig = cache.(source);
            elseif isfield(cache, 'positionlame')
                baseSig = cache.positionlame;
            else
                return;
            end

            if isfield(baseSig,'t') && isfield(baseSig,'y')
                massY = app.CalibSlopeField.Value .* baseSig.y + app.CalibOffsetField.Value;
                cache.masse_estimee = struct('t', baseSig.t(:), 'y', massY(:));
                cache.massEstimate = cache.masse_estimee;
            end

            if ~isfield(cache,'mesure_valide')
                if isfield(cache,'masse_estimee')
                    t = cache.masse_estimee.t;
                    y = cache.masse_estimee.y;
                    valid = zeros(size(y));
                    if numel(y) >= 20
                        win = max(10, round(0.5 / max(mean(diff(t)), eps)));
                        localStd = movstd(y, win, 'omitnan');
                        localSlope = [0; abs(diff(y))];
                        thresholdStd = max(0.5, 0.02 * max(abs(y)));
                        thresholdSlope = max(0.05, 0.01 * max(abs(y)));
                        valid(localStd < thresholdStd & localSlope < thresholdSlope) = 1;
                    end
                    cache.mesure_valide = struct('t', t(:), 'y', valid(:));
                end
            end

            app.LastSignalCache = cache;
        end

        function updateRealtimeIndicators(app)
            cache = app.LastSignalCache;
            app.PositionField.Value = app.lastValueFromCache(cache, {'capteur_position','capteurPosition','positionlame'});
            app.CurrentField.Value  = app.lastValueFromCache(cache, {'capteur_courant','capteurCourant','currentSensor'});
            app.CommandField.Value  = app.lastValueFromCache(cache, {'commande','actionneur','u','commande_actionneur'});
            app.MassField.Value     = app.lastValueFromCache(cache, {'masse_estimee','massEstimate','masse','mass'});

            valid = app.lastValueFromCache(cache, {'mesure_valide','mesureValide','valid_measure','valid'});
            if isnan(valid), valid = 0; end
            app.ValidityLamp.Color = ternary(valid > 0.5, [0.2 0.8 0.2], [1 0.4 0.2]);

            stable = 0;
            if isfield(cache,'masse_estimee')
                y = cache.masse_estimee.y(:);
                n = numel(y);
                if n >= 20
                    segment = y(max(1,n-min(100,n)+1):n);
                    stable = std(segment,'omitnan') < max(0.3,0.01*max(abs(y)));
                end
            end
            app.StabilityLamp.Color = ternary(stable, [0.2 0.8 0.2], [1 0.4 0.2]);
        end

        function plotDashboardSignals(app)
            cla(app.Ax1); cla(app.Ax2); cla(app.Ax3); cla(app.Ax4);
            app.plotFromCache(app.Ax1, {'capteur_position','capteurPosition','positionlame'}, 'Capteur de position');
            app.plotFromCache(app.Ax2, {'capteur_courant','capteurCourant','currentSensor'}, 'Capteur de courant');
            app.plotFromCache(app.Ax3, {'commande','actionneur','u','commande_actionneur'}, 'Commande actionneur');
            hold(app.Ax4,'off');
            plottedMass = app.plotFromCache(app.Ax4, {'masse_estimee','massEstimate','masse','mass'}, 'Masse estimée / validité');
            if isfield(app.LastSignalCache,'mesure_valide')
                hold(app.Ax4,'on');
                s = app.LastSignalCache.mesure_valide;
                yyaxis(app.Ax4,'right');
                plot(app.Ax4, s.t, s.y, 'LineStyle','--','LineWidth',1.1);
                ylabel(app.Ax4,'Valide');
                yyaxis(app.Ax4,'left');
                if ~plottedMass
                    title(app.Ax4,'Mesure valide');
                end
                hold(app.Ax4,'off');
            end
        end

        function ok = plotFromCache(app, ax, names, titleText)
            ok = false;
            for i = 1:numel(names)
                fn = matlab.lang.makeValidName(names{i});
                if isfield(app.LastSignalCache, fn)
                    s = app.LastSignalCache.(fn);
                    plot(ax, s.t, s.y, 'LineWidth', 1.3);
                    title(ax, titleText);
                    grid(ax,'on');
                    ok = true;
                    return;
                end
            end
            title(ax, [titleText ' indisponible']);
            grid(ax,'on');
        end

        function computeAndDisplayPerformance(app)
            scenario = app.LastScenarioName;
            cache = app.LastSignalCache;

            if isfield(cache,'masse_estimee')
                sig = cache.masse_estimee;
            else
                fn = app.firstExistingSignal({'masse','mass','positionlame'});
                if strlength(fn) == 0
                    return;
                end
                sig = cache.(fn);
            end

            t = sig.t(:);
            y = sig.y(:);
            n = numel(y);
            if n < 5, return; end

            target = app.getScenarioTarget(scenario);
            finalWindow = y(max(1, n-round(0.2*n)+1):n);
            finalMean = mean(finalWindow,'omitnan');
            finalStd = std(finalWindow,'omitnan');

            tol = max(0.5, 0.02 * max(1, abs(target)));
            idxStable = find(abs(y - finalMean) <= tol, 1, 'first');
            if isempty(idxStable), tStable = NaN; else, tStable = t(idxStable); end

            validTime = NaN;
            if isfield(cache,'mesure_valide')
                v = cache.mesure_valide.y(:);
                idv = find(v > 0.5, 1, 'first');
                if ~isempty(idv), validTime = cache.mesure_valide.t(idv); end
            end

            app.PerfTable.Data = {
                'Scénario', char(scenario);
                'Temps de stabilisation [s]', tStable;
                'Erreur finale', finalMean - target;
                'Écart-type fenêtre stable', finalStd;
                'Mesure valide à t = [s]', validTime
            };
        end

        function target = getScenarioTarget(~, scenario)
            switch string(scenario)
                case "Échelon 50 g", target = 50;
                case {"Échelon 100 g gauche","Échelon 100 g droite"}, target = 100;
                case "Tare", target = 0;
                case "Échelon 1 mm", target = 0;
                case "Robustesse", target = 75;
                otherwise, target = 0;
            end
        end

        function previewSignal(app)
            sig = string(app.SignalList.Value);
            if strlength(sig) == 0, return; end
            fn = matlab.lang.makeValidName(sig);
            if isfield(app.LastSignalCache, fn)
                s = app.LastSignalCache.(fn);
                figure('Name', char(sig)); plot(s.t,s.y,'LineWidth',1.2); grid on; title(char(sig));
                return;
            end
            try
                data = app.fetchSignal(sig);
                [t,y] = app.normalizeSignal(data);
                figure('Name', char(sig)); plot(t,y,'LineWidth',1.2); grid on; title(char(sig));
                app.logStatus("Signal affiché : " + sig);
            catch ME
                app.logStatus("Impossible de tracer " + sig + " : " + string(ME.message));
            end
        end

        function saveJson(app)
            S = struct();
            for i = 1:size(app.ParameterMap,1)
                key = app.ParameterMap{i,1};
                fn = matlab.lang.makeValidName(key);
                S.(key) = app.ParamFields.(fn).Value;
            end
            S.StopTime = app.StopTimeField.Value;
            S.Solver = app.SolverDropDown.Value;
            S.Asservissement = app.AsservissementSwitch.Value;
            S.equilibrium_position = app.PositionEquilibriumField.Value;
            S.command_bias = app.CommandBiasField.Value;
            S.Ts = app.SampleTimeField.Value;
            S.Kp = app.KpField.Value;
            S.Ki = app.KiField.Value;
            S.Kd = app.KdField.Value;
            S.calibration.signal = app.CalibSignalDropDown.Value;
            S.calibration.slope = app.CalibSlopeField.Value;
            S.calibration.offset = app.CalibOffsetField.Value;
            S.scenario = app.ScenarioDropDown.Value;
            [file,path] = uiputfile('*.json','Enregistrer la configuration','config_simulateur.json');
            if isequal(file,0), return; end
            fid = fopen(fullfile(path,file),'w');
            fwrite(fid, jsonencode(S, 'PrettyPrint', true), 'char');
            fclose(fid);
            app.logStatus("Configuration enregistrée.");
        end

        function loadJson(app)
            [file,path] = uigetfile('*.json','Charger une configuration');
            if isequal(file,0), return; end
            S = jsondecode(fileread(fullfile(path,file)));
            for i = 1:size(app.ParameterMap,1)
                key = app.ParameterMap{i,1};
                fn = matlab.lang.makeValidName(key);
                if isfield(S,key), app.ParamFields.(fn).Value = double(S.(key)); end
            end
            if isfield(S,'StopTime'), app.StopTimeField.Value = double(S.StopTime); end
            if isfield(S,'Solver'), app.SolverDropDown.Value = char(S.Solver); end
            if isfield(S,'Asservissement'), app.AsservissementSwitch.Value = logical(S.Asservissement); app.AsservissementSwitch.Text = ternary(app.AsservissementSwitch.Value,'ON','OFF'); end
            if isfield(S,'equilibrium_position'), app.PositionEquilibriumField.Value = double(S.equilibrium_position); end
            if isfield(S,'command_bias'), app.CommandBiasField.Value = double(S.command_bias); end
            if isfield(S,'Ts'), app.SampleTimeField.Value = double(S.Ts); end
            if isfield(S,'Kp'), app.KpField.Value = double(S.Kp); end
            if isfield(S,'Ki'), app.KiField.Value = double(S.Ki); end
            if isfield(S,'Kd'), app.KdField.Value = double(S.Kd); end
            if isfield(S,'calibration')
                if isfield(S.calibration,'signal'), app.CalibSignalDropDown.Value = char(S.calibration.signal); end
                if isfield(S.calibration,'slope'), app.CalibSlopeField.Value = double(S.calibration.slope); end
                if isfield(S.calibration,'offset'), app.CalibOffsetField.Value = double(S.calibration.offset); end
            end
            if isfield(S,'scenario'), app.ScenarioDropDown.Value = char(S.scenario); end
            app.applyParameters();
            app.logStatus("Configuration chargée.");
        end

        function exportSignals(app)
            if isempty(fieldnames(app.LastSignalCache))
                app.logStatus('Aucun signal disponible à exporter.');
                return;
            end
            [file,path] = uiputfile('*.csv','Exporter les signaux','resultats_signaux.csv');
            if isequal(file,0), return; end

            names = fieldnames(app.LastSignalCache);
            baseName = names{1};
            t = app.LastSignalCache.(baseName).t(:);
            T = table(t,'VariableNames',{'Time'});
            for i = 1:numel(names)
                s = app.LastSignalCache.(names{i});
                yi = interp1(s.t(:), s.y(:), t, 'linear', 'extrap');
                T.(matlab.lang.makeValidName(names{i})) = yi(:);
            end
            writetable(T, fullfile(path,file));
            app.LastExportTable = T;
            app.logStatus('CSV exporté.');
        end

        function exportScenarioReport(app)
            app.computeAndDisplayPerformance();
            [file,path] = uiputfile('*.txt','Exporter résumé du scénario','rapport_scenario.txt');
            if isequal(file,0), return; end
            fid = fopen(fullfile(path,file),'w');
            fprintf(fid,'Scenario: %s\n', app.LastScenarioName);
            data = app.PerfTable.Data;
            for i = 1:size(data,1)
                fprintf(fid,'%s: %s\n', string(data{i,1}), string(data{i,2}));
            end
            fprintf(fid,'Calibration signal: %s\n', app.CalibSignalDropDown.Value);
            fprintf(fid,'Calibration slope [g/V]: %.6g\n', app.CalibSlopeField.Value);
            fprintf(fid,'Calibration offset [g]: %.6g\n', app.CalibOffsetField.Value);
            fclose(fid);
            app.logStatus('Résumé scénario exporté.');
        end

        function harvestSignals(app, simOut)
            cache = struct();

            % From SimulationOutput
            try
                if isa(simOut,'Simulink.SimulationOutput')
                    vars = simOut.who;
                    for i = 1:numel(vars)
                        try
                            obj = simOut.get(vars{i});
                            [t,y] = app.normalizeSignal(obj);
                            cache.(matlab.lang.makeValidName(vars{i})) = struct('t',t(:),'y',y(:));
                        catch
                        end
                    end
                    try
                        if ~isempty(simOut.tout)
                            cache.tout = struct('t',simOut.tout(:),'y',simOut.tout(:));
                        end
                    catch
                    end
                end
            catch
            end

            % From base workspace known names
            for i = 1:numel(app.CandidateSignalNames)
                nm = app.CandidateSignalNames{i};
                try
                    obj = evalin('base', nm);
                    [t,y] = app.normalizeSignal(obj);
                    cache.(matlab.lang.makeValidName(nm)) = struct('t',t(:),'y',y(:));
                catch
                end
            end

            app.LastSignalCache = cache;
        end

        function refreshSignalsList(app)
            vars = {};
            try
                vars = evalin('base','who');
            catch
            end
            cacheNames = fieldnames(app.LastSignalCache);
            items = unique([app.CandidateSignalNames, reshape(vars,1,[]), reshape(cacheNames,1,[])], 'stable');
            if isempty(items), items = {'positionlame','simout'}; end
            app.SignalList.Items = items;
            if isempty(app.SignalList.Value) || ~ismember(app.SignalList.Value, items)
                app.SignalList.Value = items{1};
            end
        end

        function populateSubsystemTree(app)
            delete(app.Tree.Children);
            root = uitreenode(app.Tree,'Text',char(app.ModelName),'NodeData',char(app.ModelName));
            app.addChildrenRecursive(root,char(app.ModelName),0,3);
            expand(root);
        end

        function addChildrenRecursive(app,parentNode,systemPath,depth,maxDepth)
            if depth >= maxDepth, return; end
            try
                subs = find_system(systemPath,'SearchDepth',1,'BlockType','SubSystem');
                subs = subs(~strcmp(subs,systemPath));
                for i = 1:numel(subs)
                    node = uitreenode(parentNode,'Text',get_param(subs{i},'Name'),'NodeData',subs{i});
                    app.addChildrenRecursive(node,subs{i},depth+1,maxDepth);
                end
            catch
            end
        end

        function onTreeSelected(app,evt)
            node = evt.SelectedNodes;
            if isempty(node), return; end
            path = string(node.NodeData);
            app.logStatus("Bloc sélectionné : " + path);
        end

        function val = tryReadVariable(app,varName)
            ws = get_param(app.ModelName,'ModelWorkspace');
            try
                val = ws.evalin(varName); return;
            catch
            end
            try
                val = evalin('base',varName); return;
            catch
            end
            val = NaN;
        end

        function tryWriteVariable(app,varName,value)
            ws = get_param(app.ModelName,'ModelWorkspace');
            done = false;
            try
                ws.evalin(varName);
                ws.assignin(varName,value);
                done = true;
            catch
            end
            if ~done
                assignin('base',varName,value);
            end
        end

        function tryToggleAsservissement(app, state)
            candidates = {'asservissement_on','enable_control','enable_controller','closed_loop_enabled'};
            for i = 1:numel(candidates)
                try
                    app.tryWriteVariable(candidates{i}, double(state));
                    app.logStatus("Commande d'asservissement propagée via " + candidates{i});
                    return;
                catch
                end
            end
        end

        function data = fetchSignal(~, sigName)
            data = evalin('base', char(sigName));
        end

        function [t,y] = normalizeSignal(app,data)
            if isa(data,'timeseries')
                t = data.Time; y = squeeze(data.Data); return;
            end

            if isa(data,'Simulink.SimulationOutput')
                vars = data.who;
                for i = 1:numel(vars)
                    try
                        candidate = data.get(vars{i});
                        [t,y] = app.normalizeSignal(candidate);
                        return;
                    catch
                    end
                end
            end

            if isa(data,'Simulink.SimulationData.Dataset')
                for i = 1:data.numElements
                    try
                        el = data{i};
                        [t,y] = app.normalizeSignal(el.Values);
                        return;
                    catch
                    end
                end
            end

            if isa(data,'Simulink.SimulationData.Signal')
                [t,y] = app.normalizeSignal(data.Values); return;
            end

            if isstruct(data)
                if isfield(data,'time') && isfield(data,'signals')
                    t = data.time; y = squeeze(data.signals.values); return;
                end
                if isfield(data,'tout') && isfield(data,'yout')
                    t = data.tout; y = squeeze(data.yout); return;
                end
                if isfield(data,'t') && isfield(data,'y')
                    t = data.t; y = squeeze(data.y); return;
                end
            end

            if isnumeric(data)
                y = squeeze(data);
                if isvector(y)
                    y = y(:);
                    t = (0:numel(y)-1)' * 1;
                else
                    t = (0:size(y,1)-1)';
                    y = y(:,1);
                end
                return;
            end

            error('Format de signal non supporté.');
        end

        function v = safeScalar(~, maybe, fallback)
            if isnumeric(maybe) && isscalar(maybe) && ~isnan(maybe)
                v = double(maybe);
            else
                v = fallback;
            end
        end

        function x = lastValueFromCache(~, cache, names)
            x = NaN;
            for i = 1:numel(names)
                fn = matlab.lang.makeValidName(names{i});
                if isfield(cache, fn)
                    y = cache.(fn).y;
                    if ~isempty(y), x = double(y(end)); return; end
                end
            end
        end

        function fn = firstExistingSignal(app, names)
            fn = "";
            for i = 1:numel(names)
                cand = matlab.lang.makeValidName(names{i});
                if isfield(app.LastSignalCache, cand)
                    fn = cand; return;
                end
            end
        end

        function val = readStopTime(app)
            try
                val = str2double(get_param(app.ModelName,'StopTime'));
                if isnan(val), val = 10; end
            catch
                val = 10;
            end
        end

        function logStatus(app,msg)
            stamp = string(datetime('now','Format','HH:mm:ss'));
            lines = string(app.StatusArea.Value);
            lines(end+1) = "[" + stamp + "] " + string(msg);
            if numel(lines) > 18
                lines = lines(end-17:end);
            end
            app.StatusArea.Value = cellstr(lines);
            drawnow limitrate;
        end
    end
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
