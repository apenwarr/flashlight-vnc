/*

	Copyright (C) 2008 Marco Fucci

	This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Library General Public
	License as published by the Free Software Foundation; either
	version 2 of the License, or (at your option) any later version.
	
	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	Library General Public License for more details.
	
	You should have received a copy of the GNU Library General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
	
	Contact : mfucci@gmail.com
	
*/

/**
*  Core VNC support.
*  Used by the Player and the Viewer
*/
package com.wizhelp.flashlight.vnc
{
	import com.wizhelp.utils.BufferPool;
	import com.wizhelp.utils.Logger;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.PixelSnapping;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	
	import mx.controls.Image;
	
	[Event( name="remoteMouseMove", type="flash.events.MouseEvent" )]
	
	public class VNCBase extends Image implements VNCHandler
	{	
		/** Logger */
		private static var logger:Logger = new Logger(VNCBase);
		
		public function VNCBase() {
			logger.log(">> init()");
			
			source = new Bitmap(null,PixelSnapping.AUTO,true);
			this.addEventListener(Event.ENTER_FRAME, renderRemoteScreen);
			
			logger.log("<< init()");
		}
		
		protected var remoteScreen:VNCScreen;
		private var remoteScreenImage:Bitmap;
		private var remoteScreenData:BitmapData;
		protected var remoteScreenCursor:Bitmap;
		protected var remoteScreenCursorHotSpotX:int;
		protected var remoteScreenCursorHotSpotY:int;
		
		[Embed(source="/assets/cursor.gif")]
	    private var DefaultCursor:Class;
		
		private var actionStack:Array = new Array();
		[Bindable] public var currentPosition:int = 0;
		[Bindable] public var preBufferingPosition:int = -1;
		private var imageLocked:Boolean = false;
		
		public function handleServerVersion(version:String):void {
			logger.log(version);
		}
		
		public function handleNoAuth():void {
		}
		
		public function handleVNCAuth(challenge:ByteArray):void {
		}
		
		public function handleAuthOk():void {
		}
		
		public function handleServerInit(desktopName:String, dimension:Point):void {
			logger.log(">> handleServerInit()");
			
			// Create new remote screen
			remoteScreen = new VNCScreen();
			remoteScreen.fixedWidth = dimension.x;
			remoteScreen.fixedHeigth = dimension.y;
			remoteScreen.scrollRect = new Rectangle(0,0,dimension.x,dimension.y);
			
			// Init screen image
			remoteScreenData = new BitmapData(dimension.x, dimension.y, false, 0xFF000000);
			remoteScreenImage = new Bitmap(remoteScreenData,PixelSnapping.AUTO,true);
			
			// Init screen cursor
			remoteScreenCursor = new DefaultCursor();
			remoteScreenCursor.smoothing = true;
			remoteScreenCursorHotSpotX = 1;
			remoteScreenCursorHotSpotY = 1;
			
			// Add cursor and image to screen
			remoteScreen.addChild(remoteScreenImage);
			remoteScreen.addChild(remoteScreenCursor);
			
			// Set screen as the image's source
			source = remoteScreen;
			
			logger.log("<< handleServerInit()");
		}
				
		public function handleFrameBufferUpdated():void {
			actionStack.push(new VNCAction(VNCAction.UNLOCK_IMAGE,preBufferingPosition));
		}
		
		public function handleUpdateImage(rect:Rectangle, data:ByteArray):void {
			var action:VNCAction = new VNCAction(VNCAction.UPDATE_IMAGE,preBufferingPosition);
			data.position = 0;
			
			action.rect = rect;
			action.data = data;
			actionStack.push(action);
		}
		
		public function handleUpdateImageFillRect(rect:Rectangle, color:uint):void {
			var action:VNCAction = new VNCAction(VNCAction.UPDATE_IMAGE_FILL_RECT,preBufferingPosition);
			
			action.rect = rect;
			action.color = color;
			actionStack.push(action);
		}	
		
		public function handleCopyImage(src:Point, dst:Rectangle):void {
			var action:VNCAction = new VNCAction(VNCAction.UPDATE_IMAGE_COPY_RECT,preBufferingPosition);
			
			action.src = src;
			action.dst = dst;
			actionStack.push(action);
		}
		
		public function handleUpdateCursorShape(x:int, y:int, shape:BitmapData):void {
			var action:VNCAction = new VNCAction(VNCAction.UPDATE_CURSOR_SHAPE,preBufferingPosition);
			
			action.x = x;
			action.y = y;
			action.shape = shape;
			actionStack.push(action);
		}
		
		public function handleUpdateCursorPosition(x:int, y:int):void {
			var action:VNCAction = new VNCAction(VNCAction.UPDATE_CURSOR_POS,preBufferingPosition);
			
			action.x = x;
			action.y = y;
			actionStack.push(action);
		}
		
		private function renderRemoteScreen(event:Event):void {
			var actionUpdateCursorPos:VNCAction = null;
			var actionUpdateCursorShape:VNCAction = null;

			while (actionStack.length) {
				if (VNCAction(actionStack[0]).actionTime > currentPosition) {
					break;
				}
				
				var action:VNCAction = VNCAction(actionStack.shift());
				
				switch (action.actionType) {
					case VNCAction.UNLOCK_IMAGE:
						if (imageLocked) {
							remoteScreenData.unlock();
							imageLocked = false;
							break;
						}
					break;
					case VNCAction.UPDATE_IMAGE:
						if (!imageLocked) {
							imageLocked=true;
							remoteScreenData.lock();
						}
						remoteScreenData.setPixels(action.rect,action.data);
						BufferPool.releaseDataBuffer(action.data);
					break;
					case VNCAction.UPDATE_IMAGE_FILL_RECT:
						if (!imageLocked) {
							imageLocked=true;
							remoteScreenData.lock();
						}
  						remoteScreenData.fillRect(action.rect,action.color);
					break;
					case VNCAction.UPDATE_IMAGE_COPY_RECT:
						if (!imageLocked) {
							imageLocked=true;
							remoteScreenData.lock();
						}
						var copyRect:ByteArray = remoteScreenData.getPixels(
							new Rectangle(action.src.x,action.src.y,action.dst.width,action.dst.height));
					    copyRect.position = 0;
					    remoteScreenData.setPixels(action.dst,copyRect);
					    BufferPool.releaseDataBuffer(copyRect);
					break;
					case VNCAction.UPDATE_CURSOR_SHAPE:
						actionUpdateCursorShape = action;
					break;
					case VNCAction.UPDATE_CURSOR_POS:
						actionUpdateCursorPos = action;
					break;
				}
			}
			
			if (actionUpdateCursorShape != null) {
				updateRemoteCursorShape(actionUpdateCursorShape.x,actionUpdateCursorShape.y,actionUpdateCursorShape.shape);
			}
			
			if (actionUpdateCursorPos != null) {
				updateRemoteCursorPosition(actionUpdateCursorPos.x,actionUpdateCursorPos.y);
			}
		}
		
		protected function updateRemoteCursorShape(hotSpotX:int, hotSpotY:int,cursorShape:BitmapData):void {
			remoteScreenCursor.bitmapData = cursorShape;
			remoteScreenCursor.smoothing = true;
			remoteScreenCursor.x += (remoteScreenCursorHotSpotX-hotSpotX)*remoteScreenCursor.scaleX;
			remoteScreenCursor.y += (remoteScreenCursorHotSpotY-hotSpotY)*remoteScreenCursor.scaleY;
			remoteScreenCursorHotSpotX = hotSpotX;
			remoteScreenCursorHotSpotY = hotSpotY;
		}
		
		protected function updateRemoteCursorPosition(posX:int,posY:int):void {
			remoteScreenCursor.x = posX - remoteScreenCursorHotSpotX*remoteScreenCursor.scaleX;
			remoteScreenCursor.y = posY - remoteScreenCursorHotSpotY*remoteScreenCursor.scaleY;
			
			var event:MouseEvent = new MouseEvent("remoteMouseMove");
			event.localX = posX ;
			event.localY = posY;
			dispatchEvent(event);
		}
		
		private var _bigCursor:Boolean = false;
		/** Big cursor (zoom x2) */
		[Bindable]
		public function get bigCursor():Boolean  {
			return _bigCursor;
		}
		public function set bigCursor(value:Boolean):void  {
			_bigCursor = value;
			
			if (remoteScreenCursor != null) {
				var posX:int = remoteScreenCursor.x + remoteScreenCursorHotSpotX*remoteScreenCursor.scaleX;
				var posY:int = remoteScreenCursor.y + remoteScreenCursorHotSpotY*remoteScreenCursor.scaleY;
			
				if (_bigCursor) {
					remoteScreenCursor.scaleX = 2;
					remoteScreenCursor.scaleY = 2;
				} else {
					remoteScreenCursor.scaleX = 1;
					remoteScreenCursor.scaleY = 1;
				}
				
				remoteScreenCursor.x = posX - remoteScreenCursorHotSpotX*remoteScreenCursor.scaleX;
				remoteScreenCursor.y = posY - remoteScreenCursorHotSpotY*remoteScreenCursor.scaleY;
			}
		}
	}
}