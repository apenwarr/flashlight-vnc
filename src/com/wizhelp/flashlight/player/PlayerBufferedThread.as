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
	import com.wizhelp.flashlight.fbs.FBSListener;
	import com.wizhelp.flashlight.fbs.FBSReader;
	import com.wizhelp.flashlight.rfb.RFBReader;
	import com.wizhelp.utils.Thread;
	
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.geom.Rectangle;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.getQualifiedClassName;
	
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	public class PlayerBufferedThread extends Thread implements FBSListener {
		
		private static var logger:ILogger = Log.getLogger('com.wizhelp.flashlight.player.PlayerEmbedThread');
		
		private var rfbReader:RFBReader;
		private var fbsReader:FBSReader;
		private var player:Player;
		private var totalLength:int = -1;
		
		public var pre_processing_time:int = 3000;
		
		public function PlayerBufferedThread(player:Player, rfbReader:RFBReader, videoBytes:ByteArray) {
			this.rfbReader = rfbReader;
			this.player = player;
			this.fbsReader = new FBSReader(this);
			
			var rfbData:ByteArray = new ByteArray();
			totalLength = videoBytes.length;
			
			fbsReader.input = videoBytes;
			fbsReader.output = rfbData;
			rfbReader.input = rfbData;
		}
		
		override public function run():void {
			logger.debug(">> run()");
			
			runFBS();
			
			logger.debug("<< run()");
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
				if (player.videoDuration == -1) {
					player.videoDuration = player.preBufferingPosition;
				} else {
					player.preBufferingPosition = player.videoDuration;
				}
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
					// Force end of buffering
					logger.warn('Incorrect video file size, force end');
					player.handlePreBufferingCompleted();
					if (player.videoDuration == -1) {
						player.videoDuration = player.preBufferingPosition;
					} else {
						player.preBufferingPosition = player.videoDuration;
					}
				}
			}
			//sleep(20);
			//logger.log("<< runFBS()");
		}
		
		public function onVideoDuration(duration:int):void {
			logger.debug(">> onVideoDuration()");
			
			player.videoDuration = duration;
			
			logger.debug("<< onVideoDuration()");
		}
		
		public function onClipRectangle(clipRectangle:Rectangle):void {
			logger.debug(">> onClipRectangle()");
			
			player.setClipRectangle(clipRectangle);
			
			logger.debug("<< onClipRectangle()");
		}
	}
}