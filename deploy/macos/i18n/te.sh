# shellcheck shell=bash
# te.sh -- Telugu installer message catalog for install-macos.sh (AI first-pass draft).
# Keys absent here fall back to English. Technical tokens left untranslated.
# MUST be native-reviewed before go-live.
_msg_te() {
  case "$1" in
    warn_not_macos)   printf '%s' 'హెచ్చరిక: ఇది macOS కాదు (uname=%s). static/dry తనిఖీల కోసం మాత్రమే కొనసాగుతోంది.';;
    err_trap)         printf '%s' 'install-macos.sh లైన్ %s వద్ద విఫలమైంది (exit %s). ఏదీ బలవంతంగా ప్రారంభించలేదు; కారణాన్ని సరిచేసి మళ్ళీ అమలు చేయండి (స్క్రిప్ట్ idempotent).';;
    msg_lang_selected) printf '%s' 'ఇన్‌స్టాలర్ భాష: %s';;
    hdr_preflight)    printf '%s' 'ముందస్తు తనిఖీలు (preflight)';;
    pf_cmds_ok)       printf '%s' 'అవసరమైన కమాండ్‌లు అందుబాటులో ఉన్నాయి';;
    pf_sudo_note)     printf '%s' 'కొన్ని దశలు sudo ను ఉపయోగిస్తాయి (/opt/upes-ecs మరియు /var/lib/upes-ecs సృష్టించడానికి) -- మీ లాగిన్ పాస్‌వర్డ్ ఒకసారి అడగవచ్చు.';;
    hdr_homebrew)     printf '%s' 'Homebrew';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    hdr_state_dirs)   printf '%s' 'state + install డైరెక్టరీలు (sudo)';;
    hdr_ast_cfg)      printf '%s' 'asterisk కాన్ఫిగరేషన్';;
    accounts_stub)    printf '%s' 'pjsip_accounts.conf ఖాళీ stub -- ఇన్‌స్టాల్ తర్వాత SIP వినియోగదారులను జోడించండి (README-MACOS.md)';;
    hdr_ext_addr)     printf '%s' 'external media/signaling చిరునామా';;
    lan_ip)           printf '%s' 'LAN IP: %s';;
    lang_no_pack)     printf '%s' '!! అభ్యర్థించిన భాష %s కు ప్యాక్ లేదు -- en కు తిరిగి వెళుతోంది';;
    hdr_prompts)      printf '%s' 'వాయిస్ ప్రాంప్ట్‌లు (భాష=%s)';;
    hdr_groups)       printf '%s' 'callout / roll-call గ్రూపులు';;
    hdr_api)          printf '%s' 'లోకల్ స్టేటస్ API (FastAPI :8090)';;
    hdr_console)      printf '%s' 'Console వెబ్ సర్వర్ (:8080)';;
    hdr_launchd)      printf '%s' 'launchd ఏజెంట్లు (~/Library/LaunchAgents)';;
    launchctl_missing) printf '%s' '(launchctl కనబడలేదు -- macOS కాదా? run-foreground.sh ను ఉపయోగించండి)';;
    gatekeeper_note)  printf '%s' 'అన్‌సైన్డ్ బిల్డ్: macOS ఇన్‌స్టాలర్‌ను quarantine చేస్తే, అమలు చేయండి  xattr -dr com.apple.quarantine <file>  (README-MACOS.md "Gatekeeper" చూడండి).';;
    summary_complete) printf '%s' 'UPES-ECS macOS ఇన్‌స్టాల్ పూర్తయింది.';;
    sum_emergency)    printf '%s' 'అత్యవసరం (ERT క్యూ)';;
    sum_phones)       printf '%s' '%s:5060 కు రిజిస్టర్ చేయండి  (WebSocket app: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'సేవలు (launchd LaunchAgents):';;
    sum_foreground)   printf '%s' 'ఫోర్‌గ్రౌండ్ ఫాల్‌బ్యాక్ (launchd లేకుండా):';;
    sum_add_users)    printf '%s' 'ఇన్‌స్టాల్ తర్వాత SIP వినియోగదారులను జోడించండి (షిప్ చేసిన accounts ఫైల్ clean stub):';;
    sum_see_readme)   printf '%s' 'README-MACOS.md "Add a user" చూడండి.';;
    *) return 1;;
  esac
}
