%% ------------------------------------------------------Ficher Init Simulink-----------------------------------------------------------
% Initialisation centralisee des variables du modele Simulink

clearvars -except ans;
clc;

%% ========================================================================
% 1) PARAMETRES GENERAUX DE SIMULATION
% ========================================================================
Ts = 2e-6;                 % |ou 1e-3 max| Pas de calcul/sampling principal [s]
Ts_reg = 2e-3;      % 500 Hz
Tstop = inf;               % Mode fonctionnement permanent
SolverType = 'Fixed-step'; 
SolverName = 'ode4';       

% Frequences utiles
fs = 1/Ts;                 % [Hz]

%% ========================================================================
% 2) LAME / MASSE / GRANDEURS MECANIQUES
% ========================================================================


Masse = 0; % Entree de la masse appliquee au plateau entre 0 et 0.1 kg 

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
Cpa = 1;
Offset_b = 2.5;


%% ========================================================================
% 5) CAPTEUR DE COURANT
% ========================================================================
% Gain Variable de la resistance shunt de 1.
Ksh = 1;

%% ========================================================================
% 6) CONDITIONNEMENT DE COURANT
% ========================================================================
Ccoff = 2.5;
G_rant = 0.5;
Ccmin = 0;
Ccmax = 5;

%% ========================================================================
% 7) REGULATEUR DE POSITION
% ========================================================================
Ts_p = Ts_reg; % PID
Vref = 1.8;    % consigne pos

% Gains du PID(z) de position
Kp_pos = 0.85;
Ki_pos = 2.8333;
Kd_pos = 0.017;
N_pos  = 100;     

% Saturation de sortie du regulateur de position
Irmin = -2.9; % sat min Iref
Irmax =  2.9; % sat max Iref


%% ========================================================================
% 8) REGULATEUR DE COURANT
% ========================================================================
Ts_i = Ts_reg;
Imoff = 2.5;  
Km = 1/1.1;  

% Gains du PI(z) de courant
Kp_i = 0.18;
Ki_i = 180;

% Gain additionnel 
Kamp = 0.95;

Vmoff = 2.5; 

% Saturation de sortie du regulateur de courant
Vamp_min = 0;
Vamp_max = 5;

%% ========================================================================
% 9) PWM / ARDUINO / AMPLIFICATEUR
% ========================================================================
% Normalisation de la commande analogique avant comparaison PWM
K_pwm = 1/5;

% Dent de scie / porteuse PWM
fpwm = 500;             % [Hz] a ajuster selon votre implantation
Tpwm = 1/fpwm;          % [s]
Apwm = 1;               % Amplitude PWM
Opwm = 0;               % Offset PWM
Kpwmo = 5;              % Gain sortie PWM

% Fonction de transfert
numP = [1]; % num TF PWM
denP = [3.1861e-12 3.9953e-7 1.4575e-3 1]; % den TF PWM


Opwmd = 2.5; % offset etage PWM
Kpwme = 0.8; % gain etage PWM
KampL = 1;   % gain ampli final


Vamin = 0; % sat min Vactionneur
Vamax = 5; % sat max Vactionneur

%% ========================================================================
% 10) ACTIONNEUR ELECTROMAGNETIQUE (POLYFIT)
% ========================================================================
Rb = 1.63;              % Resistance bobine [ohm]
Kf = 0.5;               % Gain 0.5 

i0 = 0;                 % Condition initiale du courant integre
F0 = 0;                 % Condition initiale force [N]

G_act = -1;

% Polynome L(x) = aL2*x^2 + aL1*x + aL0
aL2 = -4.55e-6;
aL1 = -9.95e-6;
aL0 =  1.1256e-3;

% Polynome dL/dx(x) = adL1*x + adL0
adL1 = -9.10e-6;
adL0 = -9.95e-6;

% Polynome dPhi/dx(x) = aPhi1*x + aPhi0
aPhi1 =  5.96e-5;
aPhi0 = -1.41e-2;

% Polynome Kb(x) = aKb1*x + aKb0
aKb1 =  5.96e-5;
aKb0 = -1.41e-2;


fprintf('Init_Simulateur_V10_eq06.m charge avec succes.\n');
fprintf('Ts = %.6g s | Solver = %s | Stop time = %s\n', Ts, SolverName, 'inf');
