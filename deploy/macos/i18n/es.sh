# shellcheck shell=bash
# es.sh -- Spanish installer message catalog for install-macos.sh (AI first-pass draft).
# Keys absent here fall back to English. Technical tokens left untranslated.
# MUST be native-reviewed before go-live.
_msg_es() {
  case "$1" in
    warn_not_macos)   printf '%s' 'ADVERTENCIA: esto no es macOS (uname=%s). Continuando solo para comprobaciones estaticas.';;
    err_trap)         printf '%s' 'install-macos.sh fallo en la linea %s (salida %s). No se inicio nada; corrija la causa y vuelva a ejecutar (el script es idempotente).';;
    msg_lang_selected) printf '%s' 'idioma del instalador: %s';;
    hdr_preflight)    printf '%s' 'comprobaciones previas (preflight)';;
    pf_cmds_ok)       printf '%s' 'comandos requeridos presentes';;
    pf_sudo_note)     printf '%s' 'algunos pasos usan sudo (crear /opt/upes-ecs y /var/lib/upes-ecs) -- puede pedirse su contrasena una vez.';;
    hdr_homebrew)     printf '%s' 'Homebrew';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    hdr_state_dirs)   printf '%s' 'directorios de estado + instalacion (sudo)';;
    hdr_ast_cfg)      printf '%s' 'configuracion de asterisk';;
    accounts_stub)    printf '%s' 'pjsip_accounts.conf es un stub vacio -- anada usuarios SIP tras la instalacion (README-MACOS.md)';;
    hdr_ext_addr)     printf '%s' 'direccion externa de media/senalizacion';;
    lan_ip)           printf '%s' 'IP LAN: %s';;
    lang_no_pack)     printf '%s' '!! el idioma solicitado %s no tiene paquete -- volviendo a en';;
    hdr_prompts)      printf '%s' 'mensajes de voz (idioma=%s)';;
    hdr_groups)       printf '%s' 'grupos de llamada / pase de lista';;
    hdr_api)          printf '%s' 'API de estado local (FastAPI :8090)';;
    hdr_console)      printf '%s' 'servidor web de la Consola (:8080)';;
    hdr_launchd)      printf '%s' 'agentes launchd (~/Library/LaunchAgents)';;
    launchctl_missing) printf '%s' '(launchctl no encontrado -- no es macOS? use run-foreground.sh)';;
    gatekeeper_note)  printf '%s' 'Compilacion sin firmar: si macOS pone el instalador en cuarentena, ejecute  xattr -dr com.apple.quarantine <file>  (vea README-MACOS.md "Gatekeeper").';;
    summary_complete) printf '%s' 'Instalacion de UPES-ECS en macOS completada.';;
    sum_emergency)    printf '%s' 'emergencia (cola ERT)';;
    sum_phones)       printf '%s' 'registrar en %s:5060  (app WebSocket: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'Servicios (LaunchAgents de launchd):';;
    sum_foreground)   printf '%s' 'Alternativa en primer plano (sin launchd):';;
    sum_add_users)    printf '%s' 'Anada usuarios SIP tras la instalacion (el archivo de cuentas incluido es un stub limpio):';;
    sum_see_readme)   printf '%s' 'vea README-MACOS.md "Add a user".';;
    *) return 1;;
  esac
}
