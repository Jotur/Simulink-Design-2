function cfg = default_simulateur_config()
% Configuration par défaut du simulateur physique

cfg = struct();

% ======================
% LAME (physique)
% ======================
cfg.beam = struct( ...
    'L', 0.18, ...                 % m
    'b', 0.02, ...                 % m
    'h', 1.2e-3, ...               % m
    'E', 2.10e11, ...              % Pa
    'rho', 7850, ...               % kg/m^3
    'c', 0.08, ...                 % N.s/m
    'base', 0.0, ...               % m
    'plateauDistance', 0.12);      % m

% ======================
% MASSE
% ======================
cfg.mass = struct( ...
    'tipMass', 0.0, ...            % kg
    'startTime', 1.0);             % s

% ======================
% FORCE EXTERNE
% ======================
cfg.force = struct( ...
    'value', 0.0, ...              % N
    'enableCompensation', false);

% ======================
% COMMANDE
% ======================
cfg.control = struct( ...
    'positionSetpoint', 0.0, ...   % m
    'currentSetpoint', 0.0, ...    % A
    'positionPID', struct('Kp', 1.0, 'Ki', 0.0, 'Kd', 0.0), ...
    'currentPID', struct('Kp', 1.0, 'Ki', 0.0, 'Kd', 0.0));

% ======================
% ÉLECTRONIQUE (réaliste)
% ======================
cfg.elec = struct( ...
    'fs_adc', 500, ...             % Hz (échantillonnage)
    'fs_pwm', 15600, ...           % Hz (PWM réel)
    'adc_bits', 10, ...
    'dac_bits', 10, ...
    'antiAliasFc', 500, ...        % Hz
    'reconstructionFc', 50, ...    % Hz (filtre PWM)
    'vmax', 5, ...                 % V
    'imax', 2.35);                 % A

% ======================
% SIMULATION
% ======================
cfg.sim = struct( ...
    'stopTime', 3.0, ...
    'fixedStep', 1e-6);

% ======================
% CALIBRATION (CENTRAL)
% ======================
cfg.calibration = struct( ...
    'a', 0, ...                 % terme quadratique
    'b', 47.62, ...             % calibration initiale réaliste
    'c', -64.44, ...            % offset
    'isCalibrated', false, ...
    'massMin', 0, ...           % limites physiques
    'massMax', 200 ...          % g
);

% ======================
% UI
% ======================
cfg.ui = struct( ...
    'speed', 1.0);

end