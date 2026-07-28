# Vinted Alerts — Tentatives automatiques de création de VM Oracle

Ce dossier contient un système qui redemande automatiquement à Oracle Cloud
de créer ta VM gratuite toutes les 10 minutes, jusqu'à ce que la capacité
soit disponible. Dès que ça réussit, tu reçois une alerte Telegram avec
l'adresse IP de ta nouvelle VM.

## Secrets GitHub à configurer

Dans ton dépôt GitHub : **Settings → Secrets and variables → Actions → New repository secret**

| Nom du secret | Où le trouver |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Le token de ton bot (BotFather) |
| `TELEGRAM_CHAT_ID` | Ton chat_id récupéré précédemment |
| `OCI_USER_OCID` | Bloc "Configuration File Preview" → ligne `user=` |
| `OCI_FINGERPRINT` | Bloc "Configuration File Preview" → ligne `fingerprint=` |
| `OCI_TENANCY_OCID` | Bloc "Configuration File Preview" → ligne `tenancy=` |
| `OCI_REGION` | Bloc "Configuration File Preview" → ligne `region=` |
| `OCI_PRIVATE_KEY` | Contenu complet du fichier `.pem` téléchargé (clé API) |
| `OCI_AVAILABILITY_DOMAIN` | Nom exact de ton AD, ex: `UMOY:EU-PARIS-1-AD-1` |
| `OCI_SUBNET_ID` | OCID du "public subnet-Vintedalertscloud" |
| `OCI_IMAGE_ID` | OCID de l'image Ubuntu 24.04 dans ta région |
| `OCI_SSH_PUBLIC_KEY` | Contenu complet du fichier `.pub` (clé SSH, pas la clé API) |

## Note importante

Ce script utilise le shape gratuit `VM.Standard.E2.1.Micro`. Si tu préfères
retenter ta chance sur le plus puissant `VM.Standard.A1.Flex` (Ampere,
1-4 OCPU / 6-24 GB), remplace la ligne `--shape` dans
`try_create_instance.sh` et ajoute `--shape-config` avec le nombre d'OCPU et
la mémoire souhaités.

## Une fois la VM créée

Le workflow s'arrête automatiquement tout seul (grâce au fichier
`instance_created.flag`). Tu reçois l'IP publique par Telegram — reprends
alors le guide précédent (connexion SSH, transfert des fichiers, lancement
du script Vinted) à partir de l'étape "Se connecter à la VM".
