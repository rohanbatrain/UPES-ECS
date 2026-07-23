# hi.sh -- Hindi installer message catalog for install-macos.sh (AI first-pass draft).
# Sourced by install-macos.sh; defines _msg_hi <key> -> prints a printf template.
# Keys absent here fall back to English (_msg_en). Technical tokens (paths, flags,
# brew, sudo, SIP, 111, ERT, URLs) are intentionally left untranslated.
# MUST be native-reviewed before go-live.
_msg_hi() {
  case "$1" in
    warn_not_macos)   printf '%s' 'चेतावनी: यह macOS नहीं है (uname=%s). केवल static/dry जाँच के लिए जारी है.';;
    err_trap)         printf '%s' 'install-macos.sh लाइन %s पर विफल (exit %s). कुछ भी चालू नहीं किया गया; कारण ठीक करके फिर से चलाएँ (स्क्रिप्ट idempotent है).';;
    msg_lang_selected) printf '%s' 'इंस्टॉलर भाषा: %s';;
    hdr_preflight)    printf '%s' 'पूर्व-जाँच (preflight)';;
    pf_cmds_ok)       printf '%s' 'आवश्यक कमांड उपलब्ध हैं';;
    pf_sudo_note)     printf '%s' 'कुछ चरण sudo का उपयोग करते हैं (/opt/upes-ecs और /var/lib/upes-ecs बनाने के लिए) -- आपसे एक बार लॉगिन पासवर्ड पूछा जा सकता है.';;
    hdr_homebrew)     printf '%s' 'Homebrew';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    hdr_state_dirs)   printf '%s' 'state + install डायरेक्ट्री (sudo)';;
    hdr_ast_cfg)      printf '%s' 'asterisk कॉन्फ़िगरेशन';;
    accounts_stub)    printf '%s' 'pjsip_accounts.conf खाली stub है -- इंस्टॉल के बाद SIP उपयोगकर्ता जोड़ें (README-MACOS.md)';;
    hdr_ext_addr)     printf '%s' 'external media/signaling पता';;
    lan_ip)           printf '%s' 'LAN IP: %s';;
    lang_no_pack)     printf '%s' '!! अनुरोधित भाषा %s का कोई पैक नहीं है -- en पर वापस जा रहे हैं';;
    hdr_prompts)      printf '%s' 'वॉइस प्रॉम्प्ट (भाषा=%s)';;
    hdr_groups)       printf '%s' 'callout / roll-call समूह';;
    hdr_api)          printf '%s' 'लोकल स्टेटस API (FastAPI :8090)';;
    hdr_console)      printf '%s' 'Console वेब सर्वर (:8080)';;
    hdr_launchd)      printf '%s' 'launchd एजेंट (~/Library/LaunchAgents)';;
    launchctl_missing) printf '%s' '(launchctl नहीं मिला -- macOS नहीं? run-foreground.sh का उपयोग करें)';;
    gatekeeper_note)  printf '%s' 'अनसाइन्ड बिल्ड: यदि macOS इंस्टॉलर को quarantine करे, तो चलाएँ  xattr -dr com.apple.quarantine <file>  (README-MACOS.md "Gatekeeper" देखें).';;
    summary_complete) printf '%s' 'UPES-ECS macOS इंस्टॉल पूर्ण.';;
    sum_emergency)    printf '%s' 'आपातकाल (ERT कतार)';;
    sum_phones)       printf '%s' '%s:5060 पर रजिस्टर करें  (WebSocket app: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'सेवाएँ (launchd LaunchAgents):';;
    sum_foreground)   printf '%s' 'फोरग्राउंड फॉलबैक (launchd के बिना):';;
    sum_add_users)    printf '%s' 'इंस्टॉल के बाद SIP उपयोगकर्ता जोड़ें (शिप किया गया accounts फ़ाइल एक clean stub है):';;
    sum_see_readme)   printf '%s' 'README-MACOS.md "Add a user" देखें.';;
    *) return 1;;
  esac
}
