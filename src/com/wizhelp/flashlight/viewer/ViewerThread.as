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
 *  Viewer background thread
*/

package com.wizhelp.flashlight.viewer
{
	import com.wizhelp.flashlight.rfb.RFBReader;
	import com.wizhelp.utils.Thread;
	
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.net.Socket;
	import flash.utils.getQualifiedClassName;
	
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	public class ViewerThread extends Thread {
		private static var logger:ILogger = Log.getLogger('com.wizhelp.flashlight.viewer.ViewerThread');
		
		private var rfb:RFBReader;
		private var socket:Socket;
		
		public function ViewerThread(rfb:RFBReader, socket:Socket) {
			this.rfb = rfb;
			this.socket = socket;
			
			rfb.input = socket;
		}
		
		override public function run():void {
			logger.debug(">> run()");
			
			if (socket.connected) {
				runRFB();
			} else {
				stack.push(runRFB);
				wait(socket,Event.CONNECT);
			}
			
			logger.debug("<< run()");
		}
		
		private function runRFB():void {
			//logger.log(">> runRFB()");
			
			if (socket.connected) {
				if (rfb.hasEnoughData()) {
					rfb.run();
					stack.push(runRFB);
				} else {
					//logger.log("Waiting for data");	
					wait(socket,ProgressEvent.SOCKET_DATA);
					stack.push(runRFB);
				}
			} else {
				logger.debug("Socket closed");	
			}
			
			//logger.log("<< runRFB()");
		}
	}
}