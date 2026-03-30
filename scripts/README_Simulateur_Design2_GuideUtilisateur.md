# README - Simulateur Design 2

## 1. Objectif du simulateur

Cette interface MATLAB permet de piloter le modèle Simulink `Simulateur_V6_eq06` dans un format plus exploitable pour les essais, la visualisation des signaux et le réglage des paramètres. Elle sert à la fois de panneau de contrôle, d’outil de test et de guide d’exploitation pour reproduire des scénarios expérimentaux proches du prototype.

Le simulateur est conçu pour :
- modifier les paramètres du modèle sans entrer dans tous les sous-systèmes Simulink ;
- lancer et arrêter rapidement une simulation ;
- visualiser les grandeurs utiles sous forme de courbes ;
- calibrer un signal en masse estimée ;
- régler le régulateur ;
- sauvegarder et recharger une configuration d’essai ;
- exporter les résultats et un résumé de scénario.

## 2. Fichiers nécessaires

Placer dans le même dossier :
- `Simulateur_V6_eq06.slx`
- `SimulinkBladeInterface_v2.m` ou la version retenue de l’interface
- `launch_blade_interface.m` ou le lanceur associé à la version retenue

Lancer ensuite dans MATLAB :

```matlab
launch_blade_interface
```

Si le modèle n’est pas chargé, l’interface le charge automatiquement.

## 3. Vue d’ensemble de l’interface

L’interface est divisée en trois zones principales.

### 3.1 Colonne de gauche - contrôle, réglages et état
Cette zone regroupe tout ce qui sert à piloter la simulation et à modifier les paramètres.

### 3.2 Zone centrale - oscilloscope / résultats
Cette zone affiche les courbes principales :
- capteur de position ;
- capteur de courant ;
- commande actionneur ;
- masse estimée / validité.

### 3.3 Colonne de droite - structure du modèle et accès aux signaux
Cette zone sert à :
- naviguer dans les sous-systèmes ;
- afficher l’arborescence du modèle ;
- sélectionner un signal ;
- tracer un signal spécifique ;
- calculer des performances sur les résultats disponibles.

## 4. Description détaillée des commandes et boutons

## 4.1 Contrôle principal

### Lancer
Démarre la simulation avec les paramètres actuellement affichés dans l’interface.

Utilisation typique :
- après avoir modifié un paramètre ;
- après avoir chargé un scénario ;
- après avoir appliqué un réglage PID ou une calibration.

### Stop
Tente d’arrêter la simulation en cours.

Utilisation typique :
- interrompre un essai ;
- éviter d’attendre la fin d’une simulation trop longue ;
- relancer après une erreur de réglage.

### Appliquer
Envoie les paramètres de l’interface vers le modèle Simulink.

Ce bouton sert à écrire dans le modèle :
- les paramètres mécaniques ;
- le temps de simulation ;
- certains réglages d’exploitation ;
- les gains du régulateur si l’architecture associée est prévue dans le modèle.

À utiliser systématiquement après modification manuelle de champs.

### Sync
Recharge dans l’interface les paramètres actuellement présents dans le modèle.

À utiliser pour :
- vérifier ce qui est réellement chargé dans Simulink ;
- éviter un décalage entre l’interface et le modèle ;
- récupérer des valeurs modifiées directement dans Simulink.

## 4.2 Réglages de conduite

### Pos. équilibre / Équilibre
Consigne ou référence d’équilibre de la lame ou de la grandeur asservie.

Utilité :
- déplacer la position nominale de fonctionnement ;
- tester la réponse du système autour d’un autre point de fonctionnement.

### Biais commande / Biais
Offset ajouté à la commande.

Utilité :
- compenser un décalage statique ;
- tester le comportement avec une précharge de commande ;
- reproduire un réglage d’essai du prototype.

### Ts
Pas d’échantillonnage utilisé pour la logique de pilotage ou la partie numérique, si ce paramètre est raccordé dans le modèle.

Utilité :
- tester l’effet d’une fréquence d’échantillonnage plus ou moins élevée ;
- rapprocher la simulation du prototype réel.

### Asservissement ON/OFF
Active ou désactive l’état d’asservissement dans l’interface.

Utilité :
- comparer un comportement libre et un comportement régulé ;
- reproduire des essais avec ou sans boucle fermée.

### Scénario / Preset / Charger
Permet de sélectionner un cas de test puis de charger automatiquement un préréglage.

Scénarios disponibles :
- Manuel
- Calibration
- Échelon 50 g
- Échelon 100 g gauche
- Échelon 100 g droite
- Tare
- Échelon 1 mm
- Robustesse

Le bouton `Charger` applique le preset associé au scénario sélectionné.

## 4.3 Paramètres mécaniques

