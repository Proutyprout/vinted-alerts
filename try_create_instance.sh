#!/bin/bash
set -e

FLAG_FILE="instance_created.flag"

if [ -f "$FLAG_FILE" ]; then
  echo "Instance déjà créée précédemment (voir $FLAG_FILE), rien à faire."
  exit 0
fi

if [ -n "$OCI_IMAGE_ID" ]; then
  echo "Utilisation de l'image fournie manuellement : $OCI_IMAGE_ID"
  IMAGE_ID="$OCI_IMAGE_ID"
else
  echo "Recherche de l'image Ubuntu 24.04 la plus récente..."
  IMAGE_ID=$(oci compute image list \
    --compartment-id "$OCI_COMPARTMENT_ID" \
    --operating-system "Canonical Ubuntu" \
    --operating-system-version "24.04" \
    --shape "VM.Standard.E2.1.Micro" \
    --sort-by TIMECREATED --sort-order DESC \
    --query 'data[0].id' --raw-output)
fi

if [ -z "$IMAGE_ID" ] || [ "$IMAGE_ID" = "null" ]; then
  echo "❌ Impossible de trouver une image Ubuntu 24.04 compatible cette fois-ci, on réessaiera au prochain cycle."
  exit 0
fi

echo "Image trouvée : $IMAGE_ID"
echo "Tentative de création de l'instance..."

OUTPUT=$(oci compute instance launch \
  --compartment-id "$OCI_COMPARTMENT_ID" \
  --availability-domain "$OCI_AVAILABILITY_DOMAIN" \
  --shape "VM.Standard.E2.1.Micro" \
  --display-name "vinted-alerts" \
  --image-id "$IMAGE_ID" \
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
  if echo "$OUTPUT" | grep -qi "capacity\|timed out\|timeout\|connection"; then
    echo "⏳ Toujours pas de capacité disponible (ou problème réseau temporaire), on réessaiera au prochain cycle."
    exit 0
  else
    echo "❌ Erreur inattendue :"
    echo "$OUTPUT"
    if [ ! -f error_notified.flag ]; then
      curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=⚠️ Erreur inattendue lors d'une tentative de création de VM (pas capacité/réseau). La boucle continue quand même. Vérifie les logs GitHub Actions si ça persiste."
      echo "true" > error_notified.flag
    fi
    exit 0
  fi
fi
