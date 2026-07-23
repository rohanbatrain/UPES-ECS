# ar.sh -- Arabic installer message catalog for install-macos.sh (AI first-pass draft).
# Arabic is RTL; terminals render it right-to-left. Keys absent here fall back to
# English. Technical tokens left untranslated. MUST be native-reviewed before go-live.
_msg_ar() {
  case "$1" in
    warn_not_macos)   printf '%s' 'تحذير: هذا ليس macOS (uname=%s). الاستمرار من أجل الفحوص الثابتة فقط.';;
    err_trap)         printf '%s' 'فشل install-macos.sh في السطر %s (خروج %s). لم يتم تشغيل أي شيء؛ صحّح السبب وأعد التشغيل (السكربت idempotent).';;
    msg_lang_selected) printf '%s' 'لغة المُثبّت: %s';;
    hdr_preflight)    printf '%s' 'فحوص أولية (preflight)';;
    pf_cmds_ok)       printf '%s' 'الأوامر المطلوبة متوفرة';;
    pf_sudo_note)     printf '%s' 'بعض الخطوات تستخدم sudo (لإنشاء /opt/upes-ecs و /var/lib/upes-ecs) -- قد يُطلب منك كلمة المرور مرة واحدة.';;
    hdr_homebrew)     printf '%s' 'Homebrew';;
    hdr_brew_install) printf '%s' 'brew install asterisk python@3';;
    hdr_state_dirs)   printf '%s' 'أدلة الحالة + التثبيت (sudo)';;
    hdr_ast_cfg)      printf '%s' 'إعداد asterisk';;
    accounts_stub)    printf '%s' 'الملف pjsip_accounts.conf هو stub فارغ -- أضف مستخدمي SIP بعد التثبيت (README-MACOS.md)';;
    hdr_ext_addr)     printf '%s' 'عنوان الوسائط/الإشارة الخارجي';;
    lan_ip)           printf '%s' 'عنوان LAN IP: %s';;
    lang_no_pack)     printf '%s' '!! اللغة المطلوبة %s ليس لها حزمة -- العودة إلى en';;
    hdr_prompts)      printf '%s' 'الرسائل الصوتية (اللغة=%s)';;
    hdr_groups)       printf '%s' 'مجموعات النداء / تفقّد الأسماء';;
    hdr_api)          printf '%s' 'واجهة الحالة المحلية API (FastAPI :8090)';;
    hdr_console)      printf '%s' 'خادم الويب للوحة Console (:8080)';;
    hdr_launchd)      printf '%s' 'وكلاء launchd (~/Library/LaunchAgents)';;
    launchctl_missing) printf '%s' '(لم يتم العثور على launchctl -- ليس macOS؟ استخدم run-foreground.sh)';;
    gatekeeper_note)  printf '%s' 'بناء غير موقّع: إذا وضع macOS المُثبّت في الحجر، شغّل  xattr -dr com.apple.quarantine <file>  (انظر README-MACOS.md "Gatekeeper").';;
    summary_complete) printf '%s' 'اكتمل تثبيت UPES-ECS على macOS.';;
    sum_emergency)    printf '%s' 'طوارئ (طابور ERT)';;
    sum_phones)       printf '%s' 'سجّل على %s:5060  (تطبيق WebSocket: ws://%s:8088/ws)';;
    sum_services)     printf '%s' 'الخدمات (launchd LaunchAgents):';;
    sum_foreground)   printf '%s' 'البديل في المقدمة (بدون launchd):';;
    sum_add_users)    printf '%s' 'أضف مستخدمي SIP بعد التثبيت (ملف الحسابات المُرفق هو stub نظيف):';;
    sum_see_readme)   printf '%s' 'انظر README-MACOS.md "Add a user".';;
    *) return 1;;
  esac
}
