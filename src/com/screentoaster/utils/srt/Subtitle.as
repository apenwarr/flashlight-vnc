package com.screentoaster.utils.srt
{
	import flash.events.EventDispatcher;

	public class Subtitle extends EventDispatcher
	{
		[Bindable] public var text:String = null;
		[Bindable] public var showTime:int;
		[Bindable] public var hideTime:int;
		[Bindable] public var waitTime:int = -1;
		
		public function Subtitle(showTime:int, hideTime:int, text:String, waitTime:int = -1) {
			this.showTime = showTime;
			this.hideTime = hideTime;
			this.text = text;
			this.waitTime = waitTime;
		}
	}
}