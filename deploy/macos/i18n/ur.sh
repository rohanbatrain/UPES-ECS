# shellcheck shell=bash
# ur.sh -- Urdu installer message catalog for install-macos.sh (AI first-pass draft).
# Urdu is RTL; terminals render it right-to-left. Keys absent here fall back to
# English. Technical tokens left untranslated. MUST be native-reviewed before go-live.
_msg_ur() {
  case "$1" in
    warn_not_macos)   printf '%s' 'انتباہ: یہ macOS نہیں ہے (uname=%s). صرف static/dry جانچ کے لیے جاری ہے.';;
    err_trap)         printf '%s' 'install-macos.sh لائن %s پر ناکام (exit %s). کچھ بھی زبردستی شروع نہیں کیا گیا؛ وجہ درست کر کے دوبارہ چلائیں (اسکرپٹ idempotent ہے).';;
    msg_lang_selected) printf '%s' 'انسٹالر زبان: %s';;
    hdr_preflight)    printf '%s' 'پیشگی جانچ (preflight)';;
    pf_cmds_ok)       printf '%s' 'مطلوبہ کمانڈز موجود ہیں';;
    pf_sudo_note)     printf '%s' 'کچھ مراحل sudo استعمال کرتے ہیں (/opt/upes-ecs اور /var/lib/upes-ecs بنانے کے لیے) -- آپ سے ایک بار لاگ اِن پاس ورڈ پوچھا جا سکتا ہے.';;
    hdr_homebrew)     printf '%s' 'Homebrew';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    hdr_state_dirs)   printf '%s' 'state + install ڈائریکٹریاں (sudo)';;
    hdr_ast_cfg)      printf '%s' 'asterisk کنفیگریشن';;
    accounts_stub)    printf '%s' 'pjsip_accounts.conf ایک خالی stub ہے -- انسٹال کے بعد SIP صارفین شامل کریں (README-MACOS.md)';;
    hdr_ext_addr)     printf '%s' 'external media/signaling پتہ';;
    lan_ip)           printf '%s' 'LAN IP: %s';;
    lang_no_pack)     printf '%s' '!! درخواست کردہ زبان %s کا کوئی پیک نہیں -- en پر واپس جا رہے ہیں';;
    hdr_prompts)      printf '%s' 'وائس پرامپٹس (زبان=%s)';;
    hdr_groups)       printf '%s' 'callout / roll-call گروپس';;
    hdr_api)          printf '%s' 'لوکل اسٹیٹس API (FastAPI :8090)';;
    hdr_console)      printf '%s' 'Console ویب سرور (:8080)';;
    hdr_launchd)      printf '%s' 'launchd ایجنٹس (~/Library/LaunchAgents)';;
    launchctl_missing) printf '%s' '(launchctl نہیں ملا -- macOS نہیں؟ run-foreground.sh استعمال کریں)';;
    gatekeeper_note)  printf '%s' 'ان سائنڈ بلڈ: اگر macOS انسٹالر کو quarantine کرے تو چلائیں  xattr -dr com.apple.quarantine <file>  (README-MACOS.md "Gatekeeper" دیکھیں).';;
    summary_complete) printf '%s' 'UPES-ECS macOS انسٹال مکمل.';;
    sum_emergency)    printf '%s' 'ہنگامی (ERT قطار)';;
    sum_phones)       printf '%s' '%s:5060 پر رجسٹر کریں  (WebSocket app: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'سروسز (launchd LaunchAgents):';;
    sum_foreground)   printf '%s' 'فورگراؤنڈ فال بیک (launchd کے بغیر):';;
    sum_add_users)    printf '%s' 'انسٹال کے بعد SIP صارفین شامل کریں (شپ کی گئی accounts فائل ایک clean stub ہے):';;
    sum_see_readme)   printf '%s' 'README-MACOS.md "Add a user" دیکھیں.';;
    *) return 1;;
  esac
}
