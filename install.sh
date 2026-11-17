#!/data/data/com.termux/files/usr/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear
echo -e "${GREEN}"
cat << "EOF"
  ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
 ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
 ██║  ███╗███████║██║   ██║███████╗   ██║   
 ██║   ██║██╔══██║██║   ██║╚════██║   ██║   
 ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   
  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   
EOF
echo -e "${WHITE}          W E B   S Y S T E M${NC}"
echo -e "${PURPLE}==========================================${NC}"
sleep 2

echo -e "\n${YELLOW}[*] Verificando dependências do sistema...${NC}"

if ! command -v adb &> /dev/null || ! command -v curl &> /dev/null || ! command -v python &> /dev/null; then
    echo -e "${YELLOW}[*] Instalando pacotes necessários (android-tools, curl, python)...${NC}"
    pkg update -y &> /dev/null
    pkg install android-tools curl python -y &> /dev/null
    echo -e "${GREEN}[+] Dependências instaladas com sucesso.${NC}"
else
    echo -e "${GREEN}[+] Dependências OK.${NC}"
fi

echo -e "\n${YELLOW}[*] Instalando interface de controle...${NC}"

cat > /data/data/com.termux/files/usr/bin/ghost << 'GHOST_EOF'
#!/data/data/com.termux/files/usr/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear
echo -e "${PURPLE}==========================================${NC}"
echo -e "${WHITE}            AUTENTICAÇÃO GHOST            ${NC}"
echo -e "${PURPLE}==========================================${NC}\n"

ADB_STATE=$(adb get-state 2>/dev/null | tr -d '\r\n')

if [ "$ADB_STATE" == "device" ]; then
    echo -e "${GREEN}[+] Sistema ADB já conectado.${NC}"
    sleep 1
else
    echo -e "${WHITE}Etapa 1: Conexão com o Dispositivo${NC}"
    echo -e "${YELLOW}O ADB não está conectado. Vamos configurar agora.${NC}\n"
    
    echo -n "IP:PORTA de PAREAMENTO: "
    read -r PAIR_ADDR < /dev/tty
    
    echo -n "Código de 6 dígitos: "
    read -r PAIR_CODE < /dev/tty
    
    echo -e "\n${YELLOW}[*] Pareando dispositivos...${NC}"
    adb pair $PAIR_ADDR $PAIR_CODE
    
    echo -n "IP:PORTA de CONEXÃO: "
    read -r CONN_ADDR < /dev/tty
    
    echo -e "${YELLOW}[*] Estabelecendo conexão segura...${NC}"
    adb connect $CONN_ADDR
    sleep 1
    
    if [ "$(adb get-state 2>/dev/null | tr -d '\r\n')" != "device" ]; then
        echo -e "${RED}[!] Falha na conexão. Verifique os dados e tente novamente.${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}[*] Criando túnel ADB...${NC}"
adb forward tcp:7755 tcp:7755

HWID=$(adb shell settings get secure android_id 2>/dev/null | tr -d '\r\n')
if [ -z "$HWID" ] || [ "$HWID" == "null" ]; then
    echo -e "${RED}[!] Falha ao obter o Hardware ID. Verifique o ADB.${NC}"
    exit 1
fi

clear
echo -e "${PURPLE}==========================================${NC}"
echo -e "${WHITE}             VALIDAÇÃO DE LICENÇA         ${NC}"
echo -e "${PURPLE}==========================================${NC}\n"

echo -n "Insira sua Key de Acesso: "
read -r USER_KEY < /dev/tty

echo -e "\n${YELLOW}[*] Comunicando com o servidor...${NC}"

K_API=$(echo "aHR0cHM6Ly9nZXJhZG9yLWtleXMuZGUuZGVwbGV4by5jb20vYXBpL3ZhbGlkYXRl" | base64 -d)
K_SLG=$(echo "c3RpcmxheC1tb2R6LW0xbngtb2ZpY2lhbA==" | base64 -d)
K_VER=$(echo "Mi4w" | base64 -d)

RESPONSE=$(curl -s -X POST "$K_API" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"key\":\"$USER_KEY\",\"hwid\":\"$HWID\",\"appSlug\":\"$K_SLG\",\"appVersion\":\"$K_VER\"}")

