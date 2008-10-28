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
 *  Viewer core class
*/
package com.wizhelp.flashlight.viewer
{
	import com.wizhelp.flashlight.crypt.DesCipher;
	import com.wizhelp.flashlight.rfb.RFBConst;
	import com.wizhelp.flashlight.rfb.RFBPixelFormat;
	import com.wizhelp.flashlight.rfb.RFBReader;
	import com.wizhelp.flashlight.rfb.RFBWriter;
	import com.wizhelp.flashlight.vnc.VNCBase;
	import com.wizhelp.utils.Thread;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TextEvent;
	import flash.geom.Point;
	import flash.net.Socket;
	import flash.system.Security;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.ui.Mouse;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	
	import mx.core.Application;
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	public class Viewer extends VNCBase
	{	
		/** Logger */
		private static var logger:ILogger = Log.getLogger('com.wizhelp.flashlight.viewer.Viewer');
		
		public var viewOnly:Boolean;
		public var host:String;
		public var port:int;
		public var password:String;
		public var securityPort:int;
		public var shared:Boolean;
		[Bindable] public var connected:Boolean = false;
		
		private var viewerThread:ViewerThread;
		
		private var socket:Socket;
		private var rfbReader: RFBReader;
		
		private static const updateDelay:int = 20;
		private var lastUpdate:int = 0;
		
		private var captureKeyEvents:Boolean = false;
		private var localMouseOnViewer:Boolean = false;
		private var emulateRightButton:Boolean = true;
		
		private var localCursor:Bitmap;
		
		public function connect():void {
			logger.debug(">> connect()");
			
			try {
				if (socket == null) {
					if (securityPort != -1) {
						Security.loadPolicyFile("xmlsocket://"+host+":"+securityPort);
					}
					
					if (viewOnly) {
						var localCursorShape:BitmapData = new BitmapData(4,4,false,0xaaaaaa);
						localCursor = new Bitmap(localCursorShape);
					}
					
					socket = new Socket(host,port);
					
					socket.addEventListener(Event.CONNECT, handleConnect);
					socket.addEventListener(Event.CLOSE, handleDisconnect);
					socket.addEventListener(IOErrorEvent.IO_ERROR,handleIOError);
					socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleSecurityError);
					
					rfbReader = new RFBReader(this,false);
					
					Thread.systemManager = Application.application.systemManager;
					viewerThread = new ViewerThread(rfbReader,socket);
					viewerThread.start();
				}
			} catch (e:Error) {
				logger.error("Unexpected error in connect : "+e);
			}
			
			logger.debug("<< connect()");
		}
		
		public function disconnect():void {
			logger.debug(">> disconnect()");
			
			try {
				if (socket!=null) {
					socket.removeEventListener(Event.CONNECT, handleConnect);
					socket.removeEventListener(Event.CLOSE, handleDisconnect);
					socket.removeEventListener(IOErrorEvent.IO_ERROR,handleIOError);
					socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, handleSecurityError);
					socket.flush();
					socket.close();
					socket = null;
					
					viewerThread = null;
					rfbReader = null;
					connected = false;
					
					removeEventListener( KeyboardEvent.KEY_UP, handleLocalKeyboardEvent );
					removeEventListener( KeyboardEvent.KEY_DOWN, handleLocalKeyboardEvent );
					//removeEventListener( FocusEvent.KEY_FOCUS_CHANGE, handleFocusLost );
					
					if (remoteScreen != null) {
						remoteScreen.removeEventListener( MouseEvent.MOUSE_DOWN, handleLocalMouseEvent );
						remoteScreen.removeEventListener( MouseEvent.MOUSE_UP, handleLocalMouseEvent );
						remoteScreen.removeEventListener( MouseEvent.MOUSE_WHEEL, handleLocalMouseEvent );
						remoteScreen.removeEventListener( MouseEvent.ROLL_OVER,handleLocalRollOver );
						remoteScreen.removeEventListener( MouseEvent.ROLL_OUT,handleLocalRollOut );
						remoteScreen.removeEventListener( MouseEvent.MOUSE_MOVE, handleLocalMouseEvent );
					}
				}
			} catch (e:Error) {
				logger.error("Unexpected error in disconnect : "+e);
			}
			
			logger.debug("<< disconnect()");
		}
		
		private function handleConnect(event:Event):void {
			logger.debug(">> handleConnect()");
			
			connected = true;
			
			logger.debug("<< handleConnect()");
		}
		
		private function handleDisconnect(event:Event):void {
			logger.debug(">> handleDisconnect()");
			
			disconnect();
			
			logger.debug("<< handleDisconnect()");
		}
		
		private function handleIOError(event:IOErrorEvent):void {
			logger.error("IO error when connecting : "+event.type+" "+event.text);
			disconnect();
		}
		
		private function handleSecurityError(event:SecurityError):void {
			logger.error("Security error when connecting. Check security policy.  "+event.name+" "+event.message);
			disconnect();
		}
		
		override public function handleServerVersion(version:String):void {
			logger.debug(">> handleServerVersion()");
			
			super.handleServerVersion(version);
			
			socket.writeUTFBytes("RFB 003.003\n");
			socket.flush();
			
			logger.debug("<< handleServerVersion()");
		}
		
		override public function handleNoAuth():void {
			logger.debug(">> handleNoAuth()");
			
			super.handleNoAuth();
			
			socket.writeByte(0);
			socket.flush();
			
			logger.debug("<< handleNoAuth()");
		}
		
		override public function handleVNCAuth(challenge:ByteArray):void {
			logger.debug(">> handleVNCAuth()");
			
			super.handleVNCAuth(challenge);
			
			var key:ByteArray = new ByteArray();
			key.writeUTFBytes(password);
			var cipher:DesCipher = new DesCipher(key);
			
		    cipher.encrypt(challenge, 0, challenge, 0);
		    cipher.encrypt(challenge, 8, challenge, 8);
					
			socket.writeBytes(challenge);
			socket.flush();
			
			logger.debug("<< handleVNCAuth()");
		}
		
		override public function handleAuthOk():void {
			logger.debug(">> handleAuthOk()");
			
			super.handleAuthOk();
			
			socket.writeByte(shared ? 1 : 0);
			socket.flush();
			
			logger.debug("<< handleAuthOk()");
		}
		
		private var textInput:TextField;
		override public function handleServerInit(desktopName:String, dimension:Point):void {
			logger.debug(">> handleServerInit()");
			
			super.handleServerInit(desktopName,dimension);
			
			if (!viewOnly) {
				// Capture local events
				remoteScreen.addEventListener( MouseEvent.ROLL_OVER, handleLocalRollOver );
				remoteScreen.addEventListener( MouseEvent.ROLL_OUT, handleLocalRollOut );
				remoteScreen.addEventListener( MouseEvent.MOUSE_MOVE, handleLocalMouseEvent );
				remoteScreen.addEventListener( MouseEvent.MOUSE_MOVE, handleLocalMouseEvent );
				remoteScreen.addEventListener( MouseEvent.MOUSE_DOWN, handleLocalMouseEvent );
				remoteScreen.addEventListener( MouseEvent.MOUSE_UP, handleLocalMouseEvent );
				remoteScreen.addEventListener( MouseEvent.MOUSE_WHEEL, handleLocalMouseEvent );
				/*addEventListener( KeyboardEvent.KEY_UP, handleLocalKeyboardEvent );
				addEventListener( KeyboardEvent.KEY_DOWN, handleLocalKeyboardEvent );
				addEventListener( FocusEvent.KEY_FOCUS_CHANGE, handleFocusLost );*/
				
				//this.setFocus();
				
				var myContextMenu:ContextMenu = new ContextMenu();
				myContextMenu.hideBuiltInItems();
				
				var mouseHelper:ContextMenuItem = new ContextMenuItem("CRTL + click to send a remote right click");
				myContextMenu.customItems.push(mouseHelper);
				
				remoteScreen.contextMenu = myContextMenu;
				
				textInput= new TextField();
				textInput.type = TextFieldType.INPUT;
				remoteScreen.addChild(textInput);
				textInput.addEventListener( KeyboardEvent.KEY_UP, handleLocalKeyboardEvent );
				textInput.addEventListener( KeyboardEvent.KEY_DOWN, handleLocalKeyboardEvent );
				textInput.addEventListener(TextEvent.TEXT_INPUT, handleTextInput);
				textInput.addEventListener(FocusEvent.KEY_FOCUS_CHANGE, handleFocusLost);
				textInput.width = 0;
			}
			
			var encodings:Array = [
				RFBConst.EncodingTight,
				RFBConst.EncodingRaw,
				RFBConst.EncodingCopyRect,
				RFBConst.EncodingLastRect,
				RFBConst.EncodingCompressLevel0 + 9,
				RFBConst.EncodingQualityLevel0 +5,
				//RFBConst.EncodingXCursor,
				RFBConst.EncodingRichCursor,
				RFBConst.EncodingPointerPos
			];
			
			RFBWriter.writeEncodings(socket, encodings);
			
			var pixelFormat:RFBPixelFormat = RFBPixelFormat.FORMAT_24BPP;
			
			rfbReader.setPixelFormat(pixelFormat);
			    
			RFBWriter.writeSetPixelFormat(socket, pixelFormat);
			RFBWriter.writeFrameBufferUpdate(socket, false, 0, 0, rfbReader.framebufferWidth, rfbReader.framebufferHeight);
			
			logger.debug("<< handleServerInit()");
		}
		
		override public function handleFrameBufferUpdated():void {
			//logger.log(">> handleUnlockImage()");
			
			super.handleFrameBufferUpdated();
				
			var currentTime:int = getTimer();
			if (currentTime - lastUpdate < updateDelay) {
				lastUpdate = currentTime;
				setTimeout(handleFrameBufferUpdated, updateDelay - (currentTime - lastUpdate) + 1);
			} else {
				RFBWriter.writeFrameBufferUpdate(socket, true, 0, 0, rfbReader.framebufferWidth, rfbReader.framebufferHeight);
				lastUpdate = currentTime;
			}
			
			//logger.log("<< handleUnlockImage()");
		}
		
		override protected function updateRemoteCursorPosition(posX:int,posY:int):void {
			//logger.log(">> updateRemoteCursorPosition()");
			
			if (viewOnly || !localMouseOnViewer) {
				remoteScreenCursor.x = posX - remoteScreenCursorHotSpotX*remoteScreenCursor.scaleX;
				remoteScreenCursor.y = posY - remoteScreenCursorHotSpotY*remoteScreenCursor.scaleY;
			}
			
			var event:MouseEvent = new MouseEvent("remoteMouseMove");
			event.localX = posX ;
			event.localY = posY;
			dispatchEvent(event);
			
			//logger.log(">> updateRemoteCursorPosition()");
		}
		
		private function handleFocusLost(event:FocusEvent):void {
			if (captureKeyEvents) {
				event.preventDefault();
				stage.focus = textInput;
			}
		}
		
		private function handleLocalRollOver(event:MouseEvent):void {
			//logger.log(">> handleLocalRollOver()");
			
			if (viewOnly) {
				addChild(localCursor);
			} else {
				stage.focus = textInput;
				captureKeyEvents = true;
			}
			Mouse.hide();
			localMouseOnViewer = true;
			handleLocalMouseEvent(event);
			
			//logger.log("<< handleLocalRollOver()");
		}
		
		private function handleLocalRollOut(event:MouseEvent):void {
			//logger.log(">> handleLocalRollOut()");
			
			if (viewOnly) {
				removeChild(localCursor);
			} else {
				captureKeyEvents = false;
			}
			Mouse.show();
			localMouseOnViewer = false;
			
			//logger.log("<< handleLocalRollOut()");
		}
		
		private function handleLocalMouseEvent(event:MouseEvent):void {
			//logger.log(">> handleLocalMouseEvent()");
			
			if (viewOnly) {
				if (event.type == MouseEvent.MOUSE_MOVE) {
					localCursor.x = event.localX*remoteScreen.scaleX + remoteScreen.x - localCursor.width/2;
					localCursor.y = event.localY*remoteScreen.scaleY + remoteScreen.y - localCursor.height/2;
				}
			} else {
				if (event.type == MouseEvent.MOUSE_MOVE) {
					remoteScreenCursor.x = event.localX - remoteScreenCursorHotSpotX*remoteScreenCursor.scaleX;
					remoteScreenCursor.y = event.localY - remoteScreenCursorHotSpotY*remoteScreenCursor.scaleY;
				}
				RFBWriter.writePointerEvent(socket,event,emulateRightButton);
				if (captureKeyEvents) {
					stage.focus = textInput;
				}
			}
			
			//logger.log("<< handleLocalMouseEvent()");
		}
		
		private function handleLocalKeyboardEvent(event:KeyboardEvent):void {
			//logger.log(">> handleLocalKeyboardEvent()");
			
			if (!viewOnly) {
				RFBWriter.writeKeyboardEvent(socket,event);
				event.stopImmediatePropagation();
			}
			
			//logger.log("<< handleLocalKeyboardEvent()");
		}
		
		private function handleTextInput(event:TextEvent):void {
			var input:String = event.text;
			
			for (var i:int=0; i<input.length ;i++) {
				RFBWriter.writeKeyEvent(socket,input.charCodeAt(i),true);
				RFBWriter.writeKeyEvent(socket,input.charCodeAt(i),false);
			}
			socket.flush();
			
			textInput.text ='';
		}
	}
}