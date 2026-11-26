#!/data/data/com.termux/files/usr/bin/bash
# just.sh - solo interfaccia

#region boot
if ! command -v curl >/dev/null 2>&1 || ! command -v pip >/dev/null 2>&1; then
    echo "Installo dipendenze mancanti (curl, python)..."
    pkg install -y curl python
fi
#endregion

#region utility1 - yt-dlp
utility1() {
    clear
    SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

    if curl -s --max-time 3 -o /dev/null https://pypi.org; then
        echo "Controllo aggiornamenti yt-dlp..."
        pip install --upgrade yt-dlp yt-dlp-ejs >/dev/null 2>&1

        echo "Controllo aggiornamenti ffmpeg..."
        pkg install -y ffmpeg >/dev/null 2>&1

        echo "Controllo aggiornamenti nodejs..."
        pkg install -y nodejs >/dev/null 2>&1
    else
        echo "Nessuna connessione, salto controllo aggiornamenti."
    fi

    if ! command -v yt-dlp >/dev/null 2>&1; then
        echo "yt-dlp non installato e nessuna connessione disponibile."
        read -p "Premi INVIO per continuare..." _
        return 1
    fi

    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "ffmpeg non installato e nessuna connessione disponibile: le conversioni audio/video non funzioneranno."
    fi

    EXTRA=(--js-runtimes node)
    [ -f "$SCRIPT_DIR/cookies.txt" ] && EXTRA+=(--cookies "$SCRIPT_DIR/cookies.txt")

    echo ""
    echo "cartella di download:"
    echo "vuoto=default"
    echo "music=musica"
    read -p ": " destdir
    case "${destdir,,}" in
        "")    destdir="$SCRIPT_DIR/download" ;;
        music) destdir="/storage/emulated/0/Music" ;;
    esac
    mkdir -p "$destdir"

    read -p "Formato (mp3, mp4, ecc): " formato

    link="$1"
    [ -z "$link" ] && read -p "Link video: " link

    if [ "$formato" = "mp3" ]; then
        yt-dlp "${EXTRA[@]}" -x --audio-format mp3 -o "$destdir/%(title)s.%(ext)s" "$link"
    else
        yt-dlp "${EXTRA[@]}" --recode-video "$formato" -o "$destdir/%(title)s.%(ext)s" "$link"
    fi

    read -p "Premi INVIO per continuare..." _
}
#endregion

#region utility2 - neofetch+
utility2() {
    clear

    if curl -s --max-time 3 -o /dev/null https://pypi.org; then
        command -v neofetch >/dev/null 2>&1 || pkg install -y neofetch
        command -v jq >/dev/null 2>&1 || pkg install -y jq
        command -v termux-battery-status >/dev/null 2>&1 || pkg install -y termux-api
    fi

    neofetch

    echo ""
    echo "== Batteria =="
    if command -v termux-battery-status >/dev/null 2>&1; then
        BATT_JSON=$(termux-battery-status 2>/dev/null)
        if [ -n "$BATT_JSON" ]; then
            PERC=$(echo "$BATT_JSON" | jq -r '.percentage')
            HEALTH=$(echo "$BATT_JSON" | jq -r '.health')
            echo "Livello: ${PERC}%"
            echo "Salute: $HEALTH"
        else
            echo "Impossibile leggere lo stato batteria (apri l'app Termux:API almeno una volta e concedi i permessi)."
        fi
    else
        echo "termux-api non disponibile (serve anche l'app Termux:API installata separatamente)."
    fi

    CAP_DESIGN=$(cat /sys/class/power_supply/battery/charge_full_design 2>/dev/null)
    CAP_NOW=$(cat /sys/class/power_supply/battery/charge_full 2>/dev/null)
    if [ -n "$CAP_DESIGN" ] && [ -n "$CAP_NOW" ]; then
        echo "Capacità di fabbrica: $((CAP_DESIGN / 1000)) mAh"
        echo "Capacità attuale: $((CAP_NOW / 1000)) mAh"
    else
        echo "Capacità di fabbrica/attuale: non accessibile senza root su questo dispositivo."
    fi

    echo ""
    echo "== Archiviazione =="
    df -h /data 2>/dev/null | awk 'NR==2 {print "Totale: "$2"\nUsato: "$3"\nLibero: "$4}'

    echo ""
    echo "== Rete =="
    IP_ADDR=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    if [ -n "$IP_ADDR" ]; then
        echo "IP locale: $IP_ADDR ($IFACE)"
        if ip addr show "$IFACE" 2>/dev/null | grep -q "dynamic"; then
            echo "Assegnazione: dinamica (DHCP)"
        else
            echo "Assegnazione: statica"
        fi
    else
        echo "Nessuna connessione di rete attiva."
    fi

    read -p "Premi INVIO per continuare..." _
}
#endregion

