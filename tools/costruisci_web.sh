#!/bin/bash
# Esporta il gioco (Godot web) in build/web e ci copia accanto la pagina dei telefoni.
# Uso: tools/costruisci_web.sh [comando godot]
set -e
cd "$(dirname "$0")/.."
GODOT=${1:-godot}
rm -rf build/web
mkdir -p build/web
$GODOT --headless --path . --import >/dev/null 2>&1 || true
$GODOT --headless --path . --export-release "Web" build/web/index.html
test -f build/web/index.pck
cp -r web/telefono.html web/js web/css web/font web/img build/web/
# numero di versione (data e ora) per non far usare al browser i file vecchi
V=$(date -u +%Y%m%d%H%M)
sed -i "s/__VERSIONE__/$V/g" build/web/index.html
sed -i "s#js/telefono.js#js/telefono.js?v=$V#; s#css/telefono.css#css/telefono.css?v=$V#" build/web/telefono.html
# anche i moduli importati dagli altri moduli, altrimenti un file vecchio in cache rompe gli import
sed -i -E "s#from '\./(rete|suoni)\.js'#from './\1.js?v=$V'#g" build/web/js/ponte.js build/web/js/telefono.js
touch build/web/.nojekyll
echo "Pronto in build/web"