SUCCESS=$(echo "$RESPONSE" | grep -o '"success":[^,]*' | cut -d':' -f2 | tr -d ' ')
STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
EXPIRES_AT=$(echo "$RESPONSE" | grep -o '"expiresAt":[^,]*' | cut -d':' -f2 | tr -d ' ')

if [ "$SUCCESS" != "true" ] || [ "$STATUS" != "active" ]; then
    echo -e "${RED}[!] Acesso Negado. Key inválida ou expirada.${NC}"
    sleep 3
    exit 1
fi

NOW=$(date +%s)
EXPIRES_SEC=$((EXPIRES_AT / 1000))
DIFF=$((EXPIRES_SEC - NOW))

if [ $DIFF -gt 0 ]; then
    DIAS=$((DIFF / 86400))
    HORAS=$(((DIFF % 86400) / 3600))
    echo -e "${GREEN}[+] Acesso Autorizado!${NC}"
    echo -e "${GREEN}[+] Expira em: ${DIAS} dias e ${HORAS} horas.${NC}"
    sleep 2
else
    echo -e "${RED}[!] Licença expirada.${NC}"
    sleep 3
    exit 1
fi

clear
echo -e "${PURPLE}==========================================${NC}"
echo -e "${WHITE}             INJEÇÃO DO MÓDULO            ${NC}"
echo -e "${PURPLE}==========================================${NC}\n"
echo -e "${WHITE}Abra o app Amazon no celular alvo, clique em INJETAR e feche o app."
echo -e "Após abrir o Free Fire, retorne a esta tela.${NC}\n"
echo -n "Módulo injetado e FF aberto? (s/n): "
read -r INJETADO < /dev/tty

if [ "$INJETADO" != "s" ]; then
    echo -e "${RED}[!] Operação cancelada.${NC}"
    exit 1
fi

# --- INÍCIO DO SERVIDOR WEB ---
clear
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       PAINEL WEB INICIADO COM SUCESSO    ${NC}"
echo -e "${GREEN}==========================================${NC}\n"
echo -e "${WHITE}Abra o navegador do seu celular e acesse:${NC}"
echo -e "${CYAN}http://127.0.0.1:8080${NC}\n"
echo -e "${YELLOW}Mantenha o Termux aberto em segundo plano.${NC}"
echo -e "${YELLOW}Para desligar o painel, feche o Termux.${NC}\n"

# Tenta abrir o navegador automaticamente
am start -a android.intent.action.VIEW -d http://127.0.0.1:8080 > /dev/null 2>&1

