{
  config,
  pkgs,
  lib,
  ...
}:

let
  litellmConfigDir = "${config.xdg.configHome}/litellm";
  litellmConfigPath = "${litellmConfigDir}/config.yaml";
  litellmEnvPath = "${litellmConfigDir}/litellm.env";
in
{
  xdg.configFile."litellm/config.yaml".text = ''
    model_list:
      # Strict minimal mapping for debugging Claude Code <-> LiteLLM behavior.
      - model_name: codex
        model_info:
          mode: responses
        litellm_params:
          model: chatgpt/gpt-5.3-codex

    router_settings:
      num_retries: 0
      timeout: 30

    litellm_settings:
      master_key: os.environ/LITELLM_MASTER_KEY
      # Claude Code sends Anthropic-style system/developer roles; rewrite for ChatGPT routes.
      callbacks:
        - callbacks.proxy_handler_instance
      # Keep all incoming params while isolating protocol/transform issues.
      drop_params: false
  '';

  xdg.configFile."litellm/callbacks.py".text = ''
    import datetime
    import json
    import os

    from litellm.integrations.custom_logger import CustomLogger


    class SystemToInstructions(CustomLogger):
        _chatgpt_aliases = {
            "codex",
            "gpt-5.4",
            "gpt-5.4-mini",
            "claude-haiku-4-5",
            "claude-haiku-4-5-20251001",
            "claude-sonnet-4-5",
            "claude-sonnet-4-5-20250929",
            "claude-opus-4-1",
        }
        _truthy = {"1", "true", "yes", "on"}
        _system_roles = {"developer", "system"}

        def _is_chatgpt_route(self, model):
            model = str(model or "")
            return (
                model.startswith("chatgpt/")
                or model in self._chatgpt_aliases
                or model.startswith("gpt-5")
            )

        def _stringify_content(self, content):
            if isinstance(content, str):
                return content

            if isinstance(content, list):
                parts = []
                for block in content:
                    if isinstance(block, str):
                        parts.append(block)
                        continue

                    if not isinstance(block, dict):
                        parts.append(str(block))
                        continue

                    # Anthropic block: {"type": "text", "text": "..."}
                    text = block.get("text")
                    if isinstance(text, str):
                        parts.append(text)
                        continue

                    # OpenAI Responses block: {"type": "input_text", "text": "..."}
                    if isinstance(block.get("content"), str):
                        parts.append(block["content"])

                if parts:
                    return "\n\n".join(parts)

            if content is None:
                return ""

            return str(content)

        def _extract_message_text(self, msg):
            if not isinstance(msg, dict):
                return ""
            return self._stringify_content(msg.get("content"))

        def _merge_instructions(self, existing_instructions, moved_chunks):
            parts = []

            if existing_instructions is not None:
                existing_text = self._stringify_content(existing_instructions).strip()
                if existing_text:
                    parts.append(existing_text)

            for chunk in moved_chunks:
                text = self._stringify_content(chunk).strip()
                if text:
                    parts.append(text)

            # Deduplicate while preserving order.
            deduped = []
            seen = set()
            for part in parts:
                if part in seen:
                    continue
                seen.add(part)
                deduped.append(part)

            return "\n\n".join(deduped)

        def _rewrite_role_items_to_instructions(self, data, key):
            items = data.get(key)
            if not isinstance(items, list):
                return 0, []

            kept = []
            moved = []
            removed = 0

            for item in items:
                if isinstance(item, dict) and item.get("role") in self._system_roles:
                    removed += 1
                    text = self._extract_message_text(item)
                    if text.strip():
                        moved.append(text)
                    continue

                kept.append(item)

            if removed > 0:
                data[key] = kept

            return removed, moved

        def _logging_enabled(self):
            return str(os.environ.get("LITELLM_LOG_SYSTEM_REWRITE", "")).strip().lower() in self._truthy

        def _truncate(self, value, limit=1200):
            if value is None:
                return None
            text = value if isinstance(value, str) else str(value)
            if len(text) <= limit:
                return text
            return text[:limit] + f"... [truncated {len(text) - limit} chars]"

        def _roles_for_key(self, data, key):
            items = data.get(key)
            if not isinstance(items, list):
                return []

            roles = []
            for item in items:
                if isinstance(item, dict):
                    roles.append(str(item.get("role", "<none>")))
                else:
                    roles.append(type(item).__name__)
            return roles

        def _has_any_system_roles(self, data):
            for key in ("messages", "input"):
                items = data.get(key)
                if isinstance(items, list):
                    for msg in items:
                        if isinstance(msg, dict) and msg.get("role") in self._system_roles:
                            return True
            return False

        def _log_rewrite_event(
            self,
            *,
            model,
            call_type,
            had_top_level_system,
            had_inline_system_before,
            had_inline_system_after,
            moved_system_text,
            before_roles,
            after_roles,
            removed_counts,
            had_instructions_before,
            has_instructions_after,
        ):
            if not self._logging_enabled():
                return

            event = {
                "ts": datetime.datetime.utcnow().isoformat() + "Z",
                "event": "system_to_instructions_rewrite",
                "model": str(model or ""),
                "call_type": str(call_type or ""),
                "had_top_level_system": had_top_level_system,
                "had_inline_system_before": had_inline_system_before,
                "had_inline_system_after": had_inline_system_after,
                "had_instructions_before": had_instructions_before,
                "has_instructions_after": has_instructions_after,
                "removed_counts": removed_counts,
                "moved_system_preview": self._truncate(moved_system_text),
                "before_roles": before_roles,
                "after_roles": after_roles,
            }

            try:
                print("[SystemRoleRewrite] " + json.dumps(event, ensure_ascii=False), flush=True)
            except Exception as exc:
                print(f"[SystemRoleRewrite] log failure: {exc}", flush=True)

        async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
            model = data.get("model", "")
            if not self._is_chatgpt_route(model):
                return data

            # Claude Code can send Anthropic-only request metadata unsupported by chatgpt/* routes.
            data.pop("context_management", None)

            had_top_level_system = data.get("system") is not None
            had_inline_system_before = self._has_any_system_roles(data)
            had_instructions_before = data.get("instructions") is not None
            before_roles = {
                "messages": self._roles_for_key(data, "messages"),
                "input": self._roles_for_key(data, "input"),
            }

            moved_chunks = []
            removed_counts = {"messages": 0, "input": 0}

            # Anthropic Messages format: top-level `system`.
            system_content = data.pop("system", None)
            if system_content is not None:
                text = self._stringify_content(system_content).strip()
                if text:
                    moved_chunks.append(text)

            removed_counts["messages"], moved_from_messages = self._rewrite_role_items_to_instructions(data, "messages")
            removed_counts["input"], moved_from_input = self._rewrite_role_items_to_instructions(data, "input")
            moved_chunks.extend(moved_from_messages)
            moved_chunks.extend(moved_from_input)

            merged_instructions = self._merge_instructions(data.get("instructions"), moved_chunks)
            if merged_instructions:
                data["instructions"] = merged_instructions

            # Match pi's codex defaults more closely for tool-calling behavior.
            # LiteLLM's Anthropic adapter expects Anthropic-style tool_choice objects.
            tool_choice = data.get("tool_choice")
            if isinstance(tool_choice, str) and tool_choice in {"auto", "any", "none"}:
                data["tool_choice"] = {"type": tool_choice}
            if data.get("tools") and data.get("tool_choice") is None:
                data["tool_choice"] = {"type": "auto"}
            if data.get("tools") and data.get("parallel_tool_calls") is None:
                data["parallel_tool_calls"] = True

            include = data.get("include")
            if include is None:
                data["include"] = ["reasoning.encrypted_content"]
            elif isinstance(include, list) and "reasoning.encrypted_content" not in include:
                include.append("reasoning.encrypted_content")

            had_inline_system_after = self._has_any_system_roles(data)
            has_instructions_after = bool(data.get("instructions"))
            after_roles = {
                "messages": self._roles_for_key(data, "messages"),
                "input": self._roles_for_key(data, "input"),
            }

            if had_top_level_system or had_inline_system_before:
                self._log_rewrite_event(
                    model=model,
                    call_type=call_type,
                    had_top_level_system=had_top_level_system,
                    had_inline_system_before=had_inline_system_before,
                    had_inline_system_after=had_inline_system_after,
                    had_instructions_before=had_instructions_before,
                    has_instructions_after=has_instructions_after,
                    moved_system_text="\n\n".join(moved_chunks) if moved_chunks else None,
                    before_roles=before_roles,
                    after_roles=after_roles,
                    removed_counts=removed_counts,
                )

            return data


    proxy_handler_instance = SystemToInstructions()
  '';

  home.activation.ensureLiteLLMEnv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${litellmConfigDir}/chatgpt-tokens"
    chmod 700 "${litellmConfigDir}/chatgpt-tokens"

    env_file="${litellmEnvPath}"
    if [ ! -f "$env_file" ]; then
      mkdir -p "$(dirname "$env_file")"
      cat > "$env_file" <<'EOF'
# Required
LITELLM_MASTER_KEY=sk-your-generated-master-key

# Optional ChatGPT OAuth token storage overrides
# CHATGPT_TOKEN_DIR=/home/mfarver/.config/litellm/chatgpt-tokens
# CHATGPT_AUTH_FILE=auth.json
# CHATGPT_API_BASE=https://chatgpt.com/backend-api/codex

# Optional debug logging (shows rewrite event in journal)
# LITELLM_LOG_SYSTEM_REWRITE=1
EOF
      chmod 600 "$env_file"
      echo "Created $env_file with placeholders."
      echo "Then run: systemctl --user restart litellm-proxy && litellm-check"
      echo "If prompted, complete OAuth device flow from: journalctl --user -u litellm-proxy -f"
      echo "Use this to inspect mapped models: curl -sS -H \"Authorization: Bearer \$LITELLM_MASTER_KEY\" http://127.0.0.1:4000/v1/models | jq"
    fi
  '';

  home.packages = [
    (pkgs.writeShellScriptBin "litellm-check" ''
      set -euo pipefail

      env_file="${litellmEnvPath}"
      if [[ ! -f "$env_file" ]]; then
        echo "Missing $env_file. Add LITELLM_MASTER_KEY first." >&2
        exit 1
      fi

      set -a
      source "$env_file"
      set +a

      : "''${LITELLM_MASTER_KEY:?LITELLM_MASTER_KEY is required in $env_file}"

      # Use stream=true because LiteLLM 1.82.x has a known non-stream parse issue
      # on chatgpt/* responses routes (output=[] parser failure).
      resp=$(curl -sS -N -X POST "http://127.0.0.1:4000/v1/messages" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d '{
          "model": "codex",
          "max_tokens": 120,
          "stream": true,
          "system": "You are a helpful assistant. Reply with only the word OK.",
          "messages": [{"role": "user", "content": "Say hi"}]
        }')

      if echo "$resp" | grep -q 'event: message_stop'; then
        echo "OK    codex (streaming anthropic bridge healthy)"
      else
        echo "FAIL  codex -> unexpected streaming response"
        echo "$resp"
        exit 1
      fi
    '')

    (pkgs.writeShellScriptBin "litellm-probe-models" ''
      set -euo pipefail

      env_file="${litellmEnvPath}"
      if [[ ! -f "$env_file" ]]; then
        echo "Missing $env_file. Add LITELLM_MASTER_KEY first." >&2
        exit 1
      fi

      set -a
      source "$env_file"
      set +a

      : "''${LITELLM_MASTER_KEY:?LITELLM_MASTER_KEY is required in $env_file}"

      curl -sS -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        "http://127.0.0.1:4000/v1/models" | jq -r '.data[].id' | while read -r model; do
        resp=$(curl -sS -N -X POST "http://127.0.0.1:4000/v1/messages" \
          -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
          -H "Content-Type: application/json" \
          -d "{\"model\":\"$model\",\"max_tokens\":64,\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with only the word OK\"}]}")

        if echo "$resp" | grep -q 'event: message_stop'; then
          printf "OK    %s\n" "$model"
        else
          printf "FAIL  %s -> streaming response did not complete\n" "$model"
        fi
      done
    '')
  ];

  systemd.user.services.litellm-proxy = {
    Unit = {
      Description = "LiteLLM proxy for Claude Code (ChatGPT subscription backend)";
      After = [ "network.target" ];
    };

    Service = {
      Type = "simple";
      WorkingDirectory = litellmConfigDir;
      EnvironmentFile = [ litellmEnvPath ];
      Environment = [ "CHATGPT_TOKEN_DIR=${litellmConfigDir}/chatgpt-tokens" ];
      ExecStart = "${pkgs.litellm}/bin/litellm --config ${litellmConfigPath} --host 127.0.0.1 --port 4000";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = "10s";
      KillSignal = "SIGINT";
    };

    Install.WantedBy = [ "default.target" ];
  };

  programs.zsh.initContent = lib.mkAfter ''
    # Make Claude Code use the local LiteLLM proxy directly.
    if [[ -f "${litellmEnvPath}" ]]; then
      set -a
      source "${litellmEnvPath}"
      set +a

      if [[ -n "''${LITELLM_MASTER_KEY:-}" ]]; then
        export ANTHROPIC_BASE_URL="''${ANTHROPIC_BASE_URL:-http://127.0.0.1:4000}"
        # Prefer API key auth only to avoid token+key conflict warnings.
        unset ANTHROPIC_AUTH_TOKEN
        export ANTHROPIC_API_KEY="''${ANTHROPIC_API_KEY:-$LITELLM_MASTER_KEY}"
      fi
    fi
  '';
}
