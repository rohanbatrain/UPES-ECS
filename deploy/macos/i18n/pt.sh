# pt.sh -- Portuguese installer message catalog for install-macos.sh (AI first-pass draft).
# Keys absent here fall back to English. Technical tokens left untranslated.
# MUST be native-reviewed before go-live.
_msg_pt() {
  case "$1" in
    warn_not_macos)   printf '%s' 'AVISO: isto nao e macOS (uname=%s). Continuando apenas para verificacoes estaticas.';;
    err_trap)         printf '%s' 'install-macos.sh falhou na linha %s (saida %s). Nada foi iniciado; corrija a causa e execute novamente (o script e idempotente).';;
    msg_lang_selected) printf '%s' 'idioma do instalador: %s';;
    hdr_preflight)    printf '%s' 'verificacoes previas (preflight)';;
    pf_cmds_ok)       printf '%s' 'comandos necessarios presentes';;
    pf_sudo_note)     printf '%s' 'algumas etapas usam sudo (criar /opt/upes-ecs e /var/lib/upes-ecs) -- sua senha pode ser solicitada uma vez.';;
    hdr_homebrew)     printf '%s' 'Homebrew';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    hdr_state_dirs)   printf '%s' 'diretorios de estado + instalacao (sudo)';;
    hdr_ast_cfg)      printf '%s' 'configuracao do asterisk';;
    accounts_stub)    printf '%s' 'pjsip_accounts.conf e um stub vazio -- adicione usuarios SIP apos a instalacao (README-MACOS.md)';;
    hdr_ext_addr)     printf '%s' 'endereco externo de media/sinalizacao';;
    lan_ip)           printf '%s' 'IP LAN: %s';;
    lang_no_pack)     printf '%s' '!! o idioma solicitado %s nao tem pacote -- voltando para en';;
    hdr_prompts)      printf '%s' 'avisos de voz (idioma=%s)';;
    hdr_groups)       printf '%s' 'grupos de chamada / chamada nominal';;
    hdr_api)          printf '%s' 'API de status local (FastAPI :8090)';;
    hdr_console)      printf '%s' 'servidor web da Console (:8080)';;
    hdr_launchd)      printf '%s' 'agentes launchd (~/Library/LaunchAgents)';;
    launchctl_missing) printf '%s' '(launchctl nao encontrado -- nao e macOS? use run-foreground.sh)';;
    gatekeeper_note)  printf '%s' 'Build sem assinatura: se o macOS colocar o instalador em quarentena, execute  xattr -dr com.apple.quarantine <file>  (veja README-MACOS.md "Gatekeeper").';;
    summary_complete) printf '%s' 'Instalacao do UPES-ECS no macOS concluida.';;
    sum_emergency)    printf '%s' 'emergencia (fila ERT)';;
    sum_phones)       printf '%s' 'registrar em %s:5060  (app WebSocket: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'Servicos (LaunchAgents do launchd):';;
    sum_foreground)   printf '%s' 'Alternativa em primeiro plano (sem launchd):';;
    sum_add_users)    printf '%s' 'Adicione usuarios SIP apos a instalacao (o arquivo de contas fornecido e um stub limpo):';;
    sum_see_readme)   printf '%s' 'veja README-MACOS.md "Add a user".';;
    *) return 1;;
  esac
}