cat > /data/data/com.termux/files/usr/share/ghost_panel.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GHOST REMOTE</title>
    <style>
        body { background-color: #0d0d0d; color: #fff; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; }
        h1 { text-align: center; color: #00ffcc; text-shadow: 0 0 10px #00ffcc; margin-bottom: 5px; }
        p.sub { text-align: center; color: #888; margin-top: 0; margin-bottom: 20px; }
        .container { max-width: 600px; margin: 0 auto; }
        .card { background-color: #1a1a1a; border: 1px solid #333; border-radius: 10px; padding: 15px; margin-bottom: 15px; }
        .card h2 { margin-top: 0; font-size: 16px; color: #00ffcc; border-bottom: 1px solid #333; padding-bottom: 10px; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
        button { background-color: #222; color: #fff; border: 1px solid #444; padding: 15px; border-radius: 8px; font-size: 14px; font-weight: bold; cursor: pointer; transition: 0.2s; text-align: left; }
        button:hover { background-color: #333; }
        button.active { background-color: #00ffcc; color: #000; border-color: #00ffcc; box-shadow: 0 0 10px #00ffcc; }
        .danger { border-color: #ff3333; color: #ff3333; }
        .danger.active { background-color: #ff3333; color: #fff; box-shadow: 0 0 10px #ff3333; }
        #toast { position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%); background: #00ffcc; color: #000; padding: 10px 20px; border-radius: 20px; font-weight: bold; opacity: 0; transition: 0.3s; pointer-events: none; }
    </style>
</head>
<body>
    <div class="container">
        <h1>GHOST REMOTE</h1>
        <p class="sub">Painel de Controle Web</p>

        <div class="card">
            <h2>AIMBOTS</h2>
            <div class="grid">
                <button onclick="toggle(this, 'item1')">HS Cabeça</button>
                <button onclick="toggle(this, 'item5')">Drag Neck</button>
            </div>
        </div>

        <div class="card">
            <h2>ESP (VISÃO)</h2>
            <div class="grid">
                <button onclick="toggle(this, 'item3')">ESP Box</button>
                <button onclick="toggle(this, 'item2')">ESP Linha</button>
                <button onclick="toggle(this, 'item6')">ESP Nickname</button>
                <button onclick="toggle(this, 'item7')">ESP Vida</button>
                <button onclick="toggle(this, 'item9')">Esqueleto</button>
                <button onclick="toggle(this, 'item10')">Distância</button>
            </div>
        </div>

        <div class="card">
            <h2>OUTRAS FUNÇÕES</h2>
            <div class="grid">
                <button onclick="toggle(this, 'item11')">FOV Perfeito</button>
                <button onclick="toggle(this, 'item14')">Fast Switch</button>
                <button onclick="toggle(this, 'item15')">No Recoil</button>
            </div>
        </div>
        
        <div class="card">
            <h2>ZONA DE PERIGO</h2>
            <button class="danger" style="width: 100%; text-align: center;" onclick="bypass(this)">DESCONECTAR E LIMPAR</button>
        </div>
    </div>

    <div id="toast">Comando enviado!</div>

    <script>
        function showToast(msg) {
            const toast = document.getElementById('toast');
            toast.innerText = msg;
            toast.style.opacity = '1';
            setTimeout(() => { toast.style.opacity = '0'; }, 2000);
        }

        function toggle(btn, endpoint) {
            const isActive = btn.classList.contains('active');
            
            if (isActive) {
                fetch('/off?item=' + endpoint).then(() => {
                    btn.classList.remove('active');
                    showToast('Desativado');
                });
            } else {
                fetch('/on?item=' + endpoint).then(() => {
                    btn.classList.add('active');
                    showToast('Ativado');
                });
            }
        }

        function bypass(btn) {
            if(confirm("Isso vai desligar tudo e desinstalar o app Amazon. Continuar?")) {
                fetch('/bypass').then(() => {
                    showToast('Bypass concluído!');
                    setTimeout(() => { window.close(); }, 2000);
                });
            }
        }
    </script>
</body>
</html>
HTML_EOF

cat > /data/data/com.termux/files/usr/share/server.py << 'PY_EOF'
import http.server
import socketserver
import subprocess
import urllib.parse

PORT = 8080

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        
        if parsed.path == '/':
            self.path = '/data/data/com.termux/files/usr/share/ghost_panel.html'
            return http.server.SimpleHTTPRequestHandler.do_GET(self)
            
        elif parsed.path == '/on':
            item = query.get('item', [''])[0]
            subprocess.run(['curl', '-s', '-H', 'Connection: close', '--max-time', '2', f'http://127.0.0.1:7755/{item}'])
            self.send_response(200)
            self.end_headers()
            
        elif parsed.path == '/off':
            item = query.get('item', [''])[0]
            subprocess.run(['curl', '-s', '-H', 'Connection: close', '--max-time', '2', f'http://127.0.0.1:7755/{item}/desativar'])
            self.send_response(200)
            self.end_headers()
            
        elif parsed.path == '/bypass':
            for i in [1,2,3,5,6,7,9,10,11,14,15]:
                subprocess.run(['curl', '-s', '-H', 'Connection: close', '--max-time', '1', f'http://127.0.0.1:7755/item{i}/desativar'])
            subprocess.run(['adb', 'shell', 'am', 'force-stop', 'com.dts.freefireth'])
            files = ["Assembly-CSharp-patch.bytes","xyz.guard","localConfig.json","auth.txt","ffrtc_log.txt","ShaderStripSettings","reportnew.db"]
            for f in files:
                subprocess.run(['adb', 'shell', 'rm', '-f', f'/sdcard/Android/data/com.dts.freefireth/files/{f}'])
            subprocess.run(['adb', 'shell', 'am', 'force-stop', 'com.zyron'])
            subprocess.run(['adb', 'shell', 'pm', 'uninstall', 'com.zyron'])
            self.send_response(200)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()
PY_EOF

python /data/data/com.termux/files/usr/share/server.py
GHOST_EOF

chmod +x /data/data/com.termux/files/usr/bin/ghost
ghost
ENDSCRIPT
chmod +x install.sh
./install.sh
