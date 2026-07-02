#!/bin/bash

# --- BANNER ASCII HARDCODED ---
function show_banner() {
    clear
    cat << "EOF"
 ██▓███   ▄▄▄       █    ██   ██████      ██████  ▄▄▄       ██▓  ▄▄▄█████▓ ▒█████  
▓██░  ██▒▒████▄     ██  ▓██▒▒██    ▒    ▒██    ▒ ▒████▄    ▓██▒  ▓  ██▒ ▓▒▒██▒  ██▒
▓██░ ██▓▒▒██  ▀█▄  ▓██  ▒██░░ ▓██▄      ░ ▓██▄   ▒██  ▀█▄  ▒██░  ▒ ▓██░ ▒░▒██░  ██▒
▒██▄█▓▒ ▒░██▄▄▄▄██ ▓▓█  ░██░  ▒   ██▒     ▒   ██▒░██▄▄▄▄██ ▒██░  ░ ▓██▓ ░ ▒██   ██░
▒██▒ ░  ░ ▓█   ▓██▒▒▒█████▓ ▒██████▒▒   ▒██████▒▒ ▓█   ▓██▒░██████▒▒██▒ ░ ░ ████▓▒░
▒▓▒░ ░  ░ ▒▒   ▓▒█░░▒▓▒ ▒ ▒ ▒ ▒▓▒ ▒ ░   ▒ ▒▓▒ ▒ ░ ▒▒   ▓▒█░░ ▒░▓  ░▒ ░░   ░ ▒░▒░▒░ 
░▒ ░       ▒   ▒▒ ░░░▒░ ░ ░ ░ ░▒  ░ ░   ░ ░▒  ░ ░  ▒   ▒▒ ░░ ░ ▒  ░  ░      ░ ▒ ▒░ 
░░         ░   ▒    ░░░ ░ ░ ░  ░  ░     ░  ░  ░    ░   ▒     ░ ░   ░      ░ ░ ░ ▒  
               ░  ░   ░           ░           ░        ░  ░    ░  ░           ░ ░  
EOF
    echo "--------------------------------------------------------------------------------"
    echo "                   DOCKER DATABASE MANAGEMENT DASHBOARD"
    echo "--------------------------------------------------------------------------------"
}

