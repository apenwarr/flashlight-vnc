package com.screentoaster.utils.logger
{
	/*
		Copyright (C) ScreenToaster SAS
		www.screentoaster.com
	*/
	
	import flash.external.ExternalInterface;
	
	import mx.logging.AbstractTarget;
	import mx.logging.LogEvent;
	
	public class JSTarget extends AbstractTarget
	{
		private static var _jsLoggerFunction:String;
	
		public static  function set jsLoggerFunction(value:String):void {
			_jsLoggerFunction = value;
		}
		
		override public function logEvent(event:LogEvent):void {
			ExternalInterface.call(_jsLoggerFunction,event.level,event.message);
		}
	}
}