#region utility3 - scanner rete
utility3() {
    clear

    json_field() {
        case "$1" in
            "{"*) echo "$1" | jq -r ".$2 // empty" 2>/dev/null ;;
        esac
    }

     if curl -s --max-time 3 -o /dev/null https://pypi.org; then
        echo "Controllo aggiornamenti nmap..."
        pkg install -y nmap >/dev/null 2>&1

        echo "Controllo aggiornamenti net-tools..."
        pkg install -y net-tools >/dev/null 2>&1

        echo "Controllo aggiornamenti dnsutils..."
        pkg install -y dnsutils >/dev/null 2>&1

        echo "Controllo aggiornamenti termux-api..."
        pkg install -y termux-api >/dev/null 2>&1

        echo "Controllo aggiornamenti jq..."
        pkg install -y jq >/dev/null 2>&1
    else
        echo "Nessuna connessione internet, salto controllo aggiornamenti."
    fi

    NETS=$(ifconfig 2>/dev/null | awk '
        /^[^ \t]/ { iface=$1; sub(/:$/,"",iface) }
        /inet / && iface !~ /^(lo|rmnet|ccmni|v4-|dummy|tun|ipsec|clat)/ {
            ip=$2; mask=$4
            if (ip !~ /^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/) next
            n=split(mask,m,"."); bits=0
            for (i=1;i<=n;i++) { v=m[i]+0; while (v>0) { bits+=v%2; v=int(v/2) } }
            if (bits<24) bits=24
            printf "%s %s %d\n", iface, ip, bits
        }')

    if [ -z "$NETS" ]; then
        WIP=$(json_field "$(termux-wifi-connectioninfo 2>/dev/null)" ip)
        if [ -n "$WIP" ] && [ "$WIP" != "0.0.0.0" ]; then
            NETS="wlan0 $WIP 24"
        fi
    fi

    if [ -z "$NETS" ]; then
        echo "Nessuna rete locale trovata (collegati a un wifi o attiva l'hotspot)."
        read -p "Premi INVIO per continuare..." _
        return 1
    fi

    GW=$(json_field "$(termux-wifi-dhcpinfo 2>/dev/null)" gateway)

    echo ""
    echo "== Velocità connessione =="
    LS=$(json_field "$(termux-wifi-connectioninfo 2>/dev/null)" link_speed_mbps)
    [ -n "$LS" ] && echo "Velocità link wifi: $LS Mbit/s"
    echo "Test download/upload in corso (circa 15 secondi)..."
    DL=$(curl -s -o /dev/null -w '%{speed_download}' --connect-timeout 5 --max-time 8 "https://speed.cloudflare.com/__down?bytes=25000000")
    UL=$(head -c 5000000 /dev/zero | curl -s -o /dev/null -w '%{speed_upload}' --connect-timeout 5 --max-time 8 --data-binary @- "https://speed.cloudflare.com/__up")
    if ! awk -v s="${DL:-0}" 'BEGIN { exit !(s>0) }'; then
        DL=$(curl -s -o /dev/null -w '%{speed_download}' --connect-timeout 5 --max-time 8 "http://speedtest.tele2.net/10MB.zip")
    fi
    if ! awk -v s="${UL:-0}" 'BEGIN { exit !(s>0) }'; then
        UL=$(head -c 5000000 /dev/zero | curl -s -o /dev/null -w '%{speed_upload}' --connect-timeout 5 --max-time 8 --data-binary @- "http://speedtest.tele2.net/upload.php")
    fi
    if awk -v d="${DL:-0}" -v u="${UL:-0}" 'BEGIN { exit !(d>0 || u>0) }'; then
        awk -v d="${DL:-0}" -v u="${UL:-0}" 'BEGIN { printf "Download: %.1f Mbit/s | Upload: %.1f Mbit/s\n", d*8/1000000, u*8/1000000 }'
    else
        echo "Test di velocità non riuscito (server non raggiungibili)."
    fi

    while read -r IFACE MY_IP BITS; do
        echo ""
        echo "== Rete $IFACE: $MY_IP/$BITS =="

        if [ -n "$GW" ] && [ "${GW%.*}" = "${MY_IP%.*}" ]; then
            DNSOPT="--dns-servers $GW"
        else
            DNSOPT="--system-dns"
        fi

        echo "Scansione in corso..."
        RES=$(nmap -sn -T4 $DNSOPT -PS22,80,443,445,8080,62078 "$MY_IP/$BITS" -oG - </dev/null 2>/dev/null | awk '
            /Status: Up/ { n=$3; gsub(/[()]/,"",n); print $2, n }')

        echo ""
        printf "%-16s %s\n" "IP" "NOME / TIPO"
        echo "--------------------------------------------"

        COUNT=0
        while read -r IP NAME; do
            [ -z "$IP" ] && continue

            if [ "$IP" = "$MY_IP" ]; then
                NAME="questo telefono"
            else
                if [ -z "$NAME" ] && command -v dig >/dev/null 2>&1; then
                    NAME=$(dig +short +time=1 +tries=1 -p 5353 -x "$IP" @"$IP" 2>/dev/null | grep -v '^;' | head -n1 | sed 's/\.$//')
                fi

                if [ -z "$NAME" ]; then
                    PORTS=$(nmap -Pn -T4 --max-retries 1 --host-timeout 5s --open -p 22,80,443,445,554,631,5555,7000,8008,8009,9100,62078 "$IP" -oG - </dev/null 2>/dev/null | sed -n 's/.*Ports: //p')
                    TITLE=""
                    case "$PORTS" in
                        *80/open*)
                            TITLE=$(curl -s --max-time 2 "http://$IP/" 2>/dev/null | tr '\n' ' ' | sed -n 's/.*<[Tt][Ii][Tt][Ll][Ee][^>]*>\([^<]*\)<.*/\1/p' | sed 's/^ *//;s/ *$//' | head -c 40)
                            ;;
                    esac
                    HINT=""
                    case "$PORTS" in
                        *62078/open*) HINT="iPhone/iPad (Apple)" ;;
                        *8009/open*|*8008/open*) HINT="Chromecast / Android TV" ;;
                        *9100/open*|*631/open*) HINT="Stampante" ;;
                        *554/open*) HINT="Telecamera IP" ;;
                        *7000/open*) HINT="Apple TV / AirPlay" ;;
                        *5555/open*) HINT="Dispositivo Android (adb)" ;;
                        *445/open*) HINT="PC Windows / NAS" ;;
                        *22/open*) HINT="Dispositivo Linux (ssh)" ;;
                        *80/open*|*443/open*) HINT="Dispositivo con pagina web" ;;
                    esac
                    NAME="${TITLE:-$HINT}"
                fi

                if [ -n "$GW" ] && [ "$IP" = "$GW" ]; then
                    NAME="router${NAME:+ - $NAME}"
                fi
            fi

            printf "%-16s %s\n" "$IP" "${NAME:--}"
            COUNT=$((COUNT+1))
        done <<< "$RES"

        echo ""
        echo "Dispositivi trovati: $COUNT"
    done <<< "$NETS"

    echo ""
    read -p "Premi INVIO per continuare..." _
}
#endregion

