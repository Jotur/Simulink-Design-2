# Simulink-Design-2

# 🤝 Guide de collaboration – Projet Simulink

## 📌 Objectif

Ce dépôt permet de travailler en équipe sur un modèle Simulink en utilisant GitHub.
⚠️ Attention : les fichiers `.slx` étant binaires, certaines règles doivent être respectées pour éviter les conflits.

---

## 🚀 Démarrage

### 1. Cloner le projet

```bash
git clone <URL_DU_REPO>
cd <NOM_DU_REPO>
```

---

### 2. Créer une branche de travail

Toujours travailler sur une branche, jamais directement sur `main`.

```bash
git checkout -b feature-nom
```

Exemples :

* `feature-control`
* `feature-capteur`
* `fix-simulation`

---

## 🔄 Workflow de travail

### Étape 1 — Mettre à jour le projet

Avant de commencer :

```bash
git pull origin main
```

---

### Étape 2 — Travailler sur le projet

* Modifier les fichiers nécessaires (`.slx`, `.m`, etc.)
* Tester la simulation avant de commit

---

### ⚠️ Règle critique (Simulink)

👉 Une seule personne modifie le fichier `.slx` à la fois.

Avant de modifier :

* Informer l’équipe (Discord / Teams / etc.)
* Vérifier que personne ne travaille dessus

---

### Étape 3 — Sauvegarder les modifications

```bash
git add .
git commit -m "Description claire des modifications"
```

Exemples de messages :

* `Ajout du contrôleur PID`
* `Correction du gain du capteur`
* `Refactor du modèle de contrôle`

---

### Étape 4 — Envoyer les changements

```bash
git push origin feature-nom
```

---

### Étape 5 — Créer une Pull Request

* Aller sur GitHub
* Cliquer sur **Compare & pull request**
* Décrire les changements
* Demander une validation si nécessaire

---

## 📁 Organisation du projet

```text
model/      → fichiers Simulink (.slx)
scripts/    → scripts MATLAB (.m)
data/       → données (.mat)
docs/       → documentation
```

---

## 🧠 Bonnes pratiques

### ✔️ Général

* Toujours faire `git pull` avant de travailler
* Utiliser des branches pour chaque modification
* Écrire des messages de commit clairs

---

### ✔️ Simulink

* Ne jamais modifier le `.slx` à plusieurs en même temps
* Tester le modèle avant de commit
* Si possible, diviser le modèle en sous-modèles (Model References)

---

### ✔️ Git

* Ne pas commit les fichiers temporaires (`slprj`, `.slxc`, etc.)
* Faire des commits petits et fréquents
* Ne pas travailler directement sur `main`

---

## 🚫 À éviter

* ❌ Commit sans tester
* ❌ Modifier directement `main`
* ❌ Écraser le travail d’un autre
* ❌ Commit des fichiers générés automatiquement

---

## 🛠️ En cas de problème

### Conflit Git

```bash
git pull
```

Puis résoudre les conflits manuellement.

---

### Problème avec le modèle Simulink

* Comparer les versions avec Simulink Compare
* Revenir à une version précédente si nécessaire

---

## 📣 Communication

La coordination est essentielle :

* Informer l’équipe avant de modifier le `.slx`
* Discuter des changements importants

---

## 🔥 Résumé

* 1 branche par tâche
* 1 personne à la fois sur `.slx`
* Toujours pull avant de travailler
* Commit propre et clair

---

Bon travail d’équipe 🚀
