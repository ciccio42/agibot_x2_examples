# Configurazione lato computer

Questa guida raccoglie le operazioni da eseguire sul PC Windows e nella distribuzione Ubuntu su WSL2.

## 1. Windows – routing verso la rete interna

### Route persistente

PowerShell **come amministratore**:

```powershell
route delete 10.0.1.0
route -p add 10.0.1.0 mask 255.255.255.0 192.168.88.88
```

(In modalità mirrored la WSL eredita le route di Windows.)

### Versione temporanea (solo per test, sparisce al riavvio)

```powershell
# Windows
route add 10.0.1.0 mask 255.255.255.0 192.168.88.88
```

---

## 2. WSL2

### 2a. Prerequisiti Windows

`C:\Users\<utente>\.wslconfig`:

```ini
[wsl2]
networkingMode=mirrored
```

Poi `wsl --shutdown`. In caso di problemi di firewall (PowerShell admin):

```powershell
New-NetFirewallRule -DisplayName "ROS2 DDS" -Direction Inbound -Protocol UDP -LocalPort 7400-7700 -Action Allow
Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow
```

e impostare la rete WiFi del robot come **Privata**.

### 2b. Profilo DDS `~/agibot_x2_examples/wsl/agi_dds.xml`

Il file del profilo DDS è già fornito e preconfigurato nello script Bash usato per predisporre WSL all'utilizzo con il robot. Se è stato eseguito lo script di setup, non è necessario creare il file.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<dds>
  <profiles xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
    <transport_descriptors>
      <transport_descriptor>
        <transport_id>UDPv4_transport</transport_id>
        <type>UDPv4</type>
        <sendBufferSize>20971520</sendBufferSize>
        <receiveBufferSize>20971520</receiveBufferSize>
        <maxInitialPeersRange>120</maxInitialPeersRange>
      </transport_descriptor>
      <transport_descriptor>
        <transport_id>SHM_transport</transport_id>
        <type>SHM</type>
        <segment_size>20971520</segment_size>
        <port_queue_capacity>10240</port_queue_capacity>
      </transport_descriptor>
    </transport_descriptors>
    <participant profile_name="participant_profile" is_default_profile="true">
      <rtps>
        <useBuiltinTransports>false</useBuiltinTransports>
        <userTransports>
          <transport_id>SHM_transport</transport_id>
          <transport_id>UDPv4_transport</transport_id>
        </userTransports>
        <builtin>
          <initialPeersList>
            <locator><udpv4><address>192.168.88.88</address></udpv4></locator>
            <locator><udpv4><address>10.0.1.41</address></udpv4></locator>
            <locator><udpv4><address>10.0.1.42</address></udpv4></locator>
          </initialPeersList>
        </builtin>
      </rtps>
    </participant>
  </profiles>
</dds>
```

Note:

- `initialPeersList`: discovery unicast, perché il multicast non passa né sul WiFi né attraverso il routing.
- `maxInitialPeersRange`: la WSL contatta le porte di discovery di tutti i nodi (7410 + 2×ID), non solo dei primi 4.

### 2c. Variabili d'ambiente (in fondo a `~/.bashrc`)

Le variabili d'ambiente necessarie sono già inserite nello stesso script Bash fornito per predisporre WSL all'utilizzo con il robot. Se è stato eseguito lo script di setup, non è necessario aggiungerle manualmente in `~/.bashrc`; riportiamo comunque qui sotto i valori che dovrebbero essere presenti, per poterli verificare.

```bash
source /opt/ros/humble/setup.bash
source ~/agibot_ws/install/setup.bash   # workspace con aimdk_msgs compilato
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export FASTRTPS_DEFAULT_PROFILES_FILE=~/agibot_x2_examples/wsl/agi_dds.xml
export ROS_DOMAIN_ID=0
export ROS_LOCALHOST_ONLY=0
```

Non impostare `FASTRTPS_DEFAULT_PROFILES_FILES` (al plurale), `ROS_DISCOVERY_SERVER`, `ROS_SUPER_CLIENT` o `ROS_LOCALHOST_ONLY=1`.

Dopo ogni modifica alla configurazione DDS:

```bash
ros2 daemon stop && ros2 topic list
```

---

## 3. Verifica completa

Nella WSL:

```bash
ping 10.0.1.41
ros2 topic list
ros2 service list | grep -i tts
```

Diagnostica del traffico DDS nella WSL:

```bash
sudo tcpdump -ni any udp portrange 7400-7700
```

---

## 4. Esempi di comando ROS 2

### TTS (servizio)

```bash
ros2 service call /aimdk_5Fmsgs/srv/PlayTts aimdk_msgs/srv/PlayTts "{tts_req: {text: 'Hello, I am AgiBot X2', priority_weight: 0, priority_level: {value: 6}}}"
```

Stato della riproduzione: topic `/interaction/tts_status`.

---

## Avvertenze lato computer

- **Banda**: sul WiFi preferire i topic `/compressed` o `/h265` delle camere.
