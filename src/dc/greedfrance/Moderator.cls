/// Модерация групп в RecodeGram (режим по реальным возможностям Bot API).
///
/// В Bot API RecodeGram НЕТ: banChatMember, restrictChatMember, getChatMember,
/// getChatAdministrators, pinChatMessage. Есть: sendMessage, deleteMessage,
/// editMessageText, getUpdates, getMe.
///
/// Поэтому модерация построена на удалении сообщений и предупреждениях.
/// Команды бана/мута всё равно вызываются: если сервер их включит — заработают
/// сами, а пока бот честно отвечает, что сервер это не поддерживает.
Class dc.greedfrance.Moderator Extends %RegisteredObject
{

Parameter CREDENTIALSID = "telegram";

/// Сколько предупреждений до попытки кика
Parameter MAXWARNS = 3;

/// Антифлуд: столько сообщений за окно = флуд
Parameter FLOODCOUNT = 6;

Parameter FLOODWINDOW = 10;

Property API As Telegram.API [ Private ];

Method %OnNew() As %Status
{
	set cred = ##class(Ens.Config.Credentials).%OpenId(..#CREDENTIALSID)
	if '$isobject(cred) {
		quit $system.Status.Error(5001, "Credentials '"_..#CREDENTIALSID_"' not found")
	}
	set ..API = ##class(Telegram.API).%New(cred.Password, "")
	if '$isobject(..API) {
		quit $system.Status.Error(5001, "Cannot create Telegram API object")
	}
	quit $$$OK
}

// ---------------------------------------------------------------- helpers

ClassMethod Now() As %Integer
{
	quit ($piece($horolog, ",", 1) * 86400) + $piece($horolog, ",", 2)
}

ClassMethod Short(res As %DynamicObject) As %String
{
	set d = ""
	if $isobject(res) {
		set d = res.description
		if (d '= "") {
			set d = $extract($zstrip($zconvert(d, "O", "HTML"), "<>W"), 1, 90)
		}
	}
	quit d
}

// ---------------------------------------------------------------- отправка

Method Send(chatId As %String, text As %String, replyTo As %String = "") As %DynamicObject
{
	set form = {}
	do form.%Set("chat_id", chatId)
	do form.%Set("parse_mode", "HTML")
	do form.%Set("text", ##class(dc.greedfrance.Emoji).Render($extract(text, 1, 3800)))
	if (replyTo '= "") {
		do form.%Set("reply_to_message_id", replyTo)
	}
	quit ..API.CallMethod("sendMessage", form)
}

Method DeleteMessage(chatId As %String, messageId As %String) As %Boolean
{
	if (messageId = "") {
		quit 0
	}
	set form = {}
	do form.%Set("chat_id", chatId)
	do form.%Set("message_id", messageId)
	set res = ..API.CallMethod("deleteMessage", form)
	quit (+res.ok = 1)
}

// ---------------------------------------------------------------- права

/// 1 — админ, 0 — нет, -1 — сервер не умеет проверять
Method AdminState(chatId As %String, userId As %String) As %Integer
{
	set form = {}
	do form.%Set("chat_id", chatId)
	do form.%Set("user_id", userId)
	set res = ..API.CallMethod("getChatMember", form)
	if (+res.ok '= 1) {
		quit -1
	}
	set status = ""
	if $isobject(res.result) {
		set status = res.result.status
	}
	quit ((status = "creator") || (status = "administrator"))
}

/// Проверка прав. Если API не умеет getChatMember — доверяем реестру
/// ^GreedAdmin(chatId, userId). Первый, кто выполнил команду, становится
/// админом (иначе бота нельзя было бы настроить вообще).
Method IsAdmin(chatId As %String, userId As %String) As %Boolean
{
	set st = ..AdminState(chatId, userId)
	if (st >= 0) {
		if (st = 1) {
			set ^GreedAdmin(chatId, userId) = 1
		}
		quit st
	}
	if $data(^GreedAdmin(chatId, userId)) {
		quit 1
	}
	if '$data(^GreedAdmin(chatId)) {
		set ^GreedAdmin(chatId, userId) = 1
		quit 1
	}
	quit 0
}

// ---------------------------------------------------------------- состояние

