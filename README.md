# GreedFrance Chatbot

Telegram-чатбот на базе [InterSystems IRIS](https://www.intersystems.com/products/iris/) Interoperability + Python [ChatterBot](https://github.com/gunthercox/ChatterBot).

Основан на [jrpereirajr/iris-chatbot](https://github.com/jrpereirajr/iris-chatbot), переименован и адаптирован под **GreedFrance**.

## Возможности

- Приём сообщений из Telegram через IRIS Interoperability production.
- Маршрутизация сообщений в бизнес-процесс `dc.greedfrance.ChatbotRouter`.
- Генерация ответов через Python ChatterBot (`dc.greedfrance.ToChatterbot`).
- Отправка ответа обратно в Telegram.
- Готовая структура для расширения: модерация чата, статистика, команды, свои правила.

## Что внутри

- `dc.greedfrance.GreedFranceProduction` — production IRIS.
- `FromTelegram` — входящие сообщения из Telegram.
- `ChatbotRouter` — маршрутизация.
- `ToChatterbot` — ответы через ChatterBot.
- `ToTelegram` — отправка сообщений в Telegram.

## Требования

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Docker Desktop](https://www.docker.com/products/docker-desktop) / Docker + Docker Compose

## Запуск через Docker

```bash
git clone <URL_ВАШЕГО_РЕПО>
cd greedfrance-chatbot
docker-compose build
docker-compose up -d
```

После запуска IRIS будет доступен на порту `55038` (Management Portal: `http://localhost:55038/csp/sys/UtilHome.csp`).

## Настройка Telegram-бота

1. Создай бота у [@BotFather](https://telegram.me/BotFather): `/newbot`, задай имя и username, сохрани токен.
2. В IRIS создай Credentials: `http://localhost:55038/csp/user/EnsPortal.Credentials.zen?$NAMESPACE=USER&$NAMESPACE=USER&`  
   - `ID`: например `telegram`
   - `Password`: токен бота
3. Открой Production: `http://localhost:55038/csp/user/EnsPortal.ProductionConfig.zen?PRODUCTION=dc.greedfrance.GreedFranceProduction`
4. В `FromTelegram` и `ToTelegram` выбери созданный Credentials, нажми `Apply`.
5. Запусти Production. Напиши боту в Telegram — он должен ответить.

## Тесты

```bash
iris session iris "##class(%ZPM.PackageManager).Shell(\"test greedfrance-chatbot -v\",1,1)"
```

## ZPM

```objectscript
USER>zpm "install greedfrance-chatbot"
```

## Бесплатный хостинг (варианты)

IRIS + Docker тяжёлый, полностью бесплатного always-on варианта мало. Реальные варианты:

- **GitHub Codespaces** — бесплатные часы на аккаунт, удобно для теста/демо.
- **Oracle Cloud Always Free** — бесплатная VM, можно поставить Docker и поднять контейнер (нужна настройка).
- **Render/Railway/Fly.io** — обычно платно/ограничено для Docker-нагрузки такого типа; проверяй текущие лимиты.

Для постоянной работы лучше небольшой VPS.

## Лицензия

MIT (см. [LICENSE](./LICENSE)). Оригинал: [jrpereirajr/iris-chatbot](https://github.com/jrpereirajr/iris-chatbot).
