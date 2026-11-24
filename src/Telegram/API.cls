/// Класс для работы с Bot API (Telegram или RecodeGram)
Class Telegram.API Extends %RegisteredObject
{

Property Token As %String;

/// Адрес Bot API. Для RecodeGram: 31.77.232.21:2500
Parameter SERVER = "31.77.232.21";

Parameter PORT = 2500;

/// 1 - https, 0 - http
Parameter HTTPS = 0;

Property SSLConfiguration As %String;

Method GetRequestObj() As %Net.HttpRequest [ Private ]
{
	#dim request as %Net.HttpRequest
	set request = ##class(%Net.HttpRequest).%New()
	set request.Server = ..#SERVER
	set request.Port = ..#PORT
	if (..#HTTPS = 1) {
		set request.Https = 1
		set request.SSLConfiguration = ..SSLConfiguration
	}
	return request
}

Method ExecuteRequest(request As %Net.HttpRequest, method As %String) As %DynamicObject [ Private ]
{
	set st = request.Post("bot"_..Token_"/"_method)
	if ($$$ISERR(st)) {
		throw ##class(%Exception.StatusException).CreateFromStatus(st)
	}
	return ##class(%Library.DynamicObject).%FromJSON(request.HttpResponse.Data)
}

Method %OnNew(token As %String, ssl As %String = "") As %Status [ Private ]
{
	return:(token="") 0
	set ..Token = token
	set ..SSLConfiguration = ssl
	return $$$OK
}

Method GetMe() As %DynamicObject
{
	return ..ExecuteRequest(..GetRequestObj(), "getMe")
}

Method GetUpdates(offset As %Integer = "", limit As %Integer = 100, timeout As %Integer = 0) As %DynamicObject
{
	#dim request as %Net.HttpRequest
	set request = ..GetRequestObj()
	if (offset'="") {
		do request.InsertFormData("offset",offset)
	}
	do request.InsertFormData("limit",limit)
	do request.InsertFormData("timeout",timeout)
	return ..ExecuteRequest(request, "getUpdates")
}

Method SendMessage(chatId As %Integer, text As %String, parseMode As %String = "", disableWebPagePreview As %Boolean = 0, disableNotification As %Boolean = 0, replyToMessageId As %Integer = 0, replyMarkup As %DynamicObject = 0) As %DynamicObject
{
	#dim request as %Net.HttpRequest
	set request = ..GetRequestObj()
	do request.InsertFormData("chat_id",chatId)
	do request.InsertFormData("text",text)
	if (replyMarkup'=0) {
		do request.InsertFormData("reply_markup",replyMarkup.%ToJSON())
	}
	return ..ExecuteRequest(request, "sendMessage")
}

Method DeleteMessage(chatId As %String, messageId As %Integer) As %DynamicObject
{
	#dim request as %Net.HttpRequest
	set request = ..GetRequestObj()
	do request.InsertFormData("chat_id",chatId)
	do request.InsertFormData("message_id",messageId)
	return ..ExecuteRequest(request, "deleteMessage")
}

Method DeleteWebhook() As %DynamicObject
{
	return ..ExecuteRequest(..GetRequestObj(), "deleteWebhook")
}

Method GetWebhookInfo() As %DynamicObject
{
	return ..ExecuteRequest(..GetRequestObj(), "getWebhookInfo")
}

/// Универсальный вызов любого метода Bot API.
/// form - объект с полями (значения приводятся к строке).
Method CallMethod(method As %String, form As %DynamicObject = "") As %DynamicObject
{
	#dim request as %Net.HttpRequest
	set request = ..GetRequestObj()
	if ($isobject(form)) {
		set iter = form.%GetIterator()
		while (iter.%GetNext(.key, .value)) {
			set type = form.%GetTypeOf(key)
			if (type = "object") {
				set value = value.%ToJSON()
			} elseif (type = "array") {
				set value = value.%ToJSON()
			}
			do request.InsertFormData(key, value)
		}
	}
	return ..ExecuteRequest(request, method)
}

}
