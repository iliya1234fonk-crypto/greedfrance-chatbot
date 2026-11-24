/// Модерация групп RecodeGram/Telegram: баны, муты, предупреждения, удаление сообщений.
Class dc.greedfrance.Moderator Extends %RegisteredObject
{

Property API As Telegram.API [ Private ];

Parameter CREDENTIALSID = "telegram";

Parameter MAXWARNS = 3;

Method %OnNew() As %Status
{
	set cred = ##class(Ens.Config.Credentials).%OpenId(..#CREDENTIALSID)
	if '$isobject(cred) {
		quit $$$ERROR($$$GeneralError, "Credentials '" _ ..#CREDENTIALSID _ "' not found")
	}
	set ..API = ##class(Telegram.API).%New(cred.Password, "")
	if '$isobject(..API) {
		quit $$$ERROR($$$GeneralError, "Cannot create Telegram API object")
	}
	quit $$$OK
}

Method Send(chatId As %String, text As %String, replyTo As %String = "") As %Status
{
	set form = {}
	set form.chat_id = chatId
	set form.text = text
	set form.parse_mode = "HTML"
	if (replyTo '= "") {
		set form.reply_to_message_id = replyTo
	}
	do ..API.CallMethod("sendMessage", form)
	quit $$$OK
}

Method IsAdmin(chatId As %String, userId As %String) As %Boolean
{
	set form = {}
	set form.chat_id = chatId
	set form.user_id = userId
	set res = ..API.CallMethod("getChatMember", form)
	if ('res.ok) {
		quit 0
	}
	set status = res.result.status
	quit ((status = "creator") || (status = "administrator"))
}

Method SendReply(chatId As %String, text As %String, replyTo As %String)
{
	do ..Send(chatId, text, replyTo)
}

/// Разбор цели команды: ответ на сообщение или числовой id/упоминание в аргументе.
Method TargetUserId(msg As %DynamicObject, arg As %String) As %String
{
	if ($isobject(msg.reply_to_message)) {
		if ($isobject(msg.reply_to_message.from)) {
			quit msg.reply_to_message.from.id
		}
	}
	if (arg '= "") {
		set arg = $zstrip(arg, "<>W")
		if (+arg > 0) {
			quit +arg
		}
		if ($isobject(msg.entities)) {
			for i = 0:1:(msg.entities.%Size() - 1) {
				set ent = msg.entities.%Get(i)
				if (ent.type = "text_mention") {
					if ($isobject(ent.user)) {
						quit ent.user.id
					}
				}
			}
		}
	}
	quit ""
}

