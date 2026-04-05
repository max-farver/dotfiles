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
      # Models confirmed available for your account (plus requested mini model).
      - model_name: chatgpt/gpt-5.4
        model_info:
          mode: responses
        litellm_params:
          model: chatgpt/gpt-5.4

      - model_name: chatgpt/gpt-5.4-mini
        model_info:
          mode: responses
        litellm_params:
          model: chatgpt/gpt-5.4-mini

      - model_name: chatgpt/gpt-5.3-codex
        model_info:
          mode: responses
        litellm_params:
          model: chatgpt/gpt-5.3-codex

      # Convenience aliases for Claude Code usage.
      - model_name: codex
        model_info:
          mode: responses
        litellm_params:
          model: chatgpt/gpt-5.3-codex

      - model_name: gpt-5.4
        model_info:
          mode: responses
        litellm_params:
          model: chatgpt/gpt-5.4

      - model_name: gpt-5.4-mini
        model_info:
          mode: responses
        litellm_params:
          model: chatgpt/gpt-5.4-mini

    router_settings:
      num_retries: 2
      timeout: 30

    litellm_settings:
      master_key: os.environ/LITELLM_MASTER_KEY
      # Workaround for ChatGPT/Codex rejecting `system` role on some routes.
      # Ref: https://github.com/BerriAI/litellm/issues/21420
      callbacks:
        - callbacks.proxy_handler_instance
      drop_params: true
      fallbacks:
        - {"codex": ["gpt-5.4", "gpt-5.4-mini"]}
        - {"gpt-5.4": ["gpt-5.4-mini"]}
  '';

  xdg.configFile."litellm/callbacks.py".text = ''
    from litellm.integrations.custom_logger import CustomLogger


    class SystemToDeveloper(CustomLogger):
        _chatgpt_aliases = {
            "codex",
            "gpt-5.4",
            "gpt-5.4-mini",
        }

        def _is_chatgpt_route(self, model):
            model = str(model or "")
            return (
                model.startswith("chatgpt/")
                or model in self._chatgpt_aliases
                or model.startswith("gpt-5")
            )

        def _stringify_system_content(self, system_content):
            if isinstance(system_content, str):
                return system_content

            if isinstance(system_content, list):
                parts = []
                for block in system_content:
                    if isinstance(block, str):
                        parts.append(block)
                    elif isinstance(block, dict):
                        if isinstance(block.get("text"), str):
                            parts.append(block["text"])
                        elif isinstance(block.get("content"), str):
                            parts.append(block["content"])
                if parts:
                    return "\n\n".join(parts)

            return str(system_content)

        async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
            model = data.get("model", "")
            if not self._is_chatgpt_route(model):
                return data

            # Anthropic Messages format (e.g. Claude Code): top-level `system`.
            system_content = data.pop("system", None)
            if system_content:
                messages = data.get("messages")
                if not isinstance(messages, list):
                    messages = []
                messages.insert(
                    0,
                    {
                        "role": "developer",
                        "content": self._stringify_system_content(system_content),
                    },
                )
                data["messages"] = messages

            # Chat Completions / Responses-style payloads.
            for key in ("messages", "input"):
                items = data.get(key)
                if isinstance(items, list):
                    for msg in items:
                        if isinstance(msg, dict) and msg.get("role") == "system":
                            msg["role"] = "developer"

            return data


    proxy_handler_instance = SystemToDeveloper()
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
EOF
      chmod 600 "$env_file"
      echo "Created $env_file with placeholders."
      echo "Then run: systemctl --user restart litellm-proxy && litellm-check"
      echo "If prompted, complete OAuth device flow from: journalctl --user -u litellm-proxy -f"
      echo "Use this to inspect mapped models: curl -sS -H \"Authorization: Bearer \$LITELLM_MASTER_KEY\" http://127.0.0.1:4000/v1/models | jq"
    fi
  '';

  home.packages = [
    (pkgs.writeShellScriptBin "claude-litellm" ''
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
      export ANTHROPIC_BASE_URL="''${ANTHROPIC_BASE_URL:-http://127.0.0.1:4000}"
      # Set only API key auth for Claude Code to avoid token+key conflict warnings.
      unset ANTHROPIC_AUTH_TOKEN
      export ANTHROPIC_API_KEY="''${ANTHROPIC_API_KEY:-$LITELLM_MASTER_KEY}"

      # Avoid conflicting global ~/.claude/settings.json env overrides.
      if [[ " $* " == *" --setting-sources "* ]]; then
        exec claude "$@"
      else
        exec claude --setting-sources project,local "$@"
      fi
    '')

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

      curl -sS -X POST "http://127.0.0.1:4000/v1/messages" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d '{
          "model": "gpt-5.4",
          "max_tokens": 120,
          "system": "You are a helpful assistant. Reply with only the word OK.",
          "messages": [{"role": "user", "content": "Say hi"}]
        }'
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
        resp=$(curl -sS -X POST "http://127.0.0.1:4000/v1/messages" \
          -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
          -H "Content-Type: application/json" \
          -d "{\"model\":\"$model\",\"max_tokens\":64,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with only the word OK\"}]}")

        if echo "$resp" | jq -e '.error' >/dev/null; then
          printf "FAIL  %s -> %s\n" "$model" "$(echo "$resp" | jq -r '.error.message')"
        else
          printf "OK    %s\n" "$model"
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

  programs.zsh.shellAliases = {
    cc = "claude-litellm";
  };
}
