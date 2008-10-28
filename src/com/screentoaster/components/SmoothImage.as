package com.screentoaster.components
{
    import flash.display.Bitmap;
    import flash.display.DisplayObject;
    import flash.display.Loader;
    import flash.events.Event;
    
    import mx.controls.Image;
    import mx.core.mx_internal;
    import mx.logging.ILogger;
    import mx.logging.Log;
 
    use namespace mx_internal;
 
    /**
     * SmoothImage
     *
     * Automatically turns smoothing on after image has loaded
     *
     * @author Ben Longoria
     */
    public class SmoothImage extends Image {
    	
		private static var logger:ILogger = Log.getLogger('com.screentoaster.components.SmoothImage');
 
        public function SmoothImage():void {
            super();
        }
        
        override public function set source(value:Object):void {
        	if (value is Class) {
        		var cls:Class = Class(value);
        		var content:DisplayObject = new cls();
        		
        		if (content is Bitmap) {
        			var bitmap:Bitmap = content as Bitmap;
        			bitmap.smoothing = true;
        		}
        		super.source = content;
        	} else {
        		super.source = value;
        	}
        }
 
        /**
         * @private
         */
        override mx_internal function contentLoaderInfo_completeEventHandler(event:Event):void {
        	try {
	            var smoothLoader:Loader = event.target.loader as Loader;
	            var smoothImage:Bitmap = smoothLoader.content as Bitmap;
	            smoothImage.smoothing = true;
	        } catch (e:Error) {
	        	logger.error("Unexpected error in contentLoaderInfo_completeEventHandler : "+e);
	        }
 
            super.contentLoaderInfo_completeEventHandler(event);
        }
    }
}