# Что попросить у владельца Bot API RecodeGram

Бот `@greedfrance_robot` не может банить, мутить и закреплять сообщения не из-за прав
администратора в группе, а потому что сервер Bot API (`http://31.77.232.21:2500`)
не реализует эти методы: на любой из них он отвечает

```json
{"description":"METHOD_NOT_FOUND","error_code":404,"ok":false}
```

Права администратора в группе выдать можно — это ничего не изменит, метод всё равно 404.

## Текст для владельца сервера

> Привет. Нужны методы администрирования в Bot API (`31.77.232.21:2500`), сейчас они отвечают `METHOD_NOT_FOUND`:
>
> - `banChatMember`, `unbanChatMember`
> - `restrictChatMember` (мут)
> - `getChatAdministrators`, `getChatMember`, `getChat`
> - `pinChatMessage`, `unpinChatMessage`
> - `promoteChatMember`, `setChatPermissions`, `leaveChat`
>
> Без них ни один бот в RecodeGram не сможет модерировать группу, даже с правами админа.
> Сейчас работают только: `sendMessage`, `editMessageText`, `deleteMessage`, медиа, `getUpdates`, `setWebhook`, `getFile`.

## Как проверить самому

```sh
python3 tools/check_bot_api.py 1780243564:ТОКЕН
```

Скрипт печатает каждый метод и отвечает «есть» или «НЕТ».
