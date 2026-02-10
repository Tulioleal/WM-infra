#!/bin/bash
# ============================================================================
# Script para subir modelo pre-entrenado a GCS
# Uso: ./upload_model.sh <ruta_modelo.pt> [version]
# Ejemplo: ./upload_model.sh ./best.pt v1_inicial
# ============================================================================

set -e

# Configuración
BUCKET="waste-detection-001-waste-detection-models-prod"

# Verificar argumentos
if [ -z "$1" ]; then
    echo "❌ Error: Debes especificar la ruta al modelo"
    echo ""
    echo "Uso: $0 <ruta_modelo.pt> [version]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 ./best.pt                    # Sube como 'latest'"
    echo "  $0 ./best.pt v1_inicial         # Sube como versión específica"
    echo "  $0 ./yolov8n_waste_$VERSION.pt inicial   # Sube modelo personalizado"
    exit 1
fi

MODEL_PATH="$1"
VERSION="${2:-latest}"

# Verificar que el archivo existe
if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Error: No se encontró el archivo: $MODEL_PATH"
    exit 1
fi

echo "=============================================="
echo "Subiendo modelo a GCS"
echo "=============================================="
echo "Archivo: $MODEL_PATH"
echo "Bucket: gs://$BUCKET"
echo "Versión: $VERSION"
echo ""

# Subir modelo
echo "📤 Subiendo modelo..."
gsutil cp "$MODEL_PATH" "gs://$BUCKET/models/$VERSION/yolov8n_waste.pt"

# Crear metadata
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
METADATA=$(cat <<EOF
{
    "version": "$VERSION",
    "created_at": "$TIMESTAMP",
    "source": "manual_upload",
    "original_file": "$(basename $MODEL_PATH)",
    "classes": ["plastico", "papel", "carton", "vidrio", "metal", "organico", "textil", "electronico", "peligroso", "otros"]
}
EOF
)

echo "📄 Subiendo metadata..."
echo "$METADATA" | gsutil cp - "gs://$BUCKET/models/$VERSION/metadata.json"

# Si la versión no es 'latest', también actualizar latest
if [ "$VERSION" != "latest" ]; then
    echo "🔄 Actualizando 'latest'..."
    gsutil cp "gs://$BUCKET/models/$VERSION/yolov8n_waste_$VERSION.pt" "gs://$BUCKET/models/latest/yolov8n_waste_$VERSION.pt"
    
    LATEST_METADATA=$(cat <<EOF
{
    "version": "$VERSION",
    "created_at": "$TIMESTAMP",
    "source": "manual_upload",
    "source_version": "$VERSION",
    "classes": ["plastico", "papel", "carton", "vidrio", "metal", "organico", "textil", "electronico", "peligroso", "otros"]
}
EOF
)
    echo "$LATEST_METADATA" | gsutil cp - "gs://$BUCKET/models/latest/metadata.json"
fi

echo ""
echo "=============================================="
echo "✅ Modelo subido exitosamente!"
echo "=============================================="
echo ""
echo "Ubicaciones:"
echo "  - gs://$BUCKET/models/$VERSION/yolov8n_waste_$VERSION.pt"
echo "  - gs://$BUCKET/models/latest/yolov8n_waste_$VERSION.pt"
echo ""
echo "Para que la API use el nuevo modelo:"
echo "  kubectl rollout restart deployment inference-api -n waste-detection"
echo ""