#region share-funtion
share_setup() {
    local script_file
    script_file="$(readlink -f "${BASH_SOURCE[0]}")"
    mkdir -p "$HOME/bin"
    printf '#!/data/data/com.termux/files/usr/bin/bash\nexec bash %q --share "$1"\n' "$script_file" > "$HOME/bin/termux-url-opener"
    chmod +x "$HOME/bin/termux-url-opener"
}

share_screen() {
    clear
    cat <<'EOF'
/================================================\
\   ##### #   # ##### #######    @@@@@@  @    @  /
/      #  #   # #        #       @       @    @  \
\      #  #   #  ###     #       @@@@@@  @@@@@@  /
/      #  #   #     #    #            @  @    @  \
\  ####   ##### #####    #       @@@@@@  @    @  /
/                                                \
\====================<Pocket>====================/
EOF
    echo ""
    echo "shared_link:$SHARED_LINK"
    echo ""
    cat <<'EOF'
 ################################################
 |  1-yt-dlp             ||  2-null             |
 |  3-null               ||  4-null             |
 |  5-null               ||  6-null             |
 |  7-null               ||  8-null             |
 |  9-null               || 10-null             |
 ################################################
EOF
    echo ""
}

share_function1() {
    utility1 "$SHARED_LINK"
}

share_menu() {
    SHARED_LINK="$1"
    while true; do
        share_screen
        read -p "scegli una funzione: " scelta

        if [ "$scelta" = "exit" ]; then
            clear
            exit 0
        fi

        if [[ "$scelta" =~ ^[0-9]+$ ]] && declare -F "share_function$scelta" >/dev/null; then
            "share_function$scelta"
            return 0
        fi
    done
}

