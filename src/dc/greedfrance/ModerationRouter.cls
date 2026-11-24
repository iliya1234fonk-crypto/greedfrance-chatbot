/// Модератор групп + команды.
/// Стоит перед ChatbotRouter: сам обрабатывает команды, антиспам и приветствия,
/// а обычный текст передаёт в ChatbotRouter (ChatterBot).
Class dc.greedfrance.ModerationRouter Extends Ens.BusinessProcess
{

/// Сколько сообщений за окно считаются флудом
Parameter FLOODCOUNT = 6;

/// Окно антифлуда, секунды
Parameter FLOODWINDOW = 10;

/// Сколько предупреждений до "предела"
Parameter WARNLIMIT = 3;

/// Главный обработчик
Method OnRequest(pRequest As dc.greedfrance.TelegramRequest, Output pResponse As dc.greedfrance.TelegramResponse) As %Status
{
	set pResponse = ##class(dc.greedfrance.TelegramResponse).%New()
	set pResponse.ResponseChatId = pRequest.RequestChatId
	set pResponse.ResponseText = "OK"

	try {
		set chatId = pRequest.RequestChatId
		set userId = pRequest.UserId
		set chatType = pRequest.ChatType
		set text = $ZSTRIP(pRequest.RequestText,"<>W")

		do ..CountStats(chatId)

		if (pRequest.IsJoin) {
			do ..Welcome(pRequest)
			quit $$$OK
		}

		if (text="") {
			quit $$$OK
		}

		if ($Extract(text,1)="/") {
			do ..HandleCommand(pRequest,$ZCONVERT(text,"L"))
			quit $$$OK
		}

		if ((chatType="group")||(chatType="supergroup")) {
			if (..IsFlood(chatId,userId)) {
				do ..PunishSpam(pRequest)
				quit $$$OK
			}
		}

		// обычный текст — отдаём в ChatterBot (BPL сам отправит ответ в чат)
		set tSC = ..SendRequestSync("ChatbotRouter",pRequest,.tChatbotResponse)
		if $$$ISERR(tSC) {
			do ..Reply(chatId,"Не смог получить ответ от ChatterBot. Попробуй ещё раз позже.")
			quit $$$OK
		}
		if $IsObject(tChatbotResponse) {
			set pResponse.ResponseText = tChatbotResponse.ResponseText
			set pResponse.ResponseChatId = tChatbotResponse.ResponseChatId
		}
		quit $$$OK
	}
	catch e {
		return e.AsStatus()
	}
}

/// Разбор команд
Method HandleCommand(pRequest As dc.greedfrance.TelegramRequest, lowered As %String) As %Status
{
	set chatId = pRequest.RequestChatId
	set word = $Piece(lowered," ",1)
	set cmd = $Piece($Piece(word,"/",2),"@",1)

	if ((cmd="start")||(cmd="help")) {
		quit ..Reply(chatId,..HelpText())
	}

	if (cmd="rules") {
		quit ..Reply(chatId,..RulesText())
	}

	if (cmd="id") {
		quit ..Reply(chatId,"chat_id: "_chatId_$Char(10)_"твой id: "_pRequest.UserId_$Char(10)_"тип чата: "_pRequest.ChatType)
	}

	if (cmd="stats") {
		quit ..Reply(chatId,..StatsText(chatId))
	}

	if (cmd="warn") {
		if (pRequest.ReplyUserId=0) {
			quit ..Reply(chatId,"Ответь командой /warn на сообщение нарушителя.")
		}
		if (pRequest.ReplyUserId=pRequest.UserId) {
			quit ..Reply(chatId,"Себе предупреждение не выдам.")
		}
		set cnt = $Get(^GreedFranceWarn(chatId,pRequest.ReplyUserId),0)+1
		set ^GreedFranceWarn(chatId,pRequest.ReplyUserId) = cnt
		set who = ..Mention(pRequest.ReplyUserName,pRequest.ReplyDisplayName,pRequest.ReplyUserId)
		if (cnt>=..#WARNLIMIT) {
			quit ..Reply(chatId,who_" — предупреждений: "_cnt_". Предел. Банить вручную: Bot API RecodeGram баны пока не умеет.")
		}
		quit ..Reply(chatId,who_" получает предупреждение "_cnt_"/"_..#WARNLIMIT)
	}

	if (cmd="unwarn") {
		if (pRequest.ReplyUserId=0) {
			quit ..Reply(chatId,"Ответь командой /unwarn на сообщение участника.")
		}
		set cnt = $Get(^GreedFranceWarn(chatId,pRequest.ReplyUserId),0)-1
		if (cnt<0) {
			set cnt = 0
		}
		set ^GreedFranceWarn(chatId,pRequest.ReplyUserId) = cnt
		set who = ..Mention(pRequest.ReplyUserName,pRequest.ReplyDisplayName,pRequest.ReplyUserId)
		quit ..Reply(chatId,who_" — предупреждений: "_cnt)
	}

	if (cmd="warns") {
		quit ..Reply(chatId,..WarnsText(chatId))
	}

	if (cmd="del") {
		if (pRequest.ReplyMessageId=0) {
			quit ..Reply(chatId,"Ответь командой /del на сообщение, которое надо удалить.")
		}
		do ..DeleteMsg(chatId,pRequest.ReplyMessageId)
		quit ..Reply(chatId,"Удалено.")
	}

	if ((cmd="ban")||(cmd="mute")||(cmd="kick")||(cmd="unban")||(cmd="promote")||(cmd="pin")) {
		quit ..Reply(chatId,"Bot API RecodeGram не поддерживает баны, муты и пины: сервер отвечает METHOD_NOT_FOUND. Нужно, чтобы Owner добавил в API методы banChatMember, restrictChatMember, pinChatMessage, getChatAdministrators.")
	}

	quit ..Reply(chatId,"Не знаю команду /"_cmd_". Список команд: /help")
}

/// Новый участник
Method Welcome(pRequest As dc.greedfrance.TelegramRequest) As %Status
{
	set who = pRequest.JoinNames
	if (who="") {
		set who = "новый участник"
	}
	quit ..Reply(pRequest.RequestChatId,"Добро пожаловать, "_who_"! 👋"_
		$Char(10)_"Правила: /rules, команды: /help")
}

/// Спам: удаляем сообщение и пишем в чат
Method PunishSpam(pRequest As dc.greedfrance.TelegramRequest) As %Status
{
	set chatId = pRequest.RequestChatId
	set userId = pRequest.UserId
	do ..DeleteMsg(chatId,pRequest.MessageId)
	kill ^GreedFranceFlood(chatId,userId)
	quit ..Reply(chatId,"🧹 Флуд удалён. Не так быстро.")
}

/// Отправка текста в чат
Method Reply(chatId As %String, text As %String) As %Status
{
	if (chatId="") {
		quit $$$OK
	}
	set msg = ##class(Telegram.Msg.TextRequest).%New()
	set msg.ChatId = chatId
	set msg.Text = $Extract(text,1,4000)
	try {
		quit ..SendRequestSync("ToTelegram",msg,.resp)
	}
	catch e {
		$$$LOGWARNING("GreedFrance: sendMessage failed: "_e.DisplayString())
		quit $$$OK
	}
}

/// Удаление сообщения
Method DeleteMsg(chatId As %String, messageId As %Integer) As %Status
{
	if (messageId=0) {
		quit $$$OK
	}
	set msg = ##class(Telegram.Msg.DeleteRequest).%New()
	set msg.ChatId = chatId
	set msg.MessageId = messageId
	try {
		quit ..SendRequestSync("ToTelegram",msg,.resp)
	}
	catch e {
		$$$LOGWARNING("GreedFrance: deleteMessage failed: "_e.DisplayString())
		quit $$$OK
	}
}

/// Счётчики сообщений
Method CountStats(chatId As %String) As %Status
{
	if (chatId="") {
		quit $$$OK
	}
	set ^GreedFranceStats("total") = $Get(^GreedFranceStats("total"),0)+1
	set ^GreedFranceStats(chatId) = $Get(^GreedFranceStats(chatId),0)+1
	set day = $Piece($Horolog,",",1)
	set ^GreedFranceStats("day",chatId,day) = $Get(^GreedFranceStats("day",chatId,day),0)+1
	quit $$$OK
}

/// Антифлуд: TRUE, если пользователь превысил лимит
ClassMethod IsFlood(chatId As %String, userId As %Integer) As %Boolean
{
	if (userId="") {
		quit 0
	}
	set ts = $Piece($ZTimeStamp,",",1)
	set win = $Get(^GreedFranceFlood(chatId,userId),"")
	if (win="") {
		set ^GreedFranceFlood(chatId,userId) = ts_",1"
		quit 0
	}
	set start = $Piece(win,",",1)
	set cnt = $Piece(win,",",2)
	if ((ts-start)>..#FLOODWINDOW) {
		set ^GreedFranceFlood(chatId,userId) = ts_",1"
		quit 0
	}
	set cnt = cnt+1
	set ^GreedFranceFlood(chatId,userId) = start_","_cnt
	quit (cnt>..#FLOODCOUNT)
}

ClassMethod Mention(username As %String, displayName As %String, userId As %Integer) As %String
{
	if (username'="") {
		quit "@"_username
	}
	if (displayName'="") {
		quit displayName
	}
	quit "id"_userId
}

/// Текст статистики чата
ClassMethod StatsText(chatId As %String) As %String
{
	set msgs = $Get(^GreedFranceStats(chatId),0)
	set total = $Get(^GreedFranceStats("total"),0)
	set day = $Piece($Horolog,",",1)
	set today = $Get(^GreedFranceStats("day",chatId,day),0)
	set warns = 0
	set uid = ""
	for {
		set uid = $Order(^GreedFranceWarn(chatId,uid))
		quit:(uid="")
		set warns = warns+$Get(^GreedFranceWarn(chatId,uid))
	}
	quit "Статистика:"_$Char(10)_
		"сообщений в чате: "_msgs_$Char(10)_
		"за сегодня: "_today_$Char(10)_
		"предупреждений: "_warns_$Char(10)_
		"всего обработано ботом: "_total
}

/// Список предупреждений
ClassMethod WarnsText(chatId As %String) As %String
{
	set out = "Предупреждения:"
	set found = 0
	set uid = ""
	for {
		set uid = $Order(^GreedFranceWarn(chatId,uid))
		quit:(uid="")
		set cnt = $Get(^GreedFranceWarn(chatId,uid))
		if (cnt>0) {
			set found = found+1
			set out = out_$Char(10)_uid_": "_cnt
		}
	}
	if (found=0) {
		set out = out_$Char(10)_"пока никого"
	}
	quit out
}

ClassMethod HelpText() As %String
{
	quit "Команды GreedFrance:"_$Char(10)_
		"/help — этот список"_$Char(10)_
		"/rules — правила чата"_$Char(10)_
		"/id — chat_id и твой id"_$Char(10)_
		"/stats — статистика чата"_$Char(10)_
		"/warn (в ответ на сообщение) — предупреждение"_$Char(10)_
		"/unwarn (в ответ) — снять предупреждение"_$Char(10)_
		"/warns — у кого есть предупреждения"_$Char(10)_
		"/del (в ответ) — удалить сообщение"_$Char(10)_
		$Char(10)_"Антифлуд включён: слишком частые сообщения бот удаляет."
}

ClassMethod RulesText() As %String
{
	quit "Правила чата:"_$Char(10)_
		"1. Без спама и флуда."_$Char(10)_
		"2. Без оскорблений и травли."_$Char(10)_
		"3. Реклама — только с разрешения админов."_$Char(10)_
		"4. Не несколько одинаковых сообщений подряд."_$Char(10)_$Char(10)_
		"Нарушения: предупреждение (/warn), дальше — бан."
}

}