Cette section contient les paramètres de la lame et des grandeurs mécaniques associées. Selon la version actuelle de l’interface, on y retrouve notamment :
- amortissement `b` ;
- distance du plateau `q` ;
- largeur `l` ;
- longueur `L` ;
- module de Young `E` ;
- densité ;
- épaisseur `h`.

### Rôle des paramètres

#### Amortissement `b`
Représente les pertes dissipatives.

Influence principale :
- plus `b` augmente, plus la réponse est amortie ;
- les oscillations diminuent ;
- le temps de montée peut devenir plus lent.

#### Distance du plateau `q`
Paramètre géométrique lié à l’emplacement ou au bras de levier de l’action appliquée.

Influence principale :
- modifie la sensibilité mécanique ;
- peut affecter la dynamique et l’effort transmis.

#### Largeur `l`, longueur `L`, épaisseur `h`
Paramètres géométriques de la lame.

Influence principale :
- ces paramètres changent la rigidité ;
- une lame plus longue est généralement plus souple ;
- une lame plus épaisse est fortement plus rigide.

#### Module de Young `E`
Mesure la rigidité du matériau.

Pour la lame G10/FR4, la valeur catalogue issue du document matériau est d’environ :
- `E ≈ 1.86e10 Pa` soit `18.6 GPa` pour la valeur de flexion longitudinale ;
- une valeur voisine de `1.7e10 Pa` a aussi été utilisée dans le modèle comme valeur ajustée.

Influence principale :
- plus `E` augmente, plus la lame devient rigide ;
- le déplacement pour une même force diminue ;
- la fréquence propre augmente.

#### Densité
Intervient dans l’inertie.

Influence principale :
- modifie la masse équivalente ;
- influence la dynamique et les fréquences.

## 4.4 Calibration masse

Cette section sert à convertir un signal simulé en masse estimée.

### Signal source
Choisit le signal utilisé comme base de calibration.

Exemples proposés :
- `masse`
- `positionlame`
- `commande`
- `capteur_position`

### Pente [g/V]
Coefficient multiplicateur de conversion.

### Offset [g]
Décalage fixe appliqué à la masse estimée.

### Estimer depuis 2 pts
Ouvre une procédure de calibration à deux points.

Principe :
- on donne deux points connus du type `(signal, masse)` ;
- l’interface calcule automatiquement la pente et l’offset.

Utilité :
- reproduire une calibration expérimentale simple ;
- ajuster la conversion à partir de deux mesures de référence.

### Appliquer calibration
Recalcule les signaux dérivés et met à jour la masse estimée à partir de la pente et de l’offset saisis.

## 4.5 Régulateur

### Kp
Gain proportionnel.

Effet principal :
- augmente la réactivité ;
- trop élevé, il peut produire des oscillations.

### Ki
Gain intégral.

Effet principal :
- réduit l’erreur statique ;
- trop élevé, il peut dégrader la stabilité.

### Kd
Gain dérivé.

Effet principal :
- améliore l’amortissement et l’anticipation ;
- sensible au bruit si mal utilisé.

### Appliquer PID
Envoie les gains PID saisis vers le modèle.

### Lire PID
Lit les gains actuellement présents dans le modèle et les affiche dans l’interface.

## 4.6 État

Cette section contient des indicateurs numériques et visuels.

### Masse [g]
Valeur de masse estimée calculée à partir de la calibration.

### Commande [V]
Commande actionneur lue ou estimée sur le dernier résultat disponible.

### Position
Grandeur de position actuelle ou finale.

### Courant
Grandeur de courant actuelle ou finale.

### Stable
Voyant de stabilité.

Lecture générale :
- orange/rouge : régime non stabilisé ou indéterminé ;
- vert : signal considéré comme stabilisé selon le critère interne.

### Mesure valide
Voyant de validité de mesure.

Lecture générale :
- orange/rouge : mesure absente, incohérente ou hors critère ;
- vert : signal détecté comme valide.

## 4.7 Sauvegarde et export

### Save JSON
Enregistre toute la configuration actuelle dans un fichier JSON.

Contenu typique :
- paramètres mécaniques ;
- temps de simulation ;
- réglages de calibration ;
- gains PID ;
- scénario sélectionné ;
- autres champs utiles.

Utilité :
- conserver un point de fonctionnement ;
- partager une configuration ;
- revenir à un réglage qui a bien marché.

### Load JSON
Recharge une configuration enregistrée précédemment.

### Export CSV
Exporte les signaux disponibles vers un fichier CSV.

Utilité :
- exploitation dans Excel ;
- post-traitement ;
- insertion dans un rapport.

### Export rapport
Génère un résumé texte du scénario courant avec les principaux paramètres et réglages.