while true; do
    show_banner
    echo " [1] List Running Databases       (list-db.sh)"
    echo " [2] Create New Database Stack    (create-db.sh)"
    echo " [3] Start Existing Stack         (start-db.sh)"
    echo " [4] Stop Existing Stack          (stop-db.sh)"
    echo " [5] Backup Database (Docker)     (backup-db.sh)"
    echo " [6] Backup Database (Remote)     (backup-live.sh)"
    echo " [7] Restore Database             (restore-db.sh)"
    echo " [8] Sync Live to Local           (sync-db.sh)"
    echo " [9] Remove Database Stack        (remove-db.sh)"
    echo " [10] Restore to Remote (URI)    (restore-uri.sh)"
    echo " [0] Exit"
    echo "--------------------------------------------------------------------------------"
    read -p " Pilih opsi [0-10]: " OPTION

    case $OPTION in
        1)
            ./list-db.sh
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        2)
            read -p "Nama Database Baru: " DNAME
            ./create-db.sh "$DNAME"
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        3)
            read -p "Nama Project yang ingin dijalankan: " DNAME
            ./start-db.sh "$DNAME"
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        4)
            read -p "Nama Project yang ingin dihentikan: " DNAME
            ./stop-db.sh "$DNAME"
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        5)
            read -p "Nama Project: " PNAME
            read -p "Tipe (postgres/mongo): " TNAME
            ./backup-db.sh "$PNAME" "$TNAME"
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        6)
            echo "Format: <project> <type> <host> <port> <user> <db>"
            read -p "Masukkan semua parameter (pisahkan spasi): " PARAMS
            ./backup-live.sh $PARAMS
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        7)
            read -p "Nama Project: " PNAME
            read -p "Tipe (postgres/mongo): " TNAME
            ./restore-db.sh "$PNAME" "$TNAME"
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        8)
            read -p "Nama Project: " PNAME
            read -p "Tipe (postgres/mongo): " TNAME
            ./sync-db.sh "$PNAME" "$TNAME"
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        9)
            read -p "Nama Database yang akan dihapus: " DNAME
            read -p "Hapus folder data juga? (y/n): " CONFIRM
            if [ "$CONFIRM" = "y" ]; then
                ./remove-db.sh "$DNAME" --delete-data
            else
                ./remove-db.sh "$DNAME"
            fi
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        10)
            read -p "Nama Project: " PNAME
            read -p "Tipe (postgres/mongo): " TNAME
            read -p "Gunakan SSH Tunnel? (y/N): " USE_SSH
            
            if [[ "$USE_SSH" =~ ^[Yy]$ ]]; then
                read -p "SSH User@Host (e.g. root@1.2.3.4): " SSH_CONN
                read -p "Private Key Path (optional, tekan Enter jika tdk ada): " SSH_KEY
                read -p "Remote DB Host [localhost]: " R_HOST
                R_HOST=${R_HOST:-localhost}
                read -p "Remote DB Port [5432]: " R_PORT
                R_PORT=${R_PORT:-5432}
                read -p "Local Tunnel Port [5433]: " L_PORT
                L_PORT=${L_PORT:-5433}
                
                echo "🚀 Membuka SSH Tunnel ($L_PORT -> $R_HOST:$R_PORT)..."
                
                # Membangun perintah SSH
                SSH_CMD="ssh -f -N -M -o ExitOnForwardFailure=yes"
                if [ -n "$SSH_KEY" ]; then
                    SSH_CMD="$SSH_CMD -i $SSH_KEY"
                fi
                
                # Menggunakan ControlMaster agar mudah di-close nanti
                SOCKET="/tmp/ssh_tunnel_$(date +%s).sock"
                $SSH_CMD -S "$SOCKET" -L "$L_PORT:$R_HOST:$R_PORT" "$SSH_CONN" 2>/tmp/ssh_err.txt
                
                if [ $? -eq 0 ]; then
                    echo "✅ Tunnel aktif di localhost:$L_PORT"
                    echo "💡 Tips: Masukkan localhost:$L_PORT pada URI di bawah."
                else
                    echo "❌ Gagal membuka SSH Tunnel."
                    [ -f /tmp/ssh_err.txt ] && cat /tmp/ssh_err.txt
                    USE_SSH="n"
                fi
            fi

            if [ "$TNAME" == "postgres" ]; then
                # Jika pakai SSH Tunnel, default host adalah localhost dan port adalah L_PORT
                DEFAULT_HOST="localhost"
                DEFAULT_PORT="5432"
                if [[ "$USE_SSH" =~ ^[Yy]$ ]]; then
                    DEFAULT_PORT="$L_PORT"
                fi

                read -p "Remote Host [$DEFAULT_HOST]: " R_HOST_DB
                R_HOST_DB=${R_HOST_DB:-$DEFAULT_HOST}
                
                read -p "Remote Port [$DEFAULT_PORT]: " R_PORT_DB
                R_PORT_DB=${R_PORT_DB:-$DEFAULT_PORT}
                
                read -p "Remote User: " R_USER_DB
                read -s -p "Remote Password: " R_PASS_DB
                echo ""
                read -p "Remote Database Name: " R_NAME_DB
                
                export PGPASSWORD="$R_PASS_DB"
                URI="postgresql://$R_USER_DB@$R_HOST_DB:$R_PORT_DB/$R_NAME_DB"
            else
                echo "Contoh URI Mongo: mongodb+srv://user:pass@host/dbname"
                read -p "Connection URI: " URI
            fi
            
            ./restore-uri.sh "$PNAME" "$TNAME" "$URI"
            
            # Unset password setelah selesai demi keamanan
            unset PGPASSWORD
            
            if [[ "$USE_SSH" =~ ^[Yy]$ ]]; then
                echo "🛑 Menutup SSH Tunnel..."
                ssh -S "$SOCKET" -O exit "$SSH_CONN" 2>/dev/null
                rm -f "$SOCKET"
            fi
            
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        0)
            echo "Keluar... Sampai jumpa!"
            exit 0
            ;;
        *)
            echo "Opsi tidak valid!"
            sleep 1
            ;;
    esac
done