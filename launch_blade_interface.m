function launch_blade_interface(modelName)
% Lance l'interface du simulateur
if nargin < 1 || strlength(string(modelName)) == 0
    modelName = "Simulateur_V6_eq06";
end
SimulinkBladeInterface(modelName);
end
