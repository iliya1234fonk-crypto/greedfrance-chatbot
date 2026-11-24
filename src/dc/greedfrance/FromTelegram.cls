Class dc.greedfrance.FromTelegram Extends Ens.BusinessService
{

Parameter ADAPTER = "Telegram.TelegramInboundAdapter";

Method OnProcessInput(pInput As %RegisteredObject, pOutput As %RegisteredObject) As %Status
{
	set tMsg = pInput.message
	if '$IsObject(tMsg) {
		return $$$OK // skipping, if update type not equal to "message"
	}

	set msg = ##class(dc.greedfrance.TelegramRequest).%New()
	set msg.RequestText = tMsg.%Get("text","")
	set msg.MessageId = tMsg.%Get("message_id",0)

	set chat = tMsg.%Get("chat")
	if $IsObject(chat) {
		set msg.RequestChatId = chat.%Get("id","")
		set msg.ChatType = chat.%Get("type","")
	}

	set from = tMsg.%Get("from")
	if $IsObject(from) {
		set msg.UserId = from.%Get("id",0)
		set msg.UserName = from.%Get("username","")
		set msg.DisplayName = from.%Get("first_name","")
	}

	set reply = tMsg.%Get("reply_to_message")
	if $IsObject(reply) {
		set msg.ReplyMessageId = reply.%Get("message_id",0)
		set rfrom = reply.%Get("from")
		if $IsObject(rfrom) {
			set msg.ReplyUserId = rfrom.%Get("id",0)
			set msg.ReplyUserName = rfrom.%Get("username","")
			set msg.ReplyDisplayName = rfrom.%Get("first_name","")
		}
	}

	set members = tMsg.%Get("new_chat_members")
	if $IsObject(members) {
		set msg.IsJoin = 1
		set names = ""
		set it = members.%GetIterator()
		while it.%GetNext(.key,.member) {
			if $IsObject(member) {
				set name = member.%Get("first_name","")
				if (name="") {
					set name = member.%Get("username","")
				}
				if (name'="") {
					set names = names_$Select(names="":"",1:", ")_name
				}
			}
		}
		set msg.JoinNames = names
	}

	$$$TOE(sc, ..SendRequestAsync("ModerationRouter", msg, .pOutput))

	$$$TRACE(pOutput)

	Return $$$OK
}

}