## 4.8 Accès au modèle

### Ouvrir le modèle
Ouvre directement le schéma Simulink complet.

### Mettre à jour signaux
Actualise la liste des signaux accessibles dans l’interface.

À utiliser après :
- ajout d’un signal loggé ;
- modification des `To Workspace` ;
- changement de structure du modèle.

## 4.9 Zone de droite - structure et signaux

### Arborescence du modèle
Affiche les sous-systèmes du modèle, par exemple :
- `ARDUINO`
- `Actionneur`
- `CAPTEURS ET CONDITIONNEURS`
- `Lame`

Utilité :
- retrouver rapidement un bloc ;
- ouvrir un sous-système ciblé ;
- vérifier l’organisation du modèle.

### Liste des signaux
Affiche les signaux détectés.

Exemples vus dans la liste :
- `mesureValide`
- `valid_measure`
- `valid`
- `masse`
- `mass`
- `mass_est`
- `masse_estimee`

### Tracer signal sélectionné
Trace dans la zone centrale le signal choisi dans la liste.

### Calculer performances
Calcule des indicateurs de performance à partir du signal sélectionné ou des résultats disponibles.

Indicateurs typiques selon le signal et le scénario :
- temps d’établissement ;
- erreur finale ;
- écart-type final ;
- validité ;
- cible atteinte ou non.

## 5. Signification des graphes

## 5.1 Capteur de position
Affiche l’évolution du signal de position.

Utilité :
- vérifier la dynamique ;
- observer les oscillations ;
- mesurer le temps de stabilisation.

## 5.2 Capteur de courant
Affiche le signal de courant ou une grandeur équivalente reliée à l’actionneur.

Utilité :
- vérifier les pics d’effort ;
- détecter une saturation potentielle ;
- comparer les scénarios de charge.

## 5.3 Commande actionneur
Affiche le signal de commande envoyé à l’actionneur.

Utilité :
- observer l’action du régulateur ;
- vérifier la présence d’un biais ;
- évaluer la violence d’une correction.

## 5.4 Masse estimée / validité
Affiche la masse estimée issue de la calibration, et éventuellement l’état de validité.

Utilité :
- voir directement la grandeur utile pour les essais de charge ;
- comparer la réponse estimée avec la cible ;
- valider le comportement de la mesure.

## 6. Procédure utilisateur type

## 6.1 Démarrage rapide
1. Ouvrir MATLAB.
2. Placer le modèle et l’interface dans le même dossier.
3. Lancer `launch_blade_interface`.
4. Vérifier que le modèle `Simulateur_V6_eq06` est chargé.
5. Cliquer sur `Sync` pour récupérer les valeurs du modèle.
6. Vérifier ou modifier les paramètres.
7. Cliquer sur `Appliquer`.
8. Cliquer sur `Lancer` pour exécuter la simulation.
9. Observer les courbes.
10. Exporter les résultats si nécessaire.

## 6.2 Procédé expérimental exemple - obtenir une simulation exploitable

L’objectif de cet exemple est de reproduire un essai simple de charge et d’obtenir des courbes propres, une masse estimée et quelques performances.

### Exemple : essai de type échelon 50 g

#### Étape 1 - préparer le modèle
- lancer l’interface ;
- cliquer sur `Sync` ;
- vérifier que les paramètres mécaniques sont cohérents ;
- vérifier en particulier `E`, `b`, `L`, `l`, `h`.

Référence matériau conseillée pour la lame G10/FR4 :
- `E ≈ 1.86e10 Pa` comme valeur catalogue ;
- ou `1.7e10 Pa` si vous reprenez la valeur ajustée du modèle.

#### Étape 2 - choisir le scénario
- dans `Scénario`, sélectionner `Échelon 50 g` ;
- cliquer sur `Charger` pour appliquer le preset ;
- vérifier le `StopTime` proposé.

#### Étape 3 - choisir les réglages de conduite
- fixer la position d’équilibre à la valeur de référence du montage ;
- laisser le biais à `0` au premier essai ;
- mettre l’asservissement sur `ON` si l’essai doit être régulé ;
- vérifier le pas d’échantillonnage `Ts`.

#### Étape 4 - calibrer la masse
Méthode simple :
- choisir une source de signal pertinente dans `Signal source` ;
- entrer une pente initiale et un offset ;
- cliquer sur `Appliquer calibration`.

Méthode plus rigoureuse :
- cliquer sur `Estimer depuis 2 pts` ;
- saisir deux points de référence ;
- appliquer la calibration ;
- vérifier que la masse estimée est plausible.

#### Étape 5 - régler le régulateur
- saisir `Kp`, `Ki`, `Kd` ;
- cliquer sur `Appliquer PID`.

