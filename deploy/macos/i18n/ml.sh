# ml.sh -- Malayalam installer message catalog for install-macos.sh (AI first-pass draft).
# Keys absent here fall back to English. Technical tokens left untranslated.
# MUST be native-reviewed before go-live.
_msg_ml() {
  case "$1" in
    warn_not_macos)   printf '%s' 'മുന്നറിയിപ്പ്: ഇത് macOS അല്ല (uname=%s). static/dry പരിശോധനകൾക്കായി മാത്രം തുടരുന്നു.';;
    err_trap)         printf '%s' 'install-macos.sh ലൈൻ %s-ൽ പരാജയപ്പെട്ടു (exit %s). ഒന്നും നിർബന്ധിതമായി ആരംഭിച്ചിട്ടില്ല; കാരണം പരിഹരിച്ച് വീണ്ടും പ്രവർത്തിപ്പിക്കുക (സ്ക്രിപ്റ്റ് idempotent ആണ്).';;
    msg_lang_selected) printf '%s' 'ഇൻസ്റ്റാളർ ഭാഷ: %s';;
    hdr_preflight)    printf '%s' 'മുൻ‌കൂർ പരിശോധനകൾ (preflight)';;
    pf_cmds_ok)       printf '%s' 'ആവശ്യമായ കമാൻഡുകൾ ലഭ്യമാണ്';;
    pf_sudo_note)     printf '%s' 'ചില ഘട്ടങ്ങൾ sudo ഉപയോഗിക്കുന്നു (/opt/upes-ecs, /var/lib/upes-ecs സൃഷ്ടിക്കാൻ) -- നിങ്ങളുടെ ലോഗിൻ പാസ്‌വേഡ് ഒരിക്കൽ ചോദിച്ചേക്കാം.';;
    hdr_homebrew)     printf '%s' 'Homebrew';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    hdr_state_dirs)   printf '%s' 'state + install ഡയറക്ടറികൾ (sudo)';;
    hdr_ast_cfg)      printf '%s' 'asterisk കോൺഫിഗറേഷൻ';;
    accounts_stub)    printf '%s' 'pjsip_accounts.conf ഒരു ശൂന്യമായ stub ആണ് -- ഇൻസ്റ്റാളിന് ശേഷം SIP ഉപയോക്താക്കളെ ചേർക്കുക (README-MACOS.md)';;
    hdr_ext_addr)     printf '%s' 'external media/signaling വിലാസം';;
    lan_ip)           printf '%s' 'LAN IP: %s';;
    lang_no_pack)     printf '%s' '!! അഭ്യർത്ഥിച്ച ഭാഷ %s-ന് പായ്ക്ക് ഇല്ല -- en-ലേക്ക് മടങ്ങുന്നു';;
    hdr_prompts)      printf '%s' 'വോയിസ് പ്രോംപ്റ്റുകൾ (ഭാഷ=%s)';;
    hdr_groups)       printf '%s' 'callout / roll-call ഗ്രൂപ്പുകൾ';;
    hdr_api)          printf '%s' 'ലോക്കൽ സ്റ്റാറ്റസ് API (FastAPI :8090)';;
    hdr_console)      printf '%s' 'Console വെബ് സെർവർ (:8080)';;
    hdr_launchd)      printf '%s' 'launchd ഏജന്റുകൾ (~/Library/LaunchAgents)';;
    launchctl_missing) printf '%s' '(launchctl കണ്ടെത്തിയില്ല -- macOS അല്ലേ? run-foreground.sh ഉപയോഗിക്കുക)';;
    gatekeeper_note)  printf '%s' 'അൺസൈൻഡ് ബിൽഡ്: macOS ഇൻസ്റ്റാളറിനെ quarantine ചെയ്താൽ, പ്രവർത്തിപ്പിക്കുക  xattr -dr com.apple.quarantine <file>  (README-MACOS.md "Gatekeeper" കാണുക).';;
    summary_complete) printf '%s' 'UPES-ECS macOS ഇൻസ്റ്റാൾ പൂർത്തിയായി.';;
    sum_emergency)    printf '%s' 'അടിയന്തരം (ERT ക്യൂ)';;
    sum_phones)       printf '%s' '%s:5060-ലേക്ക് രജിസ്റ്റർ ചെയ്യുക  (WebSocket app: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'സേവനങ്ങൾ (launchd LaunchAgents):';;
    sum_foreground)   printf '%s' 'ഫോർഗ്രൗണ്ട് ഫാൾബാക്ക് (launchd ഇല്ലാതെ):';;
    sum_add_users)    printf '%s' 'ഇൻസ്റ്റാളിന് ശേഷം SIP ഉപയോക്താക്കളെ ചേർക്കുക (ഷിപ്പ് ചെയ്ത accounts ഫയൽ ഒരു clean stub ആണ്):';;
    sum_see_readme)   printf '%s' 'README-MACOS.md "Add a user" കാണുക.';;
    *) return 1;;
  esac
}
