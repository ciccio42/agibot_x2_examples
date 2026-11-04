# Configurazione lato robot

Questa guida raccoglie le operazioni da eseguire sulle schede del robot AgiBot X2 Ultra.

## Architettura di rete del robot

| Scheda | Ruolo | IP rete interna (`develop0`) | IP WiFi (`hotspot0`) |
|---|---|---|---|
| soc0 | Main PC (`agi@agi`): motion control, IMU, PMU… | 10.0.1.40 | 192.168.88.88 |
| soc1 | Orin: camere, percezione, audio/TTS… | 10.0.1.41 | – |
| soc2 | altri nodi | 10.0.1.42 | – |
| PC remoto | WSL2 (mirrored) | – | 192.168.88.x (es. 192.168.88.42) |

I nodi del robot usano Fast DDS con il profilo
`/agibot/software/entry/cfg/ros_dds_configuration.xml`
(**non** quello in `~/.aima/env/`, che viene letto solo dalla shell SSH).

Per verificare quale profilo usa un nodo:

```bash
sudo cat /proc/$(pgrep -f aima-mc-app-main | head -1)/environ | tr '\\0' '\\n' | grep -E 'FAST|ROS|RMW'
```

---

## 1. Profilo DDS su soc0 (permanente)

Sul main PC (`ssh agi@192.168.88.88`):

```bash
sudo cp /agibot/software/entry/cfg/ros_dds_configuration.xml \\
        /agibot/software/entry/cfg/ros_dds_configuration.xml.bak
sudo nano /agibot/software/entry/cfg/ros_dds_configuration.xml
```

Aggiungere l'IP WiFi alla whitelist, mantenendo quello interno:

```xml
<interfaceWhiteList>
  <address>10.0.1.40</address>
  <address>192.168.88.88</address>
</interfaceWhiteList>
```

Riavviare i servizi (**robot in sicurezza: sdraiato o appeso**):

```bash
sudo systemctl restart agibot_software.service   # oppure: sudo reboot
```

Verifica (deve dare circa 80, non 5):

```bash
sudo ss -ulpn | grep 192.168.88.88 | wc -l
```

---

## 2. Routing WiFi ↔ rete interna (permanente)

Serve per raggiungere i nodi su soc1 e soc2, che non hanno un'interfaccia WiFi.

Verificare prima che `/etc` sia scrivibile su ogni scheda:

```bash
sudo touch /etc/systemd/system/.test && sudo rm /etc/systemd/system/.test && echo OK
```

### 2a. soc0 – inoltro tra hotspot0 e develop0

```bash
sudo tee /etc/systemd/system/wifi-forward.service >/dev/null <<'EOF'
[Unit]
Description=Inoltro hotspot0 <-> develop0 per accesso DDS da WiFi
After=network-online.target agibot-runtime_start_ap.service agibot_software.service
Wants=network-online.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/sysctl -w net.ipv4.ip_forward=1
ExecStart=/bin/sh -c 'iptables -C FORWARD -i hotspot0 -o develop0 -j ACCEPT 2>/dev/null || iptables -I FORWARD -i hotspot0 -o develop0 -j ACCEPT'
ExecStart=/bin/sh -c 'iptables -C FORWARD -i develop0 -o hotspot0 -j ACCEPT 2>/dev/null || iptables -I FORWARD -i develop0 -o hotspot0 -j ACCEPT'
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now wifi-forward.service
```

### 2b. soc1 (10.0.1.41) e soc2 (10.0.1.42) – route di ritorno

Su **ciascuna** delle due schede:

```bash
sudo tee /etc/systemd/system/wifi-route.service >/dev/null <<'EOF'
[Unit]
Description=Route verso la rete WiFi dell'hotspot tramite soc0
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip route replace 192.168.88.0/24 via 10.0.1.40
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now wifi-route.service
```

### Versione temporanea (solo per test, sparisce al riavvio)

Eseguire sul robot:

```bash
# soc0
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -I FORWARD -i hotspot0 -o develop0 -j ACCEPT
sudo iptables -I FORWARD -i develop0 -o hotspot0 -j ACCEPT
# soc1 / soc2
sudo ip route add 192.168.88.0/24 via 10.0.1.40
```

---

## 3. Verifiche lato robot

### Verifica completa

```bash
# soc0
cat /proc/sys/net/ipv4/ip_forward              # 1
sudo iptables -L FORWARD -n | head
sudo ss -ulpn | grep 192.168.88.88 | wc -l     # circa 80
# soc1 / soc2
ip route | grep 192.168.88
```

### Diagnostica del traffico DDS

Sul robot:

```bash
sudo tcpdump -ni hotspot0 host 192.168.88.42 and udp
```

---

## Avvertenze lato robot

- **OTA**: un aggiornamento firmware può ripristinare `ros_dds_configuration.xml` e i servizi in `/etc`. Conservare questo file e riapplicare.
- **Sicurezza**: con il routing attivo, chiunque sia collegato all'hotspot raggiunge la rete interna del robot. Cambiare la password del WiFi o disattivare i servizi quando il robot esce dal laboratorio:

  ```bash
  sudo systemctl disable --now wifi-forward.service   # soc0
  sudo systemctl disable --now wifi-route.service     # soc1 / soc2
  ```

- **Ripristino DDS**: `sudo cp ros_dds_configuration.xml.bak ros_dds_configuration.xml` nella cartella `/agibot/software/entry/cfg/`.
