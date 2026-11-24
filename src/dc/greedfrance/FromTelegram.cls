Class dc.greedfrance.FromTelegram Extends Ens.BusinessService
{

Parameter ADAPTER = "Telegram.TelegramInboundAdapter";

Method OnProcessInput(pInput As %RegisteredObject, pOutput As %RegisteredObject) As %Status
{
	set msg = pInput.message
	if (msg = "") {
		return $$$OK // skipping, if update type not equal to "message"
	}

	$$$TRACE(##class(%ZEN.Auxiliary.altJSONProvider).%ObjectToAET(pInput).%ToJSON())

	set chatType = ""
	if ($isobject(msg.chat)) {
		set chatType = msg.chat.type
	}

	// В группах бот работает как модератор
	if ((chatType = "group") || (chatType = "supergroup")) {
		try {
			set moderator = ##class(dc.greedfrance.Moderator).%New()
			if ($isobject(moderator)) {
				set handled = moderator.Handle(msg)
				if (handled) {
					return $$$OK
				}
			}
		} catch ex {
			$$$TRACE("Moderator error: "_$system.Status.GetErrorText(ex.AsStatus()))
		}
		return $$$OK
	}

	set inputText = ""
	if (msg.text '= "") {
		set inputText = msg.text
	}
	if (inputText = "") {
		return $$$OK
	}

	set msgReq = ##class(dc.greedfrance.TelegramRequest).%New()
	set msgReq.RequestText = inputText
	set msgReq.RequestChatId = msg.chat.id

	$$$TOE(sc, ..SendRequestAsync("ChatbotRouter", msgReq, .pOutput))

	$$$TRACE(pOutput)

	return $$$OK
}

}
