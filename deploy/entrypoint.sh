#!/usr/bin/env bash
# UPES-ECS container entrypoint: enable SHELL() for incident IDs, drop placeholder
# prompts so Playback() succeeds, fix ownership, then start Asterisk in foreground.
set -e

# 1. SHELL() (func_shell) is gated behind live_dangerously — enable it for this node.
if ! grep -q "live_dangerously" /etc/asterisk/asterisk.conf; then
  printf '\n[options]\nlive_dangerously = yes\n' >> /etc/asterisk/asterisk.conf
fi

# 2. Placeholder prompts (copy a real core sound to each upes-ecs/* name) so the
#    dialplan plays cleanly until the real recordings (SOP 28) are added.
PROMPT_DIR=/usr/share/asterisk/sounds/en/upes-ecs
mkdir -p "$PROMPT_DIR"
SRC="$(ls /usr/share/asterisk/sounds/en/*.gsm 2>/dev/null | head -1)"
if [ -n "$SRC" ]; then
  for p in emergency-preanswer emergency-voicemail-prompt drill-prompt \
           queue-paused queue-resumed not-authorized queue-hold; do
    cp -f "$SRC" "$PROMPT_DIR/${p}.gsm"
  done
fi

# 3. Ownership (state + recordings + prompts writable by asterisk)
chown -R asterisk:asterisk "$PROMPT_DIR" /var/lib/upes-ecs \
      /var/spool/asterisk/monitor/upes-ecs 2>/dev/null || true

# 4. Start Asterisk in the foreground
exec asterisk -f -vvvg -c
