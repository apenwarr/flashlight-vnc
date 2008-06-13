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

/*
	The inside class which provides VNC support.
	
	TODO: _ remove dependency with Flex (no really need to have it at this level
				_ supoort ealier version of Flash
*/
package com.wizhelp.fvnc
{
	import com.wizhelp.utils.DesCipher;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.PixelSnapping;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.ProgressEvent;
	import flash.geom.Rectangle;
	import flash.net.Socket;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.system.Security;
	import flash.ui.Mouse;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.setTimeout;
	
	import mx.controls.Image;
	import mx.controls.Text;
	
	[Event( name="remoteMouseMove", type="flash.events.MouseEvent" )]
	[Event( name="playbackEnd", type="flash.events.Event" )]
	
	public class FVNC extends Image
	{	
		private var logger:Logger = new Logger(this);
		
		public var viewOnly:Boolean;
		public var host:String;
		public var port:int;
		public var password:String;
		public var securityPort:int;
		public var file:String;
		public var debug:Text;
		
		[Embed(source="/assets/cursor.gif")]
	    private var defaultCursor:Class;
	    
		private var recordedSession:Boolean = false;
		private var _bigCursor:Boolean = false;
		
		[Bindable]
		public function get bigCursor():Boolean  {
			return _bigCursor;
		}
		public function set bigCursor(value:Boolean):void  {
			_bigCursor = value;
			if (remoteCursor != null) {
				if (_bigCursor) {
					remoteCursor.scaleX = 2;
					remoteCursor.scaleY = 2;
				} else {
					remoteCursor.scaleX = 1;
					remoteCursor.scaleY = 1;
				}
			}
		}
		
		public var connected:Boolean = false;
		
		private var fbsReader:FBS;
		private var rfb:RFB;
		
		private var image:Bitmap;
		
		public function FVNC() {
			image = new Bitmap(null,PixelSnapping.AUTO,true);
			source = image;
		}
		
		private var socket:Socket;
		public function connect():void {
			if (socket == null) {
				Security.loadPolicyFile("xmlsocket://"+host+":"+securityPort);
				
				socket = new Socket(host,port);
				
				socket.addEventListener(Event.CONNECT, handleConnect);
				socket.addEventListener(Event.CLOSE, handleDisconnect);
				socket.addEventListener(IOErrorEvent.IO_ERROR,handleIOError);
				socket.addEventListener(ProgressEvent.SOCKET_DATA, handleSocketData);
				
				rfb = new RFB(this);
				rfb.onFrameBufferUpdate = handleFrameBufferUpdate;
				rfb.onServerVersion = handleServerVersion;
				rfb.onVNCAuth = handleVNCAuth;
				rfb.onAuthOk = handleAuthOk;
				rfb.onServerInit = handleServerInit;
				rfb.onCursorShapeUpdate = handleCursorShapeUpdate;
				rfb.onCursorPositionUpdate = handleCursorPositionUpdate;
				
				recordedSession = false;
			}
		}
		
		public function disconnect():void {
			if (socket!=null) {
				socket.removeEventListener(Event.CONNECT, handleConnect);
				socket.removeEventListener(Event.CLOSE, handleDisconnect);
				socket.removeEventListener(IOErrorEvent.IO_ERROR,handleIOError);
				socket.removeEventListener(ProgressEvent.SOCKET_DATA, handleSocketData);
				socket.flush();
				socket.close();
				socket = null;
				
				removeEventListener( KeyboardEvent.KEY_UP, handleLocalKeyboardEvent );
				removeEventListener( KeyboardEvent.KEY_DOWN, handleLocalKeyboardEvent );
				removeEventListener( FocusEvent.KEY_FOCUS_CHANGE, handleFocusLost );
				
				if (remoteScreen != null) {
					remoteScreen.removeEventListener( MouseEvent.MOUSE_DOWN, handleLocalMouseEvent );
					remoteScreen.removeEventListener( MouseEvent.MOUSE_UP, handleLocalMouseEvent );
					remoteScreen.removeEventListener( MouseEvent.MOUSE_WHEEL, handleLocalMouseEvent );
					remoteScreen.removeEventListener( MouseEvent.ROLL_OVER,handleLocalRollOver );
					remoteScreen.removeEventListener( MouseEvent.ROLL_OUT,handleLocalRollOut );
					remoteScreen.removeEventListener( MouseEvent.MOUSE_MOVE, handleLocalMouseEvent );
				}
				
				rfb = null;
			}
		}
		
		[Bindable] public var fbsLoader:URLStream = null;
		[Bindable] public var playPosition:Number = 0;
		public function play():void {
			logger.log("play()");
			if ( fbsReader == null) {
				fbsLoader = new URLStream();
			
				fbsReader = new FBS();
				fbsReader.onIncomingData = handleRecordedData;
				fbsLoader.addEventListener(Event.OPEN,handleConnect);
				fbsLoader.addEventListener(ProgressEvent.PROGRESS,handleRecordedFileData);
				fbsLoader.addEventListener(Event.COMPLETE,handleDisconnect);
				fbsLoader.addEventListener(IOErrorEvent.IO_ERROR,handleIOError);
				
				rfb = new RFB(this);
				rfb.onFrameBufferUpdate = handleFrameBufferUpdate;
				rfb.onServerVersion = handleServerVersion;
				rfb.onVNCAuth = handleVNCAuth;
				rfb.onAuthOk = handleAuthOk;
				rfb.onServerInit = handleServerInit;
				rfb.onCursorShapeUpdate = handleCursorShapeUpdate;
				rfb.onCursorPositionUpdate = handleCursorPositionUpdate;
				
				fbsLoader.load(new URLRequest(file));
				
				recordedSession = true;
				playPosition = 0;
			} else {
				fbsReader.play(fbsLoader);
			}
		}
		
		public function next():void {
			//fbsReader.next(fbsLoader);
		}
		
		public function pause():void {
			logger.log("pause()");
			fbsReader.pause();
		}
		
		public function printTimer():void {
			Logger.logTimers();
		}
		
		public function set output(v:Text):void {
			Logger.output = v;
			logger.log("Debug Console inited");
		}
		
		private var fbsBytesTotal:int;
		private function handleRecordedFileData(event:ProgressEvent):void {
			fbsBytesTotal = event.bytesTotal;
			fbsReader.handleData(fbsLoader);
		}
		
		private function handleRecordedData(stream:IDataInput, filePosition:int):void {
			playPosition = filePosition;
			rfb.handleData(stream);
			
			if (playPosition == fbsBytesTotal) {
				var event:Event = new Event("playbackEnd");
				dispatchEvent(event);
				
				fbsReader = null;
				fbsLoader = null;
			}
		}
		
		private function handleSocketData(event:ProgressEvent):void {
			//logger.log("handleSocketData "+socket.bytesAvailable);
			rfb.handleData(socket);
		}
		
		private function handleConnect(event:Event):void {
			connected = true;
		}
		
		private function handleDisconnect(event:Event):void {
			connected = false;
		}
		
		private function handleIOError(event:IOErrorEvent):void {
			throw new Error(event.text);
		}
		
		private function handleServerVersion(version:String):void {
			logger.log(version);
			
			if (!recordedSession) {
				socket.writeUTFBytes("RFB 003.003\n");
				socket.flush();
			}
		}
		
		private function handleVNCAuth(challenge:ByteArray):void {
			logger.log("handleVNCAuth : "+password);
			
			var key:ByteArray = new ByteArray();
			key.writeUTFBytes(password);
			var cipher:DesCipher = new DesCipher(key);
			
		    cipher.encrypt(challenge, 0, challenge, 0);
		    cipher.encrypt(challenge, 8, challenge, 8);
					
			socket.writeBytes(challenge);
			socket.flush();
		}
		
		private function handleAuthOk():void {
			logger.log("handleAuthOk");
			if (!recordedSession) {
				socket.writeByte(0);
				socket.flush();
			}
		}
		private var remoteScreen:RemoteScreenContainer;
		private var remoteImage:Bitmap;
		private var remoteCursor:Bitmap = null;
		private var localCursor:Bitmap = null;
		private function handleServerInit(desktopName:String, frameBuffer:BitmapData):void {
			logger.log(desktopName);
			
			remoteScreen = new RemoteScreenContainer();
			remoteImage = new Bitmap(frameBuffer,PixelSnapping.AUTO,true);
			remoteCursor = new defaultCursor();
			cursorHotSpotX = 1;
			cursorHotSpotY = 1;
			
			
			remoteCursor.smoothing = true;
			var localCursorShape:BitmapData = new BitmapData(4,4,false,0xaaaaaa);
			localCursor = new Bitmap(localCursorShape);
			
			
			remoteScreen.fixedWidth = frameBuffer.width;
			remoteScreen.fixedHeigth = frameBuffer.height;
			
			remoteScreen.scrollRect = new Rectangle(0,0,frameBuffer.width,frameBuffer.height);
			
			remoteScreen.addChild(remoteImage);
			remoteScreen.addChild(remoteCursor);
			remoteScreen.addEventListener( MouseEvent.ROLL_OVER,handleLocalRollOver );
			remoteScreen.addEventListener( MouseEvent.ROLL_OUT,handleLocalRollOut );
			remoteScreen.addEventListener( MouseEvent.MOUSE_MOVE, handleLocalMouseEvent );
			source = remoteScreen;
			
			if (!recordedSession) {
				if (!viewOnly) {
					// Capture local events
					remoteScreen.addEventListener( MouseEvent.MOUSE_DOWN, handleLocalMouseEvent );
					remoteScreen.addEventListener( MouseEvent.MOUSE_UP, handleLocalMouseEvent );
					remoteScreen.addEventListener( MouseEvent.MOUSE_WHEEL, handleLocalMouseEvent );
					addEventListener( KeyboardEvent.KEY_UP, handleLocalKeyboardEvent );
					addEventListener( KeyboardEvent.KEY_DOWN, handleLocalKeyboardEvent );
					addEventListener( FocusEvent.KEY_FOCUS_CHANGE, handleFocusLost );
				}
				
				var encodings:Array = [
					RFB.EncodingTight,
					RFB.EncodingRaw,
					RFB.EncodingCopyRect,
					RFB.EncodingLastRect,
					RFB.EncodingCompressLevel0 + 9,
					RFB.EncodingQualityLevel0 +6,
					//RFB.EncodingXCursor,
					RFB.EncodingRichCursor,
					RFB.EncodingPointerPos
				];
				
				rfb.writeEncodings(socket, encodings);
				
				var pixelFormat:Object = {
					bitsPerPixel: 16,
				    depth: 16,
				    bigEndian: false,
				    trueColour: true,
				    redMax: 31,
				    greenMax: 31,
				    blueMax: 63,
				    redShift: 11,
				    greenShift: 6,
				    blueShift: 0};
				
				/*var pixelFormat:Object = {
					bitsPerPixel: 32,
				    depth: 24,
				    bigEndian: false,
				    trueColour: true,
				    redMax: 255,
				    greenMax: 255,
				    blueMax: 255,
				    redShift: 16,
				    greenShift: 8,
				    blueShift: 0};*/
				
				/*var pixelFormat:Object = {
					bitsPerPixel: 8,
				    depth: 8,
				    bigEndian: true,
				    trueColour: true,
				    redMax: 7,
				    greenMax: 7,
				    blueMax: 3,
				    redShift: 5,
				    greenShift: 2,
				    blueShift: 0};*/
				    
				rfb.writeSetPixelFormat(socket, pixelFormat);
				
				rfb.writeFrameBufferUpdate(socket,  false);
			}
		}
		
		private var updateDelay:int = 50;
		private var lastUpdate:Number = 0;
		private function handleFrameBufferUpdate():void {
			if (!recordedSession) {
				var currentTime:Number = (new Date()).getTime();
				if (currentTime - lastUpdate < updateDelay) {
					lastUpdate = currentTime;
					setTimeout(rfb.writeFrameBufferUpdate, updateDelay - (currentTime - lastUpdate),socket);
				} else {
					rfb.writeFrameBufferUpdate(socket);
					lastUpdate = currentTime;
				}
			}
		}
		
		private var cursorHotSpotX:int=0;
		private var cursorHotSpotY:int=0;
		private function handleCursorShapeUpdate(hotSpotX:int, hotSpotY:int,cursorShape:BitmapData):void {
			remoteCursor.bitmapData = cursorShape;
			remoteCursor.smoothing = true;
			remoteCursor.x += cursorHotSpotX-hotSpotX;
			remoteCursor.y += cursorHotSpotY-hotSpotY;
			cursorHotSpotX = hotSpotX;
			cursorHotSpotY = hotSpotY;
		}
		
		private var localMouseOnViewer:Boolean = false;
		private function handleCursorPositionUpdate(posX:int,posY:int):void {
			if (viewOnly || !localMouseOnViewer || recordedSession) {
				remoteCursor.x = posX - cursorHotSpotX*remoteCursor.scaleX;
				remoteCursor.y = posY - cursorHotSpotY*remoteCursor.scaleY;
			}
			
			var event:MouseEvent = new MouseEvent("remoteMouseMove");
			event.localX = posX ;
			event.localY = posY;
			dispatchEvent(event);
		}
		
		private var captureKeyEvents:Boolean = false;
		private function handleFocusLost(event:FocusEvent):void {
			if (captureKeyEvents) {
				event.preventDefault();
				this.setFocus();
			}
		}
		
		private function handleLocalRollOver(event:MouseEvent):void {
			if (viewOnly || recordedSession) {
				addChild(localCursor);
			} else {
				this.setFocus();
				captureKeyEvents = true;
			}
			Mouse.hide();
			localMouseOnViewer = true;
			handleLocalMouseEvent(event);
		}
		
		private function handleLocalRollOut(event:MouseEvent):void {
			if (viewOnly || recordedSession) {
				removeChild(localCursor);
			} else {
				captureKeyEvents = false;
			}
			Mouse.show();
			localMouseOnViewer = false;
		}
		
		private var emulateRightButton:Boolean = true;
		private function handleLocalMouseEvent(event:MouseEvent):void {
			if (viewOnly || recordedSession) {
				if (event.type == MouseEvent.MOUSE_MOVE) {
					localCursor.x = event.localX*remoteScreen.scaleX + remoteScreen.x - localCursor.width/2;
					localCursor.y = event.localY*remoteScreen.scaleY + remoteScreen.y - localCursor.height/2;
				}
			} else {
				if (event.type == MouseEvent.MOUSE_MOVE) {
					remoteCursor.x = event.localX - cursorHotSpotX*remoteCursor.scaleX;
					remoteCursor.y = event.localY - cursorHotSpotY*remoteCursor.scaleY;
				}
				rfb.writePointerEvent(socket,event,emulateRightButton);
				if (captureKeyEvents) {
					this.setFocus();
				}
			}
		}
		
		private function handleLocalKeyboardEvent(event:KeyboardEvent):void {
			if (!viewOnly && !recordedSession) {
				rfb.writeKeyboardEvent(socket,event);
				event.stopImmediatePropagation();
			}
		}
	}
}