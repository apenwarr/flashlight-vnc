package com.wizhelp.flashlight.vnc
{
	import flash.display.BitmapData;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	
	public interface VNCHandler
	{
		function handleServerVersion(version:String):void;
		
		function handleNoAuth():void;
		
		function handleVNCAuth(challenge:ByteArray):void;
		
		function handleAuthOk():void;
		
		function handleServerInit(desktopName:String, dimension:Point):void;
		
		function handleUpdateImage(rect:Rectangle, data:ByteArray):void;
		
		function handleUpdateImageFillRect(rect:Rectangle, color:uint):void;
		
		function handleCopyImage(src:Point, dst:Rectangle):void;
		
		function handleUpdateCursorShape(x:int, y:int, shape:BitmapData):void;
		
		function handleUpdateCursorPosition(x:int, y:int):void;
		
		function handleFrameBufferUpdated():void;
	}
}