# Méthode de travail – Projet Simulink avec GitHub

##  Objectif

Ce guide explique comment :

* récupérer le projet (clone)
* travailler dessus
* envoyer vos modifications (push)

---

# 1. Récupérer le projet (clone)

# ⚠️ IMPORTANT

On travail troujours localement
C'est pourquoi il faut cloner

---


### Étape 1 — Ouvrir un terminal

Sur Windows :

* PowerShell
* ou Invite de commande (cmd)

---

### Étape 2 — Aller dans le dossier ou vous voulez créer votre repositoire

Exemple :

```bash
cd H:\document\École\Université\Design 2
```

---

### Étape 3 — Cloner le projet

👉 Copier-coller EXACTEMENT :

```bash
git clone https://github.com/Jotur/Simulink-Design-2.git
```

---

### Étape 4 — Entrer dans le projet

```bash
cd Simulink-Design-2
```

---

#  Comment Travailler sur le projet
1. Se mettre à jour avec gi tpull

```bash
git pull
```

2. Ouvrir le fichier `.slx` dans MATLAB
3. Faire les modifications
4. Sauvegarder

---

# ⚠️ IMPORTANT (Simulink)

 Une seule personne modifie le fichier `.slx` à la fois

Toujours prévenir l’équipe avant de travailler dessus.

---


## Comment ajouter les modification au repositoire

```bash
git add .
```


## Étape 1 — Créer un commit

```bash
git commit -m "Décrire les modifications"
```

Exemples :

* "Ajout du contrôleur PID"
* "Correction du capteur"

---

## Étape 2 — Envoyer sur GitHub

```bash
git push
```

# 🔁 Résumé rapide

```bash
git add .
git commit -m "message"
git push
```

---

# ❌ À éviter

* Ne pas travailler directement sur GitHub (site web)
* Ne pas modifier le `.slx` à plusieurs en même temps
* Ne pas oublier `git pull` avant de travailler

---

# 🛠️ En cas de problème

## Erreur : "not a git repository"

👉 Vous n’êtes pas dans le bon dossier

Faire :

```bash
cd Simulink-Design-2
```


# 📣 Communication

Toujours informer l’équipe :

* avant de modifier le `.slx`
* après avoir push des changements importants

---


Bon travail d’équipe!
