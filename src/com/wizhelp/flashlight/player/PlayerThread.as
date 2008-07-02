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
	Player background thread
*/

package com.wizhelp.flashlight.player
{
	import com.wizhelp.flashlight.fbs.FBSReader;
	import com.wizhelp.flashlight.rfb.RFBReader;
	import com.wizhelp.utils.Logger;
	import com.wizhelp.utils.Thread;
	
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	public class PlayerThread extends Thread {
		private static var logger:Logger = new Logger(PlayerThread);
		
		private var rfbReader:RFBReader;
		private var fbsReader:FBSReader;
		private var urlStream:URLStream;
		private var player:Player;
		private var totalLength:int = -1;
		
		public var pre_processing_time:int = 3000;
		
		public function PlayerThread(player:Player, rfbReader:RFBReader, urlStream:URLStream) {
			this.rfbReader = rfbReader;
			this.urlStream = urlStream;
			this.player = player;
			this.fbsReader = new FBSReader();
			
			var rfbData:ByteArray = new ByteArray();
			
			fbsReader.input = urlStream;
			fbsReader.output = rfbData;
			rfbReader.input = rfbData;
			
			urlStream.addEventListener(Event.COMPLETE, handleStreamCompleted);
			urlStream.addEventListener(ProgressEvent.PROGRESS, handleProgress);
		}
		
		override public function run():void {
			logger.log(">> run()");
			
			if (urlStream.connected) {
				runFBS();
			} else {
				stack.push(runFBS);
				wait(urlStream, ProgressEvent.PROGRESS);
			}
			
			logger.log("<< run()");
		}
		
		private function handleProgress(event:ProgressEvent):void {
			totalLength = event.bytesTotal;
			urlStream.removeEventListener(ProgressEvent.PROGRESS, handleProgress);
		}
		
		private function runRFB():void {
			//logger.log(">> runRFB()");
			if (rfbReader.hasEnoughData()) {
				rfbReader.run();
				stack.push(runRFB);
			} else {
				runFBS();
			}
			//logger.log("<< runRFB()");
		}
		
		private function runFBS():void {
			//logger.log(">> runFBS()");
			if (fbsReader.filePosition == totalLength) {
				player.handlePreBufferingCompleted();
				player.videoDuration = player.preBufferingPosition;
			} else {
				if (fbsReader.hasEnoughData()) {
					if (player.preBufferingPosition - player.currentPosition > pre_processing_time) {
						player.handlePreBufferingCompleted();
						sleep(200);
						stack.push(runFBS);
					} else {
						fbsReader.run();
						if (fbsReader.newDataBlock) {
							player.preBufferingPosition = fbsReader.dataBlockTime;
							stack.push(runRFB);
						} else {
							stack.push(runFBS);
						}
					}
				} else {
					stack.push(runFBS);
					logger.log('wait data');
					wait(urlStream, ProgressEvent.PROGRESS);
				}
			}
			//sleep(20);
			//logger.log("<< runFBS()");
		}
		
		private function handleStreamCompleted(event:Event):void {
			logger.log(">> handleStreamCompleted()");
			logger.log("<< handleStreamCompleted()");
		}
	}
}