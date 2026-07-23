# ne.sh -- Nepali installer message catalog for install-macos.sh (AI first-pass draft).
# Keys absent here fall back to English. Technical tokens left untranslated.
# MUST be native-reviewed before go-live.
_msg_ne() {
  case "$1" in
    warn_not_macos)   printf '%s' 'चेतावनी: यो macOS होइन (uname=%s). static/dry जाँचका लागि मात्र जारी छ.';;
    err_trap)         printf '%s' 'install-macos.sh लाइन %s मा असफल (exit %s). केही पनि जबरजस्ती सुरु गरिएको छैन; कारण ठीक गरेर फेरि चलाउनुहोस् (स्क्रिप्ट idempotent छ).';;
    msg_lang_selected) printf '%s' 'इन्स्टलर भाषा: %s';;
    hdr_preflight)    printf '%s' 'पूर्व-जाँच (preflight)';;
    pf_cmds_ok)       printf '%s' 'आवश्यक कमाण्डहरू उपलब्ध छन्';;
    pf_sudo_note)     printf '%s' 'केही चरणहरूले sudo प्रयोग गर्छन् (/opt/upes-ecs र /var/lib/upes-ecs बनाउन) -- तपाईंलाई एक पटक लगइन पासवर्ड सोधिन सक्छ.';;
    hdr_homebrew)     printf '%s' 'Homebrew';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    hdr_state_dirs)   printf '%s' 'state + install डाइरेक्टरीहरू (sudo)';;
    hdr_ast_cfg)      printf '%s' 'asterisk कन्फिगरेसन';;
    accounts_stub)    printf '%s' 'pjsip_accounts.conf खाली stub हो -- इन्स्टल पछि SIP प्रयोगकर्ता थप्नुहोस् (README-MACOS.md)';;
    hdr_ext_addr)     printf '%s' 'external media/signaling ठेगाना';;
    lan_ip)           printf '%s' 'LAN IP: %s';;
    lang_no_pack)     printf '%s' '!! अनुरोध गरिएको भाषा %s को कुनै प्याक छैन -- en मा फर्कंदै';;
    hdr_prompts)      printf '%s' 'भ्वाइस प्रम्प्टहरू (भाषा=%s)';;
    hdr_groups)       printf '%s' 'callout / roll-call समूहहरू';;
    hdr_api)          printf '%s' 'लोकल स्टाटस API (FastAPI :8090)';;
    hdr_console)      printf '%s' 'Console वेब सर्भर (:8080)';;
    hdr_launchd)      printf '%s' 'launchd एजेन्टहरू (~/Library/LaunchAgents)';;
    launchctl_missing) printf '%s' '(launchctl फेला परेन -- macOS होइन? run-foreground.sh प्रयोग गर्नुहोस्)';;
    gatekeeper_note)  printf '%s' 'अनसाइन्ड बिल्ड: यदि macOS ले इन्स्टलरलाई quarantine गर्छ भने चलाउनुहोस्  xattr -dr com.apple.quarantine <file>  (README-MACOS.md "Gatekeeper" हेर्नुहोस्).';;
    summary_complete) printf '%s' 'UPES-ECS macOS इन्स्टल पूरा भयो.';;
    sum_emergency)    printf '%s' 'आपतकालीन (ERT लाम)';;
    sum_phones)       printf '%s' '%s:5060 मा रजिस्टर गर्नुहोस्  (WebSocket app: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'सेवाहरू (launchd LaunchAgents):';;
    sum_foreground)   printf '%s' 'फोरग्राउन्ड फलब्याक (launchd बिना):';;
    sum_add_users)    printf '%s' 'इन्स्टल पछि SIP प्रयोगकर्ता थप्नुहोस् (सिप गरिएको accounts फाइल clean stub हो):';;
    sum_see_readme)   printf '%s' 'README-MACOS.md "Add a user" हेर्नुहोस्.';;
    *) return 1;;
  esac
}