Conseil de départ :
- commencer avec un `Kp` modéré ;
- garder `Ki = 0` et `Kd = 0` au tout début ;
- ajouter ensuite l’intégrale ou la dérivée progressivement.

#### Étape 6 - lancer la simulation
- cliquer sur `Appliquer` pour pousser tous les réglages ;
- cliquer sur `Lancer`.

#### Étape 7 - observer les résultats
Pendant ou après la simulation, analyser :
- la position ;
- la commande ;
- le courant ;
- la masse estimée ;
- les voyants de stabilité et de validité.

Ce qu’on cherche en général :
- une réponse rapide ;
- peu d’oscillation ;
- une masse estimée stable ;
- une commande raisonnable ;
- une mesure valide.

#### Étape 8 - calculer les performances
- sélectionner le signal le plus utile dans la liste de droite ;
- cliquer sur `Calculer performances`.

#### Étape 9 - exporter
- cliquer sur `Export CSV` pour les courbes ;
- cliquer sur `Export rapport` pour un résumé d’essai ;
- éventuellement enregistrer la configuration avec `Save JSON`.

#### Étape 10 - itérer
Comparer plusieurs essais en ne changeant qu’un seul élément à la fois :
- gains PID ;
- amortissement ;
- module de Young ;
- offset ou pente de calibration ;
- scénario ;
- pas d’échantillonnage.

C’est la seule façon sérieuse de comprendre ce qui améliore vraiment le comportement, au lieu de tout changer au hasard comme dans un rituel approximatif.

## 7. Procédé expérimental conseillé pour le projet

Pour obtenir une simulation crédible et défendable, il est recommandé de suivre cet ordre.

### Phase 1 - cohérence physique
Valider d’abord :
- matériau de la lame ;
- géométrie ;
- module de Young ;
- densité ;
- amortissement approximatif.

### Phase 2 - calibration mesure
Valider ensuite :
- le choix du signal source ;
- la pente [g/V] ;
- l’offset [g] ;
- la cohérence masse estimée / stimulus imposé.

### Phase 3 - réglage de la boucle
Ajuster :
- `Kp` ;
- puis `Ki` ;
- puis `Kd` si nécessaire.

### Phase 4 - validation par scénarios
Tester plusieurs scénarios :
- calibration ;
- tare ;
- échelon 50 g ;
- échelon 100 g ;
- échelon 1 mm ;
- robustesse.

### Phase 5 - export et comparaison
Conserver les résultats :
- fichiers JSON pour les réglages ;
- CSV pour les signaux ;
- rapport texte pour les synthèses.

## 8. Conseils d’interprétation des résultats

### Réponse trop lente
Causes possibles :
- `Kp` trop faible ;
- amortissement trop élevé ;
- lame trop rigide ou trop massive ;
- `Ts` trop grand.

### Réponse oscillante
Causes possibles :
- `Kp` trop fort ;
- `Ki` trop fort ;
- amortissement insuffisant ;
- calibration incohérente ;
- commande trop agressive.

### Masse estimée incohérente
Causes possibles :
- mauvaise source de signal ;
- pente fausse ;
- offset faux ;
- signal non valide ;
- confusion d’unités.

### Simulation inutilisable
Vérifier :
- unités SI partout ;
- présence des signaux dans le modèle ;
- cohérence des noms de variables ;
- temps de simulation suffisant ;
- boutons `Appliquer` puis `Lancer` exécutés dans cet ordre.

## 9. Recommandations pratiques pour la soutenance ou l’évaluation

Avant une démonstration, préparer :
- un scénario stable et reproductible ;
- une calibration déjà vérifiée ;
- une configuration JSON prête à charger ;
- un ou deux tests courts à lancer en direct ;
- un export CSV déjà exploité dans un graphique propre.

Le plus convaincant n’est pas de montrer vingt boutons. C’est de montrer que :
- vous savez ce qu’ils font ;
- vous savez pourquoi vous les utilisez ;
- et vos courbes racontent quelque chose de cohérent.

## 10. Résumé ultra rapide d’utilisation

Ordre minimal conseillé :
1. `Sync`
2. régler paramètres
3. choisir scénario
4. `Charger`
5. calibrer si nécessaire
6. régler PID
7. `Appliquer`
8. `Lancer`
9. observer
10. `Export CSV` / `Export rapport`

## 11. Pistes d’amélioration futures

Pour une version encore plus robuste, on peut ajouter :
- lancement automatique de séquences d’essais ;
- comparaison de deux simulations sur les mêmes axes ;
- génération automatique de figures pour le rapport ;
- gestion plus fine des cibles par scénario ;
- validation automatique des unités et des bornes ;
- bouton de remise à zéro complet.

