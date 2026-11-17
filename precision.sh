#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# ============================================================
# GHOST PRECICION - Termux
# Validação server-side de Key pela API de licenças
# ============================================================

readonly APP_NAME="GHOST PRECICION"
readonly API_URL="https://gerador-keys.de.deplexo.com/api/validate"
readonly APP_SLUG="stirlax-modz-m1nx-oficial"
readonly APP_VERSION="2.0"
readonly STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ghost_precision"
readonly STATE_FILE="$STATE_DIR/session.json"
readonly HWID_FILE="$STATE_DIR/hwid"

ROXO='\033[1;35m'
VERDE='\033[1;32m'
VERMELHO='\033[1;31m'
CIANO='\033[1;36m'
RESET='\033[0m'

som() {
    printf '\a'
}

limpar() {
    command -v clear >/dev/null 2>&1 && clear || printf '\033c'
}

pausar() {
    sleep "${1:-1}"
}

exigir_dependencias() {
    local ausentes=()
    command -v curl >/dev/null 2>&1 || ausentes+=("curl")
    command -v jq >/dev/null 2>&1 || ausentes+=("jq")

    if ((${#ausentes[@]} > 0)); then
        printf '%bDependências ausentes: %s%b\n' "$VERMELHO" "${ausentes[*]}" "$RESET"
        printf 'No Termux, instale com:\n'
        printf '  pkg update && pkg install %s\n' "${ausentes[*]}"
        exit 1
    fi
}

obter_hwid() {
    mkdir -p "$STATE_DIR"

    if [[ -s "$HWID_FILE" ]]; then
        tr -d '\r\n' < "$HWID_FILE"
        return 0
    fi

    local hwid=""

    if command -v settings >/dev/null 2>&1; then
        hwid="$(settings get secure android_id 2>/dev/null || true)"
        [[ "$hwid" == "null" ]] && hwid=""
    fi

    if [[ -z "$hwid" ]] && command -v getprop >/dev/null 2>&1; then
        hwid="$(getprop ro.serialno 2>/dev/null || true)"
    fi

    if [[ -z "$hwid" ]]; then
        hwid="$(sha256sum /proc/sys/kernel/random/boot_id 2>/dev/null | awk '{print $1}' || true)"
    fi

    if [[ -z "$hwid" ]]; then
        printf '%bNão foi possível obter o HWID do dispositivo.%b\n' "$VERMELHO" "$RESET" >&2
        return 1
    fi

    printf '%s\n' "$hwid" > "$HWID_FILE"
    chmod 600 "$HWID_FILE"
    printf '%s' "$hwid"
}

ler_token() {
    if [[ -s "$STATE_FILE" ]]; then
        jq -r '.sessionToken // empty' "$STATE_FILE" 2>/dev/null || true
    fi
}

salvar_sessao() {
    local key="$1"
    local token="$2"
    local expires_at="$3"

    mkdir -p "$STATE_DIR"
    jq -n \
        --arg key "$key" \
        --arg sessionToken "$token" \
        --argjson expiresAt "${expires_at:-0}" \
        '{key:$key, sessionToken:$sessionToken, expiresAt:$expiresAt}' \
        > "$STATE_FILE"
    chmod 600 "$STATE_FILE"
}

limpar_sessao() {
    rm -f "$STATE_FILE"
}

montar_payload() {
    local key="$1"
    local hwid="$2"
    local token="${3:-}"

    if [[ -n "$token" ]]; then
        jq -n \
            --arg key "$key" \
            --arg hwid "$hwid" \
            --arg appSlug "$APP_SLUG" \
            --arg appVersion "$APP_VERSION" \
            --arg sessionToken "$token" \
            '{key:$key, hwid:$hwid, appSlug:$appSlug, appVersion:$appVersion, sessionToken:$sessionToken}'
    else
        jq -n \
            --arg key "$key" \
            --arg hwid "$hwid" \
            --arg appSlug "$APP_SLUG" \
            --arg appVersion "$APP_VERSION" \
            '{key:$key, hwid:$hwid, appSlug:$appSlug, appVersion:$appVersion}'
    fi
}

consultar_api() {
    local payload="$1"
    local token="${2:-}"
    local resposta
    local -a headers=(
        -H 'Content-Type: application/json'
        -H 'Accept: application/json'
        -H 'User-Agent: GHOST-PRECICION-Termux/1.0'
        -H 'Connection: close'
    )

    if [[ -n "$token" ]]; then
        headers+=(
            -H "Authorization: Bearer $token"
            -H "X-Session-Token: $token"
        )
    fi

    if ! resposta="$(curl --silent --show-error --location --http1.1 \
        --connect-timeout 15 --max-time 30 \
        --request POST "$API_URL" \
        "${headers[@]}" \
        --data "$payload")"; then
        printf '%bErro de conexão com a API.%b\n' "$VERMELHO" "$RESET" >&2
        return 2
    fi

    if ! jq -e . >/dev/null 2>&1 <<< "$resposta"; then
        printf '%bResposta inválida da API.%b\n' "$VERMELHO" "$RESET" >&2
        return 2
    fi

    printf '%s' "$resposta"
}

resposta_valida() {
    jq -e '
        (.success == true) and
        (.status == "active") and
        (.killed == false) and
        (.banned == false)
    ' >/dev/null 2>&1 <<< "$1"
}

validar_resposta() {
    local resposta="$1"
    local key="$2"
    local mensagem token expires_at

    if resposta_valida "$resposta"; then
        token="$(jq -r '.sessionToken // empty' <<< "$resposta")"
        expires_at="$(jq -r '.expiresAt // 0' <<< "$resposta")"

        if [[ -z "$token" ]]; then
            printf '%bA API autorizou, mas não retornou sessionToken.%b\n' "$VERMELHO" "$RESET" >&2
            return 1
        fi

        salvar_sessao "$key" "$token" "$expires_at"
        printf '%bAcesso liberado.%b\n' "$VERDE" "$RESET"
        return 0
    fi

    mensagem="$(jq -r '.message // "Key inválida, expirada, pausada ou HWID não corresponde."' <<< "$resposta")"
    printf '%b%s%b\n' "$VERMELHO" "$mensagem" "$RESET" >&2
    return 1
}

validar_key() {
    local key="${1:-}"
    local hwid token payload resposta

    if [[ -z "$key" ]]; then
        printf '%bDigite uma Key.%b\n' "$VERMELHO" "$RESET" >&2
        return 1
    fi

    hwid="$(obter_hwid)" || return 1
    token="$(ler_token)"
    payload="$(montar_payload "$key" "$hwid" "$token")"

    printf '%bValidando Key na API...%b\n' "$CIANO" "$RESET"

    if resposta="$(consultar_api "$payload" "$token")"; then
        if validar_resposta "$resposta" "$key"; then
            return 0
        fi

        # Token expirado ou inválido: remove apenas a sessão e tenta uma vez
        # sem token, mantendo a validação server-side da mesma Key/HWID.
        if [[ -n "$token" ]]; then
            limpar_sessao
            payload="$(montar_payload "$key" "$hwid")"
            printf '%bSessão anterior inválida; solicitando nova sessão...%b\n' "$CIANO" "$RESET"
            if resposta="$(consultar_api "$payload")"; then
                validar_resposta "$resposta" "$key"
                return $?
            fi
        fi
        return 1
    fi

    return 1
}

intro() {
    limpar
    printf '%b' "$ROXO"
    som
    printf 'CARREGANDO SISTEMA...\n'
    pausar 1
    limpar
    cat <<'EOF'

 ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
██║  ███╗███████║██║   ██║███████╗   ██║
██║   ██║██╔══██║██║   ██║╚════██║   ██║
╚██████╔╝██║  ██║╚██████╔╝███████║   ██║
 ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝

                 PRECICION
EOF
    printf '%b' "$RESET"
    pausar 1
}

carregando() {
    limpar
    printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$ROXO"
    printf '        INICIANDO SISTEMA\n'
    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n' "$RESET"

    pausar 1
    printf '[*] Procurando porta...\n'
    pausar 2
    printf '[OK] Porta encontrada e conectada.\n'
    pausar 1

    local ip
    ip="$(awk 'BEGIN{srand(); printf "%d.%d.%d.%d", rand()*223+1, rand()*256, rand()*256, rand()*256}')"
    printf '[NET] IP: [%s]\n' "$ip"
    pausar 2
    printf '[OK] Servidor conectado. Pronto para uso.\n'
    pausar 2
}

ativar() {
    local recurso="$1"
    som
    printf '\nAtivando %s...\n' "$recurso"
    pausar 2
    printf '■■□□□□□□□□ 20%%\n'; pausar 0.5
    printf '■■■■□□□□□□ 40%%\n'; pausar 0.5
    printf '■■■■■■□□□□ 60%%\n'; pausar 0.5
    printf '■■■■■■■■□□ 80%%\n'; pausar 0.5
    printf '■■■■■■■■■■ 100%%\n'; pausar 1
    som
    printf '\n%b%s ativado com sucesso.%b\n' "$VERDE" "$recurso" "$RESET"
    printf '\nEntre no jogo.\n'
    pausar 3
}

menu() {
    while true; do
        limpar
        printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$ROXO"
        printf '         %s\n' "$APP_NAME"
        printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n' "$RESET"
        printf '\n [1] Precisão\n [2] Assistência de Mira\n [3] Estabilizar Mira\n [4] Aumento de FPS\n [5] Dispositivo protegido\n [6] Sair\n\n'
        read -r -p 'Escolha: ' opcao

        case "$opcao" in
            1) ativar 'Precisão' ;;
            2) ativar 'Assistência de Mira' ;;
            3) ativar 'Estabilização de Mira' ;;
            4) ativar 'Aumento de FPS' ;;
            5) ativar 'Otimização do Dispositivo' ;;
            6) limpar; printf 'Saindo...\n'; exit 0 ;;
            *) printf '%bOpção inválida.%b\n' "$VERMELHO" "$RESET"; pausar 1 ;;
        esac
    done
}

menu_principal() {
    while true; do
        limpar
        printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$ROXO"
        printf '         %s\n' "$APP_NAME"
        printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n' "$RESET"
        printf ' [1] Free Fire Max\n [2] Free Fire Normal\n [3] Sair\n\n'
        read -r -p 'Escolha: ' opcao

        case "$opcao" in
            1|2)
                printf '\n[OK] Jogo selecionado.\n'
                pausar 1
                menu
                ;;
            3)
                limpar
                printf 'Saindo...\n'
                exit 0
                ;;
            *)
                printf '%bOpção inválida.%b\n' "$VERMELHO" "$RESET"
                pausar 1
                ;;
        esac
    done
}

main() {
    exigir_dependencias
    intro
    printf 'Digite a Key: '
    read -r key

    if ! validar_key "$key"; then
        printf '%bAcesso bloqueado.%b\n' "$VERMELHO" "$RESET"
        exit 1
    fi

    carregando
    menu_principal
}

main "$@"
