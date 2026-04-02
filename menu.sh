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
    echo " [4] Backup Database (Docker)     (backup-db.sh)"
    echo " [5] Backup Database (Remote)     (backup-live.sh)"
    echo " [6] Restore Database             (restore-db.sh)"
    echo " [7] Sync Live to Local           (sync-db.sh)"
    echo " [8] Remove Database Stack        (remove-db.sh)"
    echo " [0] Exit"
    echo "--------------------------------------------------------------------------------"
    read -p " Pilih opsi [0-8]: " OPTION

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
            read -p "Nama Project: " PNAME
            read -p "Tipe (postgres/mongo): " TNAME
            ./backup-db.sh "$PNAME" "$TNAME"
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        5)
            echo "Format: <project> <type> <host> <port> <user> <db>"
            read -p "Masukkan semua parameter (pisahkan spasi): " PARAMS
            ./backup-live.sh $PARAMS
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        6)
            read -p "Nama Project: " PNAME
            read -p "Tipe (postgres/mongo): " TNAME
            ./restore-db.sh "$PNAME" "$TNAME"
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        7)
            read -p "Nama Project: " PNAME
            read -p "Tipe (postgres/mongo): " TNAME
            ./sync-db.sh "$PNAME" "$TNAME"
            read -p "Tekan [Enter] untuk kembali..."
            ;;
        8)
            read -p "Nama Database yang akan dihapus: " DNAME
            read -p "Hapus folder data juga? (y/n): " CONFIRM
            if [ "$CONFIRM" = "y" ]; then
                ./remove-db.sh "$DNAME" --delete-data
            else
                ./remove-db.sh "$DNAME"
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