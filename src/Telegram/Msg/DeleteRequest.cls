Class Telegram.Msg.DeleteRequest Extends Ens.Request
{

Property ChatId As %Integer;

Property MessageId As %Integer;

Storage Default
{
<Data name="DeleteRequestDefaultData">
<Subscript>"DeleteRequest"</Subscript>
<Value name="1">
<Value>ChatId</Value>
</Value>
<Value name="2">
<Value>MessageId</Value>
</Value>
</Data>
<DefaultData>DeleteRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