ClassMethod WarnCount(chatId As %String, userId As %String) As %Integer
{
	quit +$get(^GreedWarn(chatId, userId))
}

ClassMethod ResetWarns(chatId As %String, userId As %String)
{
	kill ^GreedWarn(chatId, userId)
}

ClassMethod Touch(chatId As %String, userId As %String)
{
	set ^GreedStats(chatId, "all") = +$get(^GreedStats(chatId, "all")) + 1
	set day = $zd($horolog, 3)
	set ^GreedStats(chatId, "day", day) = +$get(^GreedStats(chatId, "day", day)) + 1
	set ^GreedStats(chatId, "user", userId) = +$get(^GreedStats(chatId, "user", userId)) + 1
}

Method Flood(chatId As %String, userId As %String) As %Boolean
{
	set now = ..Now()
	set start = $get(^GreedFlood(chatId, userId, "t"))
	set cnt = +$get(^GreedFlood(chatId, userId, "c"))
	if ((start = "") || ((now - start) > ..#FLOODWINDOW)) {
		set ^GreedFlood(chatId, userId, "t") = now
		set ^GreedFlood(chatId, userId, "c") = 1
		quit 0
	}
	set cnt = cnt + 1
	set ^GreedFlood(chatId, userId, "c") = cnt
	quit (cnt > ..#FLOODCOUNT)
}

// ---------------------------------------------------------------- действия

Method TryBan(chatId As %String, userId As %String) As %String
{
	set form = {}
	do form.%Set("chat_id", chatId)
	do form.%Set("user_id", userId)
	do form.%Set("revoke_messages", 1)
	set res = ..API.CallMethod("banChatMember", form)
	if (+res.ok = 1) {
		quit "😡 Забанен."
	}
	quit "⚠️ Сервер не поддерживает banChatMember."
}

Method TryUnban(chatId As %String, userId As %String) As %String
{
	set form = {}
	do form.%Set("chat_id", chatId)
	do form.%Set("user_id", userId)
	do form.%Set("only_if_banned", 1)
	set res = ..API.CallMethod("unbanChatMember", form)
	if (+res.ok = 1) {
		quit "🙂 Разбанен."
	}
	quit "⚠️ Сервер не поддерживает unbanChatMember."
}

Method TryKick(chatId As %String, userId As %String) As %String
{
	set form = {}
	do form.%Set("chat_id", chatId)
	do form.%Set("user_id", userId)
	do form.%Set("revoke_messages", 1)
	set res = ..API.CallMethod("banChatMember", form)
	if (+res.ok = 1) {
		set form2 = {}
		do form2.%Set("chat_id", chatId)
		do form2.%Set("user_id", userId)
		do form2.%Set("only_if_banned", 1)
		do ..API.CallMethod("unbanChatMember", form2)
		quit "💔 Кикнут."
	}
	quit "⚠️ Сервер не поддерживает кик/бан."
}

Method TryMute(chatId As %String, userId As %String) As %String
{
	set form = {}
	do form.%Set("chat_id", chatId)
	do form.%Set("user_id", userId)
	do form.%Set("permissions", {"can_send_messages":false,"can_send_audios":false,"can_send_documents":false,"can_send_photos":false,"can_send_videos":false,"can_send_video_notes":false,"can_send_voice_notes":false,"can_send_polls":false,"can_send_other_messages":false,"can_add_web_page_previews":false,"can_invite_users":false,"can_pin_messages":false})
	set res = ..API.CallMethod("restrictChatMember", form)
	if (+res.ok = 1) {
		quit "💤 Замучен."
	}
	quit "⚠️ Сервер не поддерживает restrictChatMember."
}

Method TryUnmute(chatId As %String, userId As %String) As %String
{
	set form = {}
	do form.%Set("chat_id", chatId)
	do form.%Set("user_id", userId)
	do form.%Set("permissions", {"can_send_messages":true,"can_send_audios":true,"can_send_documents":true,"can_send_photos":true,"can_send_videos":true,"can_send_video_notes":true,"can_send_voice_notes":true,"can_send_polls":true,"can_send_other_messages":true,"can_add_web_page_previews":true,"can_invite_users":true})
	set res = ..API.CallMethod("restrictChatMember", form)
	if (+res.ok = 1) {
		quit "🙂 Размучен."
	}
	quit "⚠️ Сервер не поддерживает restrictChatMember."
}

/// Предупреждение. На MAXWARNS — попытка кика и сброс счётчика.
Method Warn(chatId As %String, userId As %String, reason As %String = "") As %Integer
{
	set cnt = ..WarnCount(chatId, userId) + 1
	set ^GreedWarn(chatId, userId) = cnt
	set suffix = ""
	if (reason '= "") {
		set suffix = " ("_reason_")"
	}
	if (cnt >= ..#MAXWARNS) {
		set res = ..TryKick(chatId, userId)
		do ..ResetWarns(chatId, userId)
		do ..Send(chatId, "⚠️ "_userId_" — "_cnt_" предупреждений"_suffix_". "_res)
	} else {
		do ..Send(chatId, "⚠️ "_userId_" — предупреждение "_cnt_" из "_..#MAXWARNS_suffix)
	}
	quit cnt
}

// ---------------------------------------------------------------- разбор

/// Кого наказываем: автор сообщения, на которое ответили, или число/упоминание.
Method TargetUserId(msg As %DynamicObject, arg As %String) As %String
{
	if $isobject(msg.reply_to_message) {
		if $isobject(msg.reply_to_message.from) {
			quit msg.reply_to_message.from.id
		}
	}
	set arg = $zstrip(arg, "<>W")
	if (+arg > 0) {
		quit +arg
	}
	if $isobject(msg.entities) {
		for i = 0:1:(msg.entities.%Size() - 1) {
			set ent = msg.entities.%Get(i)
			if ((ent.type = "text_mention") && $isobject(ent.user)) {
				quit ent.user.id
			}
		}
	}
	quit ""
}

// ---------------------------------------------------------------- точка входа

/// Возвращает 1, если сообщение обработано модератором.
Method Handle(msg As %DynamicObject) As %Boolean
{
	if '$isobject(msg) {
		quit 0
	}
	if '$isobject(msg.chat) {
		quit 0
	}
	set chatId = msg.chat.id
	set fromId = ""
	if $isobject(msg.from) {
		set fromId = msg.from.id
	}
	if (fromId = "") {
		quit 0
	}
	// ботов не модерируем
	if (+msg.from.is_bot = 1) {
		quit 0
	}

	set text = ""
	if '$isobject(msg.text) {
		set text = msg.text
	}

	// новые участники — приветствие
	if $isobject(msg.new_chat_members) {
		do ..Welcome(chatId, msg.new_chat_members)
		quit 1
	}

	do ..Touch(chatId, fromId)

	// антифлуд: удаляем лишнее и выдаём предупреждение
	if ..Flood(chatId, fromId) {
		do ..DeleteMessage(chatId, msg.message_id)
		do ..Warn(chatId, fromId, "флуд")
		quit 1
	}

	if ($extract(text) '= "/") {
		quit 0
	}

	set messageId = msg.message_id
	set raw = $extract(text, 2, *)
	set cmd = $zconvert($piece($piece(raw, " ", 1), "@", 1), "L")
	set arg = $zstrip($piece(raw, " ", 2, *), "<>W")

	// команды для всех
	if ((cmd = "start") || (cmd = "help") || (cmd = "modhelp")) {
		do ..Send(chatId, ..HelpText())
		quit 1
	}
	if (cmd = "rules") {
		do ..Send(chatId, ..RulesText())
		quit 1
	}
	if (cmd = "id") {
		do ..Send(chatId, "😯 chat_id: "_chatId_$c(10)_"user_id: "_fromId_$c(10)_"тип: "_msg.chat.type)
		quit 1
	}
	if (cmd = "stats") {
		do ..Send(chatId, ..StatsText(chatId))
		quit 1
	}
	if (cmd = "warns") {
		set target = ..TargetUserId(msg, arg)
		if (target = "") {
			set target = fromId
		}
		do ..Send(chatId, "Предупреждений у "_target_": "_..WarnCount(chatId, target))
		quit 1
	}

	// дальше — только админы
	if ('..IsAdmin(chatId, fromId)) {
		do ..Send(chatId, "😡 Команда только для админов группы.", messageId)
		quit 1
	}

	if ((cmd = "del") || (cmd = "delete")) {
		if $isobject(msg.reply_to_message) {
			do ..DeleteMessage(chatId, msg.reply_to_message.message_id)
			do ..DeleteMessage(chatId, messageId)
		} else {
			do ..Send(chatId, "Ответь на сообщение, которое надо удалить.", messageId)
		}
		quit 1
	}

	set target = ..TargetUserId(msg, arg)
	if (target = "") {
		do ..Send(chatId, "Ответь на сообщение участника или укажи его числовой id.", messageId)
		quit 1
	}

	if (cmd = "warn") {
		do ..Warn(chatId, target, "решение админа")
		quit 1
	}
	if ((cmd = "unwarn") || (cmd = "resetwarns")) {
		do ..ResetWarns(chatId, target)
		do ..Send(chatId, "🙂 Предупреждения сброшены: "_target)
		quit 1
	}
	if (cmd = "ban") {
		do ..Send(chatId, ..TryBan(chatId, target))
		quit 1
	}
	if (cmd = "unban") {
		do ..Send(chatId, ..TryUnban(chatId, target))
		quit 1
	}
	if (cmd = "kick") {
		do ..Send(chatId, ..TryKick(chatId, target))
		quit 1
	}
	if (cmd = "mute") {
		do ..Send(chatId, ..TryMute(chatId, target))
		quit 1
	}
	if (cmd = "unmute") {
		do ..Send(chatId, ..TryUnmute(chatId, target))
		quit 1
	}
	if (cmd = "trust") {
		set ^GreedAdmin(chatId, target) = 1
		do ..Send(chatId, "😎 "_target_" теперь может пользоваться командами бота.")
		quit 1
	}

	do ..Send(chatId, "❓ Неизвестная команда. /help — список команд", messageId)
	quit 1
}

