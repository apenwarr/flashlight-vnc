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
	Player core class
*/

package com.wizhelp.flashlight.player
{
	import com.wizhelp.flashlight.rfb.RFBReader;
	import com.wizhelp.flashlight.vnc.VNCBase;
	import com.wizhelp.utils.Logger;
	import com.wizhelp.utils.Thread;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.getTimer;
	
	import mx.core.Application;
	
	[Event( name="videoEnd", type="flash.events.Event" )]
	
	public class Player extends VNCBase {
		
		[Bindable] public var videoUrl:String;
		[Bindable] public var videoLoader:URLStream = null;
		[Bindable] public var videoDuration:int = -1;
		
		private var logger:Logger = new Logger(Player);
		private var playerThread:PlayerThread = null;
		private var baseTime:int;
		private var waitingBuffering:Boolean;
		
		public function play():void {
			logger.log(">> play()");
			
			if ( playerThread == null) {
				videoLoader = new URLStream();
			
				var rfb:RFBReader = new RFBReader(this);
				
				Thread.systemManager = Application.application.systemManager;
				playerThread = new PlayerThread(this, rfb, videoLoader);
				playerThread.start();
				
				videoLoader.addEventListener(Event.OPEN,handleDownloadStarted);
				videoLoader.addEventListener(Event.COMPLETE,handleDownloadFinished);
				videoLoader.addEventListener(IOErrorEvent.IO_ERROR,handleDownloadError);
				
				videoLoader.load(new URLRequest(videoUrl));
				
				waitingBuffering = true;
				currentPosition = 0;
				preBufferingPosition = -1;
			} else {
				baseTime = getTimer() - currentPosition;
				this.addEventListener(Event.ENTER_FRAME, updatePosition, false, 100);
			}
			
			logger.log("<< play()");
		}
		
		public function next():void {
			//fbsReader.next(fbsLoader);
		}
		
		public function pause():void {
			logger.log(">> pause()");
			
			this.removeEventListener(Event.ENTER_FRAME, updatePosition, false);
			
			logger.log("<< pause()");
		}
		
		private function updatePosition(event:Event):void {
			currentPosition = Math.max(getTimer() - baseTime, 0);
			
			if (videoDuration != -1 && currentPosition >= videoDuration ) {
				this.removeEventListener(Event.ENTER_FRAME, updatePosition, false);
				playerThread = null;
				currentPosition = videoDuration;
				
				var event:Event = new Event("videoEnd");
				dispatchEvent(event);
			} else 	if (currentPosition > preBufferingPosition) {
				waitingBuffering = true;
				this.removeEventListener(Event.ENTER_FRAME, updatePosition, false);
			}
		}
		
		private function handleDownloadStarted(event:Event):void {
			logger.log(">> handleDownloadStarted()");
			logger.log("<< handleDownloadStarted()");
		}
		
		private function handleDownloadFinished(event:Event):void {
			logger.log(">> handleDownloadFinished()");
			logger.log("<< handleDownloadFinished()");
		}
		
		private function handleDownloadError(event:IOErrorEvent):void {
			logger.log(">> handleDownloadError()");
			logger.log("<< handleDownloadError()");
		}
		
		public function handlePreBufferingCompleted():void {
			//logger.log(">> handlePreBufferingCompleted()");
			
			if (waitingBuffering) {
				baseTime = getTimer() - currentPosition;
				waitingBuffering = false;
				this.addEventListener(Event.ENTER_FRAME, updatePosition, false, 100);
			}
			
			//logger.log("<< handlePreBufferingCompleted()");
		}

	}
}