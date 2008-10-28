package com.wizhelp.flashlight.fbs
{
	import flash.geom.Rectangle;
	
	public interface FBSListener
	{
		 function onVideoDuration(duration:int):void;
		 function onClipRectangle(clipRectangle:Rectangle):void;
	}
}