/// Премиум-эмодзи (custom emoji) из нашего пака в RecodeGram.
/// ID взяты из сообщений, которые владелец бота присылал боту:
/// сервер вернул entities с type="custom_emoji" и custom_emoji_id.
/// Использование: set text = ##class(dc.greedfrance.Emoji).Render(text)
Class dc.greedfrance.Emoji Extends %RegisteredObject
{

XData EmojiMap [ MimeType = "application/json" ]
{
{"💤":"2439041569131786168","☺️":"4597355097536367746","😯":"7259497068081255459","😻":"9221572105672521659","👋":"4388406521154080499","❤":"8574730238183917396","😡":"7823069062403247485","❓":"8435672295643758212","⚠️":"1525323927779146069","💔":"8017979044046014006","🙂":"6282648522502854596","😎":"7765660997405941824","❤️":"3680918674188892068"}
}

/// Загружает карту в глобал ^GreedEmojiT(длина, эмодзи) = custom_emoji_id.
ClassMethod Load() As %Status
{
	quit:$data(^GreedEmojiT) $$$OK
	kill ^GreedEmojiT
	set xd = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||EmojiMap")
	if '$isobject(xd) {
		quit $system.Status.Error(5001, "EmojiMap XData not found")
	}
	set stream = xd.Data
	if '$isobject(stream) {
		quit $system.Status.Error(5001, "EmojiMap XData is empty")
	}
	do stream.Rewind()
	set json = stream.Read(stream.Size)
	set obj = ##class(%DynamicObject).%FromJSON(json)
	set iter = obj.%GetIterator()
	while iter.%GetNext(.key, .id) {
		set ^GreedEmojiT($length(key), key) = id
		set alt = $translate(key, $char(65039))
		if ((alt '= key) && (alt '= "") && ('$data(^GreedEmojiT($length(alt), alt)))) {
			set ^GreedEmojiT($length(alt), alt) = id
		}
	}
	quit $$$OK
}

/// Экранирует HTML и оборачивает известные эмодзи в <tg-emoji>.
ClassMethod Render(text As %String) As %String
{
	if (text = "") {
		quit ""
	}
	do ..Load()
	set out = $replace(text, "&", "&amp;")
	set out = $replace(out, "<", "&lt;")
	set out = $replace(out, ">", "&gt;")
	set len = ""
	for {
		set len = $order(^GreedEmojiT(len), -1)
		quit:(len = "")
		set key = ""
		for {
			set key = $order(^GreedEmojiT(len, key))
			quit:(key = "")
			if ($find(out, key) > 0) {
				set out = $replace(out, key, "<tg-emoji emoji-id="""_^GreedEmojiT(len, key)_""">"_key_"</tg-emoji>")
			}
		}
	}
	quit out
}

ClassMethod Has(emoji As %String) As %Boolean
{
	do ..Load()
	quit $data(^GreedEmojiT($length(emoji), emoji))
}

}
