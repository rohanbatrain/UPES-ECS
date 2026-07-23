# shellcheck shell=bash
# de.sh -- German installer message catalog for install-macos.sh (AI first-pass draft).
# Keys absent here fall back to English. Technical tokens left untranslated.
# MUST be native-reviewed before go-live.
_msg_de() {
  case "$1" in
    warn_not_macos)   printf '%s' 'WARNUNG: dies ist nicht macOS (uname=%s). Fortsetzung nur fuer statische Pruefungen.';;
    err_trap)         printf '%s' 'install-macos.sh in Zeile %s fehlgeschlagen (Exit %s). Nichts wurde gestartet; Ursache beheben und erneut ausfuehren (das Skript ist idempotent).';;
    msg_lang_selected) printf '%s' 'Installationssprache: %s';;
    hdr_preflight)    printf '%s' 'Vorpruefungen (preflight)';;
    pf_cmds_ok)       printf '%s' 'benoetigte Befehle vorhanden';;
    pf_sudo_note)     printf '%s' 'einige Schritte nutzen sudo (Anlegen von /opt/upes-ecs und /var/lib/upes-ecs) -- Sie werden ggf. einmal nach Ihrem Passwort gefragt.';;
    hdr_homebrew)     printf '%s' 'Homebrew';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    hdr_state_dirs)   printf '%s' 'Status- + Installationsverzeichnisse (sudo)';;
    hdr_ast_cfg)      printf '%s' 'asterisk-Konfiguration';;
    accounts_stub)    printf '%s' 'pjsip_accounts.conf ist ein leerer Stub -- SIP-Benutzer nach der Installation hinzufuegen (README-MACOS.md)';;
    hdr_ext_addr)     printf '%s' 'externe Media-/Signalisierungsadresse';;
    lan_ip)           printf '%s' 'LAN-IP: %s';;
    lang_no_pack)     printf '%s' '!! angeforderte Sprache %s hat kein Paket -- zuruck zu en';;
    hdr_prompts)      printf '%s' 'Sprachansagen (Sprache=%s)';;
    hdr_groups)       printf '%s' 'Ruf- / Namensaufruf-Gruppen';;
    hdr_api)          printf '%s' 'lokale Status-API (FastAPI :8090)';;
    hdr_console)      printf '%s' 'Console-Webserver (:8080)';;
    hdr_launchd)      printf '%s' 'launchd-Agenten (~/Library/LaunchAgents)';;
    launchctl_missing) printf '%s' '(launchctl nicht gefunden -- kein macOS? run-foreground.sh verwenden)';;
    gatekeeper_note)  printf '%s' 'Unsignierter Build: falls macOS den Installer in Quarantaene stellt, ausfuehren  xattr -dr com.apple.quarantine <file>  (siehe README-MACOS.md "Gatekeeper").';;
    summary_complete) printf '%s' 'UPES-ECS-Installation unter macOS abgeschlossen.';;
    sum_emergency)    printf '%s' 'Notfall (ERT-Warteschlange)';;
    sum_phones)       printf '%s' 'an %s:5060 registrieren  (WebSocket-App: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'Dienste (launchd LaunchAgents):';;
    sum_foreground)   printf '%s' 'Vordergrund-Fallback (ohne launchd):';;
    sum_add_users)    printf '%s' 'SIP-Benutzer nach der Installation hinzufuegen (die mitgelieferte Konten-Datei ist ein sauberer Stub):';;
    sum_see_readme)   printf '%s' 'siehe README-MACOS.md "Add a user".';;
    *) return 1;;
  esac
}
