package com.screentoaster.utils.logger
{
	/*
		Copyright (C) ScreenToaster SAS
		www.screentoaster.com
	*/
	
	import mx.controls.Alert;
	import mx.controls.Text;
	import mx.core.mx_internal;
	import mx.logging.targets.LineFormattedTarget;
	
	use namespace mx_internal;
	
	public class ConsoleTarget extends LineFormattedTarget
	{
		public static var console:Text;
		private var tmpBuffer:String = null;
		
		override mx_internal function internalLog(message:String):void {
			if (console) {
				if (tmpBuffer) {
					console.text = console.text + tmpBuffer;
					tmpBuffer = null;
				}
				console.text = console.text + message +"\n";
			} else {
				if (!tmpBuffer) {
					tmpBuffer = '';
				}
				tmpBuffer = tmpBuffer + message +"\n";
			}
		}
	}
}