share_setup

if [ "$1" = "--share" ]; then
    share_menu "$2"
fi
#endregion

#region menu
while true; do
    clear
    cat <<'EOF'
/================================================\
\   ##### #   # ##### #######    @@@@@@  @    @  /
/      #  #   # #        #       @       @    @  \
\      #  #   #  ###     #       @@@@@@  @@@@@@  /
/      #  #   #     #    #            @  @    @  \
\  ####   ##### #####    #       @@@@@@  @    @  /
/                                                \
\====================<Pocket>====================/

 ################################################
 |  1-yt-dlp             ||  2-neofetch+        |
 |  3-netscan            ||  4-null             |
 |  5-null               ||  6-null             |
 |  7-null               ||  8-null             |
 |  9-null               || 10-null             |
 ################################################

EOF
    read -p "scegli una funzione: " scelta

    if [ "$scelta" = "exit" ]; then
        clear
        exit 0
    fi

    if [ "$scelta" = "xdedit" ]; then
        SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
        nano "$SCRIPT_FILE"
        exec bash "$SCRIPT_FILE"
    fi

    if [ "$scelta" = "xdreload" ]; then
        exec bash "$(readlink -f "${BASH_SOURCE[0]}")"
    fi

    if [ "$scelta" = "xdupate" ] || [ "$scelta" = "xdupdate" ]; then
        SCRIPT_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
        echo "Scarico l'ultima versione da GitHub..."
        if curl -fsSL "https://raw.githubusercontent.com/gaetron/just-sh-poket/main/%28poket%29just.sh" -o "$SCRIPT_FILE.tmp" \
            && head -n1 "$SCRIPT_FILE.tmp" | grep -q '^#!' \
            && bash -n "$SCRIPT_FILE.tmp"; then
            cp "$SCRIPT_FILE" "$SCRIPT_FILE.bak"
            mv "$SCRIPT_FILE.tmp" "$SCRIPT_FILE"
            exec bash "$SCRIPT_FILE"
        else
            rm -f "$SCRIPT_FILE.tmp"
            echo "Aggiornamento non riuscito: controlla la connessione. Script invariato."
            sleep 2
        fi
    fi
    
    if [ "$scelta" = "xdinfo" ]; then

        URL_INFO="https://docs.google.com/spreadsheets/d/1p2pwSReLNOqWwvcm5b43FTDhTk3uoyYco9qIMYJxy4c/edit?usp=sharing"

        read -p "Vuoi aprire il link direttamente? [y/n]: " info
        
        if [ "${info,,}" = "y" ]; then
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$URL_INFO" >/dev/null 2>&1 &
            else
                echo "$URL_INFO"
            fi
        else
            echo "$URL_INFO"
            read -p "Premi INVIO per continuare..." _
        fi
    fi


    if [ -n "$scelta" ] && [ "$scelta" -ge 1 ] 2>/dev/null && [ "$scelta" -le 10 ] 2>/dev/null; then
        "utility$scelta"
    fi
done
#endregion
