%% Init_Simulateur_V10_eq06.m
% Initialisation centralisee des variables du modele Simulink
% Modele vise : Simulateur_V10_eq06
% -------------------------------------------------------------------------
% Utilisation recommandee dans Simulink (Model Properties > Callbacks > InitFcn):
%   run('Init_Simulateur_V10_eq06.m');
% -------------------------------------------------------------------------
% Objectif :
%   - Aucune valeur numerique directement dans les blocs Simulink
%   - Toutes les constantes du modele sont definies ici
%   - Le script peut etre rappelle automatiquement via le callback InitFcn

clearvars -except ans;
clc;

%% ========================================================================
% 1) PARAMETRES GENERAUX DE SIMULATION
% ========================================================================
Ts = 1e-3;                 % |ou 2e-3 max| Pas de calcul/sampling principal [s]
Ts_reg = 2e-3;      % 500 Hz
Tstop = inf;               % Mode fonctionnement permanent
SolverType = 'Fixed-step'; % A configurer dans les Model Settings
SolverName = 'ode4';       % Runge-Kutta ordre 4

% Frequences utiles
fs = 1/Ts;                 % [Hz]

%% ========================================================================
% 2) LAME / MASSE / GRANDEURS MECANIQUES
% ========================================================================


Masse = 0; % Masse appliquee au plateau entre 0 et 100

% Conversion SI [kg]
Gain = 1/1000;  % Conversion de la Masse SI [kg]

% Gravite [m/s^2]
g = 9.81;      

% Force equivalente [N]
F_gravite = Masse*g; 

% Longueur de la lame [m]
L = 25e-2;

% Largeur de la lame [m]
b = 72.82e-3;

% Epaisseur (hauteur) de la lame [m]
h = 1.46e-3;

% Distance entre l'encastrement et le plateau [m]
q = 0.14;

% Masse totale lame + plateau + bobine [kg]
M_l_p_b = 0.137;

% Module de Young du materiau [Pa]
E = 18.6e9;

% Coefficient d'amortissement [-]
zeta = 0.0917;

% Densite du materiau [kg/m^3]
d = 1850;

% Nombre d'elements de discretisation spatiale [-]
N = 22;

% Pas de temps du modele de la lame [s]
dt = 5e-6;


%% ========================================================================
% 3) CAPTEUR DE POSITION
% ========================================================================
% Equation lineaire : Vpos = Kpos*x + Offp = 205*x + 2.3025
Kpos = 205;
Offp = 2.3025;

%% ========================================================================
% 4) CONDITIONNEMENT DE POSITION
% ========================================================================
% Loi quadratique : y = a*x^2 + b*x + c
Cpa = -0.0235339;
Cpb = 2.2110269;
Cpc = -3.1661245;

% Saturation du conditionnement de position
Cpmin = 0;
Cpmax = 5;

%% ========================================================================
% 5) CAPTEUR DE COURANT
% ========================================================================
% Gain Variable de la resistance shunt de 1.
Ksh = 1;

%% ========================================================================
% 6) CONDITIONNEMENT DE COURANT
% ========================================================================
Ccoff = 2.5;
Ccmin = 0;
Ccmax = 5;

%% ========================================================================
% 7) REGULATEUR DE POSITION
% ========================================================================
Ts_p = Ts_reg; % PID
Vref = 1.8;    % consigne pos

% Gains du PID(z) de position
% Remplacer par vos vraies valeurs.
Kp_pos = 0.85;
Ki_pos = 2.8333;
Kd_pos = 0.017;
N_pos  = 100;     % A checker

% Saturation de sortie du regulateur de position (courant de reference)
Irmin = -2.9; % sat min Iref
Irmax =  2.9; % sat max Iref


%% ========================================================================
% 8) REGULATEUR DE COURANT
% ========================================================================
Ts_i = Ts_reg;
Imoff = 2.5; % offset mesure
Km = 1/1.1;    % Gain applique apres sommation d'offset sur la capture

% Gains du PI(z) de courant
% Remplacer par vos vraies valeurs.
Kp_i = 0.18;
Ki_i = 180;

% Gain additionnel "Gain ampli" visible sur la capture
Kamp = 1/0.95;

Vmoff = 2.5; % offset mesure

% Saturation de sortie du regulateur de courant
Vamp_min = 0;
Vamp_max = 5;

%% ========================================================================
% 9) PWM / ARDUINO / AMPLIFICATEUR
% ========================================================================
% Normalisation de la commande analogique avant comparaison PWM
K_pwm = 1/5;

% Dent de scie / porteuse PWM
fpwm = 500;               % [Hz] a ajuster selon votre implantation
Tpwm = 1/fpwm;       % [s]
Apwm = 1;                   % Amplitude PWM
Opwm = 0;               % Offset PWM
Kpwmo = 5; % Gain sortie PWM

% Fonction de transfert
numP = [1]; % num TF PWM
denP = [3.1861e-12 3.9953e-7 1.4575e-3 1]; % den TF PWM

% Etage aval montre sur la capture
Opwmd = 2.5; % offset etage PWM
Kpwme = 0.8; % gain etage PWM
KampL = 1;   % gain ampli final


Vamin = 0; % sat min Vactionneur
Vamax = 5; % sat max Vactionneur

%% ========================================================================
% 10) ACTIONNEUR ELECTROMAGNETIQUE (POLYFIT)
% ========================================================================
Rb = 1.63;              % Resistance bobine [ohm]
Kf = 0.5;    % Gain 0.5 

i0 = 0;            % Condition initiale du courant integre
F0 = 0;  % Condition initiale force [N]

% Polynome L(x) = aL2*x^2 + aL1*x + aL0
aL2 = -4.55e-6;
aL1 = -9.95e-6;
aL0 =  1.1256e-3;

% Polynome dL/dx(x) = adL1*x + adL0
adL1 = -9.10e-3;
adL0 = -9.95e-3;

% Polynome dPhi/dx(x) = aPhi1*x + aPhi0
aPhi1 =  5.96e-5;
aPhi0 = -1.41e-2;

% Polynome Kb(x) = aKb1*x + aKb0
aKb1 =  5.96e-5;
aKb0 = -1.41e-2;


%% ========================================================================
% 11) VALEURS PAR DEFAUT POUR SCOPES / TESTS
% ========================================================================
Position_lame_init = 0;
Position_actionneur_init = 0;
Vitesse_actionneur_init = 0;
Tension_actionneur_init = 0;
Courant_actionneur_init = 0;

%% ========================================================================
% 12) RESUME DES REMPLACEMENTS A FAIRE DANS SIMULINK
% ========================================================================
% Remplacer dans chaque bloc les valeurs numeriques par les variables suivantes:
%
% CAPTEUR DE POSITION
%   205               -> K_capteur_position
%   2.3025            -> Offset_capteur_position
%
% CONDITIONNEMENT DE POSITION
%   2.2110269         -> CondPos_b
%  -0.0235339         -> CondPos_a
%  -3.1661245         -> CondPos_c
%   saturation min    -> CondPos_sat_min
%   saturation max    -> CondPos_sat_max
%
% CAPTEUR DE COURANT
%   1                 -> K_shunt_courant
%
% CONDITIONNEMENT DE COURANT
%   2.5               -> Offset_courant_cond
%   saturation min    -> CondCour_sat_min
%   saturation max    -> CondCour_sat_max
%
% REGULATEUR DE POSITION
%   1.8               -> Vref_position
%   PID gains         -> Kp_pos, Ki_pos, Kd_pos, N_pos
%   sat min/max       -> Iref_sat_min, Iref_sat_max
%
% REGULATEUR DE COURANT
%   2.5               -> Offset_mes_courant
%   gain I_mes        -> K_mes_courant
%   PI gains          -> Kp_i, Ki_i
%   Gain ampli        -> K_gain_ampli_courant
%   sat min/max       -> Vamp_sat_min, Vamp_sat_max
%
% PWM / AMPLIFICATEUR
%   1/5               -> K_pwm_norm
%   5                 -> K_pwm_sortie
%   2.5               -> PWM_demux_offset
%   0.8               -> K_etage_pwm
%   1                 -> K_amplificateur_lineaire
%
% ACTIONNEUR
%   1.63              -> Rb
%   0.5               -> K_force_half
%   integrateur IC    -> i_init
%
% SOLVER / MODELE
%   fixed-step size   -> Ts
%   stop time         -> Tstop

%% ========================================================================
% 13) AIDE-MEMOIRE POUR CALLBACKS SIMULINK
% ========================================================================
% Dans Model Properties > Callbacks > InitFcn, mettre par exemple :
%   run('Init_Simulateur_V10_eq06.m');
%
% Puis dans Model Settings:
%   Type               : Fixed-step
%   Solver             : ode4 (Runge-Kutta)
%   Fixed-step size    : Ts
%   Stop time          : inf

fprintf('Init_Simulateur_V10_eq06.m charge avec succes.\n');
fprintf('Ts = %.6g s | Solver = %s | Stop time = %s\n', Ts, SolverName, 'inf');
