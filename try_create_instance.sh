#!/bin/bash
# Tente de créer l'instance Oracle Cloud. Si "Out of capacity", échoue
# silencieusement (le workflow réessaiera au prochain cron). Si succès,
# affiche l'IP publique, envoie une alerte Telegram et crée un marqueur
# pour que le workflow arrête de réessayer.

set -e

FLAG_FILE="instance_created.flag"

if [ -f "$FLAG_FILE" ]; then
  echo "Instance déjà créée précédemment (voir $FLAG_FILE), rien à faire."
  exit 0
fi

echo "Tentative de création de l'instance..."

OUTPUT=$(oci compute instance launch \
  --compartment-id "$OCI_COMPARTMENT_ID" \
  --availability-domain "$OCI_AVAILABILITY_DOMAIN" \
  --shape "VM.Standard.E2.1.Micro" \
  --display-name "vinted-alerts" \
  --image-id "$OCI_IMAGE_ID" \
  --subnet-id "$OCI_SUBNET_ID" \
  --assign-public-ip true \
  --metadata "{\"ssh_authorized_keys\": \"$OCI_SSH_PUBLIC_KEY\"}" \
  --wait-for-state RUNNING \
  --max-wait-seconds 120 2>&1) && SUCCESS=true || SUCCESS=false

echo "$OUTPUT"

if [ "$SUCCESS" = true ]; then
  echo "✅ Instance créée avec succès !"
  echo "true" > "$FLAG_FILE"

  INSTANCE_ID=$(echo "$OUTPUT" | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

  # Récupère l'IP publique (peut prendre quelques secondes à être assignée)
  sleep 15
  PUBLIC_IP=$(oci compute instance list-vnics \
    --instance-id "$INSTANCE_ID" \
    --query 'data[0]."public-ip"' --raw-output 2>/dev/null || echo "non disponible, vérifie la console")

  MESSAGE="✅ VM Oracle créée avec succès !%0AIP publique : ${PUBLIC_IP}%0AConnecte-toi avec : ssh -i ta-cle.key ubuntu@${PUBLIC_IP}"

  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${MESSAGE}"

  exit 0
else
  if echo "$OUTPUT" | grep -qi "Out of capacity\|OutOfHostCapacity"; then
    echo "⏳ Toujours pas de capacité disponible, on réessaiera au prochain cycle."
    exit 0
  else
    echo "❌ Erreur inattendue :"
    echo "$OUTPUT"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=⚠️ Erreur inattendue lors de la tentative de création de VM (pas un souci de capacité). Vérifie les logs GitHub Actions."
    exit 1
  fi
fi
