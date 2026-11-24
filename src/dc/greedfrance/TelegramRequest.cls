Class dc.greedfrance.TelegramRequest Extends Ens.Request
{

Property RequestText As %String(MAXLEN = "");

Property RequestChatId As %String(MAXLEN = "");

/// Идентификатор сообщения в чате (нужен для удаления)
Property MessageId As %Integer;

/// private / group / supergroup / channel
Property ChatType As %String;

/// Кто написал
Property UserId As %Integer;

Property UserName As %String;

Property DisplayName As %String;

/// На какое сообщение отвечает пользователь (для /warn, /del)
Property ReplyMessageId As %Integer;

Property ReplyUserId As %Integer;

Property ReplyUserName As %String;

Property ReplyDisplayName As %String;

/// Пришёл новый участник (new_chat_members)
Property IsJoin As %Boolean;

Property JoinNames As %String(MAXLEN = "");

Storage Default
{
<Data name="TelegramRequestDefaultData">
<Subscript>"TelegramRequest"</Subscript>
<Value name="1">
<Value>RequestText</Value>
</Value>
<Value name="2">
<Value>RequestChatId</Value>
</Value>
<Value name="3">
<Value>MessageId</Value>
</Value>
<Value name="4">
<Value>ChatType</Value>
</Value>
<Value name="5">
<Value>UserId</Value>
</Value>
<Value name="6">
<Value>UserName</Value>
</Value>
<Value name="7">
<Value>DisplayName</Value>
</Value>
<Value name="8">
<Value>ReplyMessageId</Value>
</Value>
<Value name="9">
<Value>ReplyUserId</Value>
</Value>
<Value name="10">
<Value>ReplyUserName</Value>
</Value>
<Value name="11">
<Value>ReplyDisplayName</Value>
</Value>
<Value name="12">
<Value>IsJoin</Value>
</Value>
<Value name="13">
<Value>JoinNames</Value>
</Value>
</Data>
<DefaultData>TelegramRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
