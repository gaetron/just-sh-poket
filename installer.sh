#!/data/data/com.termux/files/usr/bin/bash
# installer.sh - installa just.sh in Termux

#region config
REPO_RAW="https://raw.githubusercontent.com/gaetron/just-sh-poket/main"
REMOTE_NAME="%28poket%29just.sh"
LOCAL_NAME="(poket)just.sh"
INSTALL_DIR="/storage/emulated/0/programmi/Just.sh"
#endregion

#region storage
if [ ! -w /storage/emulated/0 ]; then
    echo "Serve il permesso di accesso ai file: conferma la richiesta che compare."
    termux-setup-storage
    for i in $(seq 1 30); do
        [ -w /storage/emulated/0 ] && break
        sleep 1
    done
fi

if [ ! -w /storage/emulated/0 ]; then
    echo "Permesso storage non concesso. Concedilo e rilancia l'installer."
    exit 1
fi
#endregion

#region download
mkdir -p "$INSTALL_DIR" || { echo "Impossibile creare $INSTALL_DIR"; exit 1; }

TARGET="$INSTALL_DIR/$LOCAL_NAME"
[ -f "$TARGET" ] && cp "$TARGET" "$TARGET.bak"

echo "Scarico $LOCAL_NAME..."
if ! curl -fsSL "$REPO_RAW/$REMOTE_NAME" -o "$TARGET.tmp"; then
    echo "Download fallito: controlla la connessione e riprova."
    rm -f "$TARGET.tmp"
    exit 1
fi
mv "$TARGET.tmp" "$TARGET"
#endregion

#region shortcut
mkdir -p "$HOME/.shortcuts"
rm -f "$HOME/.shortcuts/$LOCAL_NAME"
printf '#!/data/data/com.termux/files/usr/bin/bash\nexec bash %q\n' "$TARGET" > "$HOME/.shortcuts/$LOCAL_NAME"
chmod +x "$HOME/.shortcuts/$LOCAL_NAME"
#endregion

#region fine
echo ""
echo "Installazione completata."
echo "Script: $TARGET"
echo ""
read -p "Vuoi vedere come creare la shortcut sulla schermata home? (s/n): " risp </dev/tty
case "${risp,,}" in
    s|si|y|yes)
        echo ""
        echo "1. Installa l'app Termux:Widget (dalla stessa fonte di Termux, es. F-Droid)"
        echo "2. Tieni premuto sulla schermata home e apri Widget"
        echo "3. Cerca Termux:Widget e trascina il widget sulla home"
        echo "4. Scegli \"$LOCAL_NAME\" dall'elenco"
        ;;
esac
#endregion