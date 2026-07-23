# shellcheck shell=bash
# fr.sh -- French installer message catalog for install-macos.sh (AI first-pass draft).
# Keys absent here fall back to English. Technical tokens left untranslated.
# MUST be native-reviewed before go-live.
_msg_fr() {
  case "$1" in
    warn_not_macos)   printf '%s' 'AVERTISSEMENT: ceci n est pas macOS (uname=%s). Poursuite pour les verifications statiques uniquement.';;
    err_trap)         printf '%s' 'install-macos.sh a echoue a la ligne %s (code %s). Rien n a ete demarre; corrigez la cause et relancez (le script est idempotent).';;
    msg_lang_selected) printf '%s' 'langue de l installateur: %s';;
    hdr_preflight)    printf '%s' 'verifications prealables (preflight)';;
    pf_cmds_ok)       printf '%s' 'commandes requises presentes';;
    pf_sudo_note)     printf '%s' 'certaines etapes utilisent sudo (creation de /opt/upes-ecs et /var/lib/upes-ecs) -- votre mot de passe peut etre demande une fois.';;
    hdr_homebrew)     printf '%s' 'Homebrew';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    hdr_state_dirs)   printf '%s' 'repertoires d etat + installation (sudo)';;
    hdr_ast_cfg)      printf '%s' 'configuration asterisk';;
    accounts_stub)    printf '%s' 'pjsip_accounts.conf est un stub vide -- ajoutez des utilisateurs SIP apres l installation (README-MACOS.md)';;
    hdr_ext_addr)     printf '%s' 'adresse externe media/signalisation';;
    lan_ip)           printf '%s' 'IP LAN: %s';;
    lang_no_pack)     printf '%s' '!! la langue demandee %s n a pas de pack -- retour a en';;
    hdr_prompts)      printf '%s' 'invites vocales (langue=%s)';;
    hdr_groups)       printf '%s' 'groupes d appel / appel nominal';;
    hdr_api)          printf '%s' 'API d etat locale (FastAPI :8090)';;
    hdr_console)      printf '%s' 'serveur web de la Console (:8080)';;
    hdr_launchd)      printf '%s' 'agents launchd (~/Library/LaunchAgents)';;
    launchctl_missing) printf '%s' '(launchctl introuvable -- pas macOS? utilisez run-foreground.sh)';;
    gatekeeper_note)  printf '%s' 'Build non signe: si macOS met l installateur en quarantaine, executez  xattr -dr com.apple.quarantine <file>  (voir README-MACOS.md "Gatekeeper").';;
    summary_complete) printf '%s' 'Installation de UPES-ECS sur macOS terminee.';;
    sum_emergency)    printf '%s' 'urgence (file ERT)';;
    sum_phones)       printf '%s' 'enregistrer sur %s:5060  (app WebSocket: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'Services (LaunchAgents launchd):';;
    sum_foreground)   printf '%s' 'Repli au premier plan (sans launchd):';;
    sum_add_users)    printf '%s' 'Ajoutez des utilisateurs SIP apres l installation (le fichier de comptes livre est un stub propre):';;
    sum_see_readme)   printf '%s' 'voir README-MACOS.md "Add a user".';;
    *) return 1;;
  esac
}
