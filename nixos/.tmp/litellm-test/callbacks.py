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

        for key in ("messages", "input"):
            items = data.get(key)
            if isinstance(items, list):
                for msg in items:
                    if isinstance(msg, dict) and msg.get("role") == "system":
                        msg["role"] = "developer"

        return data


proxy_handler_instance = SystemToDeveloper()