/// Возвращает 1, если сообщение обработано модератором.
Method Handle(msg As %DynamicObject) As %Boolean
{
	set text = ""
	if (msg.text '= "") {
		set text = msg.text
	}
	if ($extract(text) '= "/") {
		quit 0
	}

	set chatId = msg.chat.id
	set fromId = msg.from.id
	set messageId = msg.message_id

	set raw = $extract(text, 2, *)
	set cmd = $zconvert($piece($piece(raw, " ", 1), "@", 1), "L")
	set arg = $piece(raw, " ", 2)

	// Команды, доступные всем
	if ((cmd = "start") || (cmd = "help")) || (cmd = "modhelp") {
		do ..Send(chatId, ..HelpText())
		quit 1
	}
	if (cmd = "warns") {
		set target = ..TargetUserId(msg, arg)
		if (target = "") {
			set target = fromId
		}
		do ..Send(chatId, "Предупреждений: "_..WarnCount(chatId, target))
		quit 1
	}

	// Дальше только для админов
	if ('..IsAdmin(chatId, fromId)) {
		do ..Send(chatId, "⛔ Эта команда только для админов группы", messageId)
		quit 1
	}

	if (cmd = "del") || (cmd = "delete") {
		if ($isobject(msg.reply_to_message)) {
			set form = {}
			set form.chat_id = chatId
			set form.message_id = msg.reply_to_message.message_id
			do ..API.CallMethod("deleteMessage", form)
			set form = {}
			set form.chat_id = chatId
			set form.message_id = messageId
			do ..API.CallMethod("deleteMessage", form)
		} else {
			do ..Send(chatId, "Ответь на сообщение, которое надо удалить", messageId)
		}
		quit 1
	}

	set target = ..TargetUserId(msg, arg)
	if (target = "") {
		do ..Send(chatId, "Ответь на сообщение участника или укажи его числовой id", messageId)
		quit 1
	}

	if (cmd = "ban") {
		do ..Ban(chatId, target)
		do ..Send(chatId, "🔨 Забанен: "_target)
		quit 1
	}
	if (cmd = "unban") {
		do ..Unban(chatId, target)
		do ..Send(chatId, "✅ Разбанен: "_target)
		quit 1
	}
	if (cmd = "kick") {
		do ..Kick(chatId, target)
		do ..Send(chatId, "👢 Кикнут: "_target)
		quit 1
	}
	if (cmd = "mute") {
		do ..Mute(chatId, target)
		do ..Send(chatId, "🔇 Замучен: "_target)
		quit 1
	}
	if (cmd = "unmute") {
		do ..Unmute(chatId, target)
		do ..Send(chatId, "🔊 Размучен: "_target)
		quit 1
	}
	if (cmd = "warn") {
		set cnt = ..AddWarn(chatId, target)
		if (cnt >= ..#MAXWARNS) {
			do ..Kick(chatId, target)
			do ..ResetWarns(chatId, target)
			do ..Send(chatId, "⚠️ "_target_" получил "_cnt_" предупреждений и кикнут")
		} else {
			do ..Send(chatId, "⚠️ Предупреждение "_cnt_" из "_..#MAXWARNS_" для "_target)
		}
		quit 1
	}
	if (cmd = "unwarn") || (cmd = "resetwarns") {
		do ..ResetWarns(chatId, target)
		do ..Send(chatId, "♻️ Предупреждения сброшены: "_target)
		quit 1
	}

	do ..Send(chatId, "Неизвестная команда. /help — список команд", messageId)
	quit 1
}

ClassMethod Ban(chatId As %String, userId As %String)
{
	set api = ..GetAPI()
	set form = {}
	set form.chat_id = chatId
	set form.user_id = userId
	set form.revoke_messages = 1
	do api.CallMethod("banChatMember", form)
}

ClassMethod Unban(chatId As %String, userId As %String)
{
	set api = ..GetAPI()
	set form = {}
	set form.chat_id = chatId
	set form.user_id = userId
	set form.only_if_banned = 1
	do api.CallMethod("unbanChatMember", form)
}

ClassMethod Kick(chatId As %String, userId As %String)
{
	do ..Ban(chatId, userId)
	do ..Unban(chatId, userId)
}

ClassMethod Mute(chatId As %String, userId As %String)
{
	set api = ..GetAPI()
	set form = {}
	set form.chat_id = chatId
	set form.user_id = userId
	set form.permissions = {"can_send_messages":false,"can_send_audios":false,"can_send_documents":false,"can_send_photos":false,"can_send_videos":false,"can_send_video_notes":false,"can_send_voice_notes":false,"can_send_polls":false,"can_send_other_messages":false,"can_add_web_page_previews":false,"can_change_info":false,"can_invite_users":false,"can_pin_messages":false,"can_manage_topics":false}
	do api.CallMethod("restrictChatMember", form)
}

ClassMethod Unmute(chatId As %String, userId As %String)
{
	set api = ..GetAPI()
	set form = {}
	set form.chat_id = chatId
	set form.user_id = userId
	set form.permissions = {"can_send_messages":true,"can_send_audios":true,"can_send_documents":true,"can_send_photos":true,"can_send_videos":true,"can_send_video_notes":true,"can_send_voice_notes":true,"can_send_polls":true,"can_send_other_messages":true,"can_add_web_page_previews":true,"can_change_info":false,"can_invite_users":true,"can_pin_messages":false,"can_manage_topics":false}
	do api.CallMethod("restrictChatMember", form)
}

ClassMethod GetAPI() As Telegram.API
{
	set cred = ##class(Ens.Config.Credentials).%OpenId("telegram")
	quit ##class(Telegram.API).%New(cred.Password, "")
}

ClassMethod WarnCount(chatId As %String, userId As %String) As %Integer
{
	quit +$get(^GreedWarn(chatId, userId))
}

ClassMethod AddWarn(chatId As %String, userId As %String) As %Integer
{
	set ^GreedWarn(chatId, userId) = ..WarnCount(chatId, userId) + 1
	quit ^GreedWarn(chatId, userId)
}

ClassMethod ResetWarns(chatId As %String, userId As %String)
{
	kill ^GreedWarn(chatId, userId)
}

ClassMethod HelpText() As %String
{
	quit "<b>GreedFrance — модерация группы</b>"_$c(10)
		_ "/ban — забанить (ответом на сообщение или по id)"_$c(10)
		_ "/unban — разбанить"_$c(10)
		_ "/kick — выгнать из группы"_$c(10)
		_ "/mute — запретить писать"_$c(10)
		_ "/unmute — снять мут"_$c(10)
		_ "/warn — предупреждение (3 = кик)"_$c(10)
		_ "/unwarn — сбросить предупреждения"_$c(10)
		_ "/warns — сколько предупреждений"_$c(10)
		_ "/del — удалить сообщение (ответом на него)"_$c(10)
		_ "<i>Команды админов работают только у админов группы.</i>"
}

}
