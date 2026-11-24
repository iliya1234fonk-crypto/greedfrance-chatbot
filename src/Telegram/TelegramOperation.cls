Class Telegram.TelegramOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "Telegram.TelegramOutboundAdapter";

Parameter INVOCATION = "Queue";

Property Adapter As Telegram.TelegramOutboundAdapter;

Method SendMessage(pInput As Telegram.Msg.TextRequest, Output pOutput As Ens.Response) As %Status
{
	Quit ..Adapter.SendMessage(pInput.ChatId,pInput.Text,1)
}

Method SendButton(pInput As Telegram.Msg.ButtonRequest, Output pOutput As Ens.Response) As %Status
{
	Quit ..Adapter.SendButton(pInput.ChatId,pInput.Text,pInput.Button,1)
}

Method DeleteMessage(pInput As Telegram.Msg.DeleteRequest, Output pOutput As Ens.Response) As %Status
{
	Quit ..Adapter.DeleteMessage(pInput.ChatId,pInput.MessageId)
}

XData MessageMap
{
<MapItems>
    <MapItem MessageType="Telegram.Msg.TextRequest">
        <Method>SendMessage</Method>
    </MapItem>
    <MapItem MessageType="Telegram.Msg.DeleteRequest">
        <Method>DeleteMessage</Method>
    </MapItem>
    <MapItem MessageType="Telegram.Msg.ButtonRequest">
        <Method>SendButton</Method>
    </MapItem>
</MapItems>
}

}
