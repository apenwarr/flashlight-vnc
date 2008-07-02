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
	Write RFB protocol.
*/

package com.wizhelp.flashlight.rfb
{
	import com.wizhelp.utils.Logger;
	
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.net.Socket;
	import flash.ui.Keyboard;
	
	public class RFBWriter {
		private static var logger:Logger = new Logger(RFBWriter);
			
		public static function writeEncodings(socket:Socket, encodings:Array):void {
			socket.writeByte(RFBConst.SetEncodings);
			socket.writeByte( 0 );
			socket.writeShort( encodings.length );
			for (var i:int=0 ; i < encodings.length ; i++) {
				socket.writeInt(encodings[i]);
			}
			socket.flush();
		}
		
		public static function writeFrameBufferUpdate(socket:Socket, updateOnly:Boolean, x:int, y:int, width:int, height:int):void {
			socket.writeByte(RFBConst.FramebufferUpdateRequest);
			socket.writeByte(updateOnly ? 1 : 0);
			socket.writeShort(x);
			socket.writeShort(y);
			socket.writeShort(width);
			socket.writeShort(height);
			socket.flush();
		}
		
		public static function writeSetPixelFormat(socket:Socket, pixelFormat:Object):void {
			socket.writeByte(RFBConst.SetPixelFormat);
			
			socket.writeByte(0);
			socket.writeByte(0);
			socket.writeByte(0);
			
			socket.writeByte(pixelFormat.bitsPerPixel);
			socket.writeByte(pixelFormat.depth);
			socket.writeByte(pixelFormat.bigEndian ? 1 : 0);
			socket.writeByte(pixelFormat.trueColour ? 1 : 0);
			socket.writeShort(pixelFormat.redMax);
			socket.writeShort(pixelFormat.greenMax);
			socket.writeShort(pixelFormat.blueMax);
			socket.writeByte(pixelFormat.redShift);
			socket.writeByte(pixelFormat.greenShift);
			socket.writeByte(pixelFormat.blueShift);
			
			socket.writeByte(0);
			socket.writeByte(0);
			socket.writeByte(0);
			socket.flush();
		}
		
		/* handles pointer events
		* Right click is emulated with CRT
		*/
		public static function writePointerEvent(socket:Socket, event:MouseEvent, emulateRightButton:Boolean):void {
			var pointerMask:int;
			var mask2:int = 2;
			var mask3:int = 4;
			
			/*if ( event.delta < 0 ) {
				pointerMask |= 0x10;
			}
			else if ( event.delta > 0 ) {
				pointerMask |= 0x04;
			}*/
			
			/*if (event.ctrlKey && !emulateRightButton) {
				writeKeyEvent(socket,0xFFE3,true);
			}
			if (event.altKey) {
				writeKeyEvent(socket,0xFFE1,true);
			}
			if (event.shiftKey) {
				writeKeyEvent(socket,0xFFE9,true);
			}*/
			if (event.buttonDown) {
				if (emulateRightButton && event.ctrlKey) {
					pointerMask |= 0x04;
				} else {
					pointerMask |= 0x01;
				}
			}
			
			socket.writeByte(RFBConst.PointerEvent);
			socket.writeByte(pointerMask);
			socket.writeShort(event.localX);
			socket.writeShort(event.localY);
			
			/*if (event.ctrlKey && !emulateRightButton) {
				writeKeyEvent(socket,0xFFE3,false);
			}
			if (event.altKey) {
				writeKeyEvent(socket,0xFFE1,false);
			}
			if (event.shiftKey) {
				writeKeyEvent(socket,0xFFE9,false);
			}*/
			
			socket.flush();
		}
		
		public static function writeKeyEvent(socket:Socket, keyCode:uint, pushed:Boolean):void {
			socket.writeByte(RFBConst.KeyboardEvent);
			socket.writeByte(pushed ? 1 : 0);
			socket.writeByte(0);
			socket.writeByte(0);
			socket.writeUnsignedInt(keyCode);
		}
		
		/* handles keys events
		*	this is full of bugs
		*/
		private static var crtDown:Boolean = false;
		public static function writeKeyboardEvent(socket:Socket, event:flash.events.KeyboardEvent):void {
			/*if (event.keyCode == Keyboard.SHIFT || 
				event.keyCode == Keyboard.CONTROL) {
					return;
				}
				
			if (event.ctrlKey) {
				writeKeyEvent(socket,0xFFE3,true);
			}
			if (event.altKey) {
				writeKeyEvent(socket,0xFFE1,true);
			}
			if (event.shiftKey) {
				writeKeyEvent(socket,0xFFE9,true);
			}*/
			
			var keysym:uint;
			
			logger.log(event.charCode);
			logger.log(event.keyCode);
			logger.log(event.keyLocation);
			
			switch ( event.keyCode ) {
				case Keyboard.BACKSPACE : keysym = 0xFF08; break;
				case Keyboard.TAB       : keysym = 0xFF09; break;
				case Keyboard.ENTER     : keysym = 0xFF0D; break;
				case Keyboard.ESCAPE    : keysym = 0xFF1B; break;
				case Keyboard.INSERT    : keysym = 0xFF63; break;
				case Keyboard.DELETE    : keysym = 0xFFFF; break;
				case Keyboard.HOME      : keysym = 0xFF50; break;
				case Keyboard.END       : keysym = 0xFF57; break;
				case Keyboard.PAGE_UP   : keysym = 0xFF55; break;
				case Keyboard.PAGE_DOWN : keysym = 0xFF56; break;
				case Keyboard.LEFT   	: keysym = 0xFF51; break;
				case Keyboard.UP   		: keysym = 0xFF52; break;
				case Keyboard.RIGHT   	: keysym = 0xFF53; break;
				case Keyboard.DOWN   	: keysym = 0xFF54; break;
				case Keyboard.F1   		: keysym = 0xFFBE; break;
				case Keyboard.F2   		: keysym = 0xFFBF; break;
				case Keyboard.F3   		: keysym = 0xFFC0; break;
				case Keyboard.F4   		: keysym = 0xFFC1; break;
				case Keyboard.F5   		: keysym = 0xFFC2; break;
				case Keyboard.F6   		: keysym = 0xFFC3; break;
				case Keyboard.F7   		: keysym = 0xFFC4; break;
				case Keyboard.F8   		: keysym = 0xFFC5; break;
				case Keyboard.F9   		: keysym = 0xFFC6; break;
				case Keyboard.F10  		: keysym = 0xFFC7; break;
				case Keyboard.F11  		: keysym = 0xFFC8; break;
				case Keyboard.F12  		: keysym = 0xFFC9; break;
				case Keyboard.CONTROL : keysym = 0xFFE3;
					crtDown = event.type == flash.events.KeyboardEvent.KEY_DOWN ? true: false;
					break;
				case Keyboard.SHIFT : keysym = 0xFFE1;break;
				default:
					return;
					keysym = event.charCode;
			}
			
			if (event.type == flash.events.KeyboardEvent.KEY_UP && crtDown)  {
				writeKeyEvent(socket,keysym,true);
				writeKeyEvent(socket,keysym,false);
				writeKeyEvent(socket,0xFFE3,false);
				crtDown = false;
			} else{
				writeKeyEvent(socket,keysym,event.type == flash.events.KeyboardEvent.KEY_DOWN ? true: false);
			}
			
			/*if (event.ctrlKey) {
				writeKeyEvent(socket,0xFFE3,false);
			}
			if (event.altKey) {
				writeKeyEvent(socket,0xFFE1,false);
			}
			if (event.shiftKey) {
				writeKeyEvent(socket,0xFFE9,false);
			}*/
			
			socket.flush();
		} 
	}
}