Method Welcome(chatId As %String, members As %DynamicObject)
{
	set names = ""
	for i = 0:1:(members.%Size() - 1) {
		set m = members.%Get(i)
		set name = m.first_name
		if (m.username '= "") {
			set name = "@"_m.username
		}
		if (names = "") {
			set names = name
		} else {
			set names = names_", "_name
		}
	}
	if (names = "") {
		quit
	}
	do ..Send(chatId, "👋 Добро пожаловать, "_names_"!"_$c(10)_"Правила: /rules")
}

ClassMethod StatsText(chatId As %String) As %String
{
	set day = $zd($horolog, 3)
	set warns = 0
	set uid = ""
	for {
		set uid = $order(^GreedWarn(chatId, uid))
		quit:(uid = "")
		set warns = warns + ..WarnCount(chatId, uid)
	}
	quit "😎 Статистика чата"_$c(10)
		_"сообщений всего: "_+$get(^GreedStats(chatId, "all"))_$c(10)
		_"сегодня: "_+$get(^GreedStats(chatId, "day", day))_$c(10)
		_"предупреждений: "_warns
}

ClassMethod RulesText() As %String
{
	quit "☺️ Правила чата"_$c(10)
		_"1. Без спама и флуда."_$c(10)
		_"2. Без оскорблений и травли."_$c(10)
		_"3. Реклама — только с разрешения админов."_$c(10)
		_"4. Не повторяй одно и то же сообщение."_$c(10)_$c(10)
		_"Нарушения: предупреждение, дальше — бан."
}

ClassMethod HelpText() As %String
{
	quit "❓ GreedFrance — модерация"_$c(10)
		_"/help — команды"_$c(10)
		_"/rules — правила чата"_$c(10)
		_"/id — chat_id и твой id"_$c(10)
		_"/stats — статистика"_$c(10)
		_"/warn — предупреждение (ответом на сообщение)"_$c(10)
		_"/warns — сколько предупреждений"_$c(10)
		_"/unwarn — сбросить предупреждения"_$c(10)
		_"/del — удалить сообщение (ответом на него)"_$c(10)
		_"/ban /unban /kick /mute /unmute — если сервер поддерживает"_$c(10)
		_"/trust — разрешить участнику команды бота"_$c(10)_$c(10)
		_"💤 Антифлуд включён: "_..#FLOODCOUNT_" сообщений за "_..#FLOODWINDOW_" сек — удаление и предупреждение."
}

}
