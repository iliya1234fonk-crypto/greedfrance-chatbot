Class dc.greedfrance.GreedFranceProduction Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="dc.greedfrance.GreedFranceProduction" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description></Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="ToChatterbot" Category="" ClassName="dc.greedfrance.ToChatterbot" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
  </Item>
  <Item Name="ChatbotRouter" Category="" ClassName="dc.greedfrance.ChatbotRouter" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
  </Item>
  <Item Name="FromTelegram" Category="" ClassName="dc.greedfrance.FromTelegram" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Adapter" Name="Credentials">telegram</Setting>
  </Item>
  <Item Name="ToTelegram" Category="" ClassName="Telegram.TelegramOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Adapter" Name="Credentials">telegram</Setting>
  </Item>
</Production>
}

}
