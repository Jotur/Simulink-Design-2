function export = build_system_export_struct(cfg)
% build_system_export_struct
% Prépare une structure propre d'export pour le simulateur système, le
% workspace et d'éventuels rapports de vérification.

    if nargin < 1 || isempty(cfg)
        cfg = default_simulateur_config();
    end

    beam = struct();
    beam.L = cfg.beam.L;
    beam.b = cfg.beam.b;
    beam.h = cfg.beam.h;
    beam.E = cfg.beam.E;
    beam.rho = cfg.beam.rho;
    beam.c = cfg.beam.c;
    beam.base = cfg.beam.base;
    beam.plateauDistance = cfg.beam.plateauDistance;

    beam.A = beam.b * beam.h;
    beam.I = beam.b * beam.h^3 / 12;
    beam.mu = beam.rho * beam.A;
    beam.mass_distributed = beam.mu * beam.L;
    beam.mass_total = beam.mass_distributed + cfg.mass.tipMass;

    if beam.mass_total > 0
        beam.k_equiv = 3 * beam.E * beam.I / max(beam.L, eps)^3;
        beam.omega_n = sqrt(max(beam.k_equiv / beam.mass_total, 0));
        beam.f_n_hz = beam.omega_n / (2*pi);
    else
        beam.k_equiv = 0;
        beam.omega_n = 0;
        beam.f_n_hz = 0;
    end

    if beam.k_equiv > 0
        beam.static_deflection_tip_mass = cfg.mass.tipMass * 9.81 / beam.k_equiv;
        beam.static_deflection_external_force = cfg.force.value / beam.k_equiv;
    else
        beam.static_deflection_tip_mass = 0;
        beam.static_deflection_external_force = 0;
    end

    workspace = struct();
    workspace.L_beam = beam.L;
    workspace.b_beam = beam.b;
    workspace.h_beam = beam.h;
    workspace.E_beam = beam.E;
    workspace.rho_beam = beam.rho;
    workspace.c_beam = beam.c;
    workspace.beam_A = beam.A;
    workspace.beam_I = beam.I;
    workspace.beam_mu = beam.mu;
    workspace.beam_mass_distributed = beam.mass_distributed;
    workspace.beam_mass_total = beam.mass_total;
    workspace.beam_k_equiv = beam.k_equiv;
    workspace.beam_omega_n = beam.omega_n;
    workspace.beam_f_n_hz = beam.f_n_hz;
    workspace.tip_mass = cfg.mass.tipMass;
    workspace.mass_start_time = cfg.mass.startTime;
    workspace.F_external = cfg.force.value;
    workspace.position_setpoint = cfg.control.positionSetpoint;
    workspace.current_setpoint = cfg.control.currentSetpoint;
    workspace.fs_adc = cfg.elec.fs_adc;
    workspace.fs_pwm = cfg.elec.fs_pwm;
    workspace.adc_bits = cfg.elec.adc_bits;
    workspace.dac_bits = cfg.elec.dac_bits;
    workspace.fc_antialias = cfg.elec.antiAliasFc;
    workspace.fc_reconstruction = cfg.elec.reconstructionFc;
    workspace.v_limit = cfg.elec.vmax;
    workspace.i_limit = cfg.elec.imax;

    export = struct();
    export.beam = beam;
    export.mass = cfg.mass;
    export.force = cfg.force;
    export.control = cfg.control;
    export.elec = cfg.elec;
    export.sim = cfg.sim;
    export.calibration = cfg.calibration;
    export.ui = cfg.ui;
    export.workspace = workspace;
end
