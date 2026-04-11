function export = build_system_export_struct(cfg)
% build_system_export_struct
% Génère une structure contenant les paramètres physiques et
% prédictions analytiques du système.

    if nargin < 1 || isempty(cfg)
        cfg = default_simulateur_config();
    end

    % ======================
    % PARAMÈTRES LAME
    % ======================
    beam = struct();

    beam.L = cfg.beam.L;
    beam.b = cfg.beam.b;
    beam.h = cfg.beam.h;
    beam.E = cfg.beam.E;
    beam.rho = cfg.beam.rho;
    beam.c = cfg.beam.c;

    % ======================
    % GÉOMÉTRIE
    % ======================
    beam.A = beam.b * beam.h;                 % section
    beam.I = beam.b * beam.h^3 / 12;          % moment inertie
    beam.mu = beam.rho * beam.A;              % masse linéique

    % ======================
    % MASSES
    % ======================
    beam.mass_distributed = beam.mu * beam.L;
    beam.mass_total = beam.mass_distributed + cfg.mass.tipMass;

    % ======================
    % RAIDEUR ÉQUIVALENTE
    % ======================
    if beam.L > 0
        beam.k_equiv = 3 * beam.E * beam.I / (beam.L^3);
    else
        beam.k_equiv = 0;
    end

    % ======================
    % FRÉQUENCE PROPRE
    % ======================
    if beam.mass_total > 0 && beam.k_equiv > 0
        beam.omega_n = sqrt(beam.k_equiv / beam.mass_total);
        beam.f_n_hz = beam.omega_n / (2*pi);
    else
        beam.omega_n = 0;
        beam.f_n_hz = 0;
    end

    % ======================
    % DÉFLEXION STATIQUE
    % ======================
    g = 9.81;

    if beam.k_equiv > 0
        beam.static_deflection_tip_mass = ...
            cfg.mass.tipMass * g / beam.k_equiv;

        beam.static_deflection_external_force = ...
            cfg.force.value / beam.k_equiv;
    else
        beam.static_deflection_tip_mass = 0;
        beam.static_deflection_external_force = 0;
    end

    % ======================
    % EXPORT WORKSPACE
    % ======================
    workspace = struct();

    workspace.L_beam = beam.L;
    workspace.b_beam = beam.b;
    workspace.h_beam = beam.h;
    workspace.E_beam = beam.E;
    workspace.rho_beam = beam.rho;

    workspace.beam_A = beam.A;
    workspace.beam_I = beam.I;
    workspace.beam_mu = beam.mu;

    workspace.beam_mass_total = beam.mass_total;
    workspace.beam_k_equiv = beam.k_equiv;
    workspace.beam_f_n_hz = beam.f_n_hz;

    workspace.tip_mass = cfg.mass.tipMass;
    workspace.F_external = cfg.force.value;

    % ======================
    % CALIBRATION
    % ======================
    calibration = struct();

    calibration.a = cfg.calibration.a;
    calibration.b = cfg.calibration.b;
    calibration.c = cfg.calibration.c;

    % ======================
    % STRUCTURE FINALE
    % ======================
    export = struct();

    export.beam = beam;
    export.mass = cfg.mass;
    export.force = cfg.force;
    export.control = cfg.control;
    export.elec = cfg.elec;
    export.sim = cfg.sim;
    export.calibration = calibration;
    export.workspace = workspace;

end