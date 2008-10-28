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
	import com.wizhelp.utils.Thread;
	
	import flash.events.AsyncErrorEvent;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	import mx.core.Application;
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	[Event( name="videoPlay", type="flash.events.Event" )]
	[Event( name="videoPause", type="flash.events.Event" )]
	[Event( name="videoResume", type="flash.events.Event" )]
	[Event( name="videoEnd", type="flash.events.Event" )]
	[Event( name="videoRewind", type="flash.events.Event" )]
	
	public class Player extends VNCBase {
		
		[Bindable] public var videoUrl:String;
		[Bindable] public var videoLoader:URLStream = null;
		[Bindable] public var videoDuration:int = -1;
		
		[Bindable] public var audioUrl:String;
		[Bindable] public var audioLoader:NetConnection;
		[Bindable] public var audioPlayer:NetStream;
		
		[Bindable] public var playing:Boolean = false;
		
		private static var logger:ILogger = Log.getLogger('com.wizhelp.flashlight.player.Player');
		private var playerThread:Thread = null;
		private var baseTime:int;
		[Bindable] public var buffering:Boolean = false;
		[Bindable] public var hanged:Boolean = false;
		
		private var videoData:ByteArray;
		
		private var useAudioTimer:Boolean = false;
		
		public function set videoEmbed(value:Class):void {
			if (value) {
				videoData = new value() as ByteArray;
			}
		}
		
		public function set videoDurationDefault(value:int):void {
			if (videoDuration == -1 && value > 0) {
				videoDuration = value;
			}
		}
		
		public function play():void {
			logger.debug(">> play()");
			
			try {
				if (!playing) {
					playing = true;
					if ( playerThread == null) {
						Thread.systemManager = Application.application.systemManager;
						
						var rfb:RFBReader = new RFBReader(this,true);
						
						if (videoData == null) {
							videoLoader = new URLStream();
						
							videoLoader.addEventListener(IOErrorEvent.IO_ERROR,handleVideoConnectionError);
							videoLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleVideoConnectionError);
							videoLoader.addEventListener(Event.COMPLETE,handleVideoCompleted);
							
							videoLoader.load(new URLRequest(videoUrl));
							
							playerThread = new PlayerStreamingThread(this, rfb, videoLoader);
							playerThread.start();
						} else {
							videoData.position = 0;
							playerThread = new PlayerBufferedThread(this, rfb,videoData);
							playerThread.start();
						}
						
						buffering = true;
						currentPosition = 0;
						preBufferingPosition = -1;
						
						if (audioUrl != null) {
							audioLoader = new NetConnection();
							audioLoader.addEventListener(AsyncErrorEvent.ASYNC_ERROR, handleAudioConnectionError);
							audioLoader.addEventListener(IOErrorEvent.IO_ERROR, handleAudioConnectionError);
							audioLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,handleAudioConnectionError);
							audioLoader.addEventListener(NetStatusEvent.NET_STATUS, handleAudioLoaderStatus);
							audioLoader.connect(null);
							
							audioPlayer = new NetStream(audioLoader);
							audioPlayer.addEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAudioConnectionError);
							audioPlayer.addEventListener(IOErrorEvent.IO_ERROR, handleAudioConnectionError);
							audioPlayer.addEventListener(NetStatusEvent.NET_STATUS, handleAudioStatus);
							audioPlayer.play(audioUrl);
							audioPlayer.pause();
						}
						dispatchEvent(new Event("videoPlay"));
					} else {
						resumePlay();
					}
					
				}
			} catch (e:Error) {
					logger.error("An unexpected error occured during start playing : "+e.errorID+" "+e.name+" "+e.message+" "+e.getStackTrace());
			}
			
			logger.debug("<< play()");
		}
		
		private function handleAudioLoaderStatus(event:NetStatusEvent):void {
			if (event.info) {
				if (event.info.level == 'status') {
					switch (event.info.code) {
						case 'NetConnection.Connect.Success' :
							useAudioTimer = true;
							break;
						default:
					}
				} else if (event.info.level == 'error') {
					logger.error("An error occured when loading audio : "+event.info.code);
					useAudioTimer = false;
				}
			}
		}
		
		private function handleAudioStatus(event:NetStatusEvent):void {
			if (event.info) {
				if (event.info.level == 'status') {
					switch (event.info.code) {
						case  'NetStream.Play.Stop' :
							useAudioTimer = false;
							break;
						default:
					}
				} else if (event.info.level == 'error') {
					logger.error("An error occured when playing audio : "+event.info.code);
					useAudioTimer = false;
				}
			}
		}
		
		public function rewind():void {
			logger.debug(">> rewind()");
			
			try {
				pausePlayer();
				
				reset();
				playing = false;
				buffering = false;
				hanged = false;
				useAudioTimer = false;
				if (audioPlayer) {
					audioPlayer.close();
					audioPlayer = null;
				}
				if (audioLoader) {
					audioLoader.close();
					audioLoader = null;
				}
				if (playerThread!=null) {
					playerThread.kill();
					playerThread = null;
				}
				dispatchEvent(new Event("videoRewind"));
			} catch (e:Error) {
				logger.error("An unexpected error occured during rewind : "+e.errorID+" "+e.name+" "+e.message+" "+e.getStackTrace());
			}
			
			logger.debug("<< rewind()");
		}
		
		public function pause():void {
			logger.debug(">> pause()");
			
			try {
				if (playing) {
					pausePlayer();
					playing = false;
				}	
			} catch (e:Error) {
				logger.error("An unexpected error occured during rewind : "+e.errorID+" "+e.name+" "+e.message+" "+e.getStackTrace());
			}
			
			logger.debug("<< pause()");
		}
		
		public function hangPlay(time:int):void {
			logger.debug(">> hangPlay()");
			
			try {
				pausePlayer();
				hanged=true;
				var hangTimer:Timer = new Timer(time,1);
				hangTimer.addEventListener(TimerEvent.TIMER,handleHangedEnd);
				hangTimer.start();
			} catch (e:Error) {
				logger.error("An unexpected error occured during hangPlay : "+e.errorID+" "+e.name+" "+e.message+" "+e.getStackTrace());
			}
			
			logger.debug("<< hangPlay()");
		}
		
		private function pausePlayer():void {
			logger.debug(">> pausePlayer()");
			
			if (!buffering && !hanged && playing) {
				this.removeEventListener(Event.ENTER_FRAME, updatePosition, false);
				
				if (audioPlayer != null) {
					audioPlayer.pause();
				}
			}
					
			dispatchEvent(new Event("videoPause"));
			
			logger.debug("<< pausePlayer()");
		}
		
		private function resumePlay():void {
			logger.debug(">> resumePlay()");
			
			if (!buffering && !hanged && playing) {
				baseTime = getTimer() - currentPosition;
				this.addEventListener(Event.ENTER_FRAME, updatePosition, false, 100);
				
				if (audioPlayer != null) {
					audioPlayer.resume();
				}
			}
			
			dispatchEvent(new Event("videoResume"));
			
			logger.debug("<< resumePlay()");
		}
		
		override protected function startWaiting():void {
				pausePlayer();
				buffering = true;
		}
		
		override protected function stopWaiting(event:Event=null):void {
			if (buffering) {
				buffering = false;
				resumePlay();
			}
		}
		
		private function updatePosition(event:Event):void {
			try {
				if (!useAudioTimer) {
					currentPosition = Math.max(getTimer() - baseTime, 0);
				} else {
					currentPosition = audioPlayer.time * 1000;
					baseTime = getTimer() - currentPosition;
				}
				
				if (videoDuration != -1 && currentPosition >= videoDuration ) {
					logger.debug("End of video");
					
					pausePlayer();
					playing = false;
					
					playerThread = null;
					currentPosition = videoDuration;
					
					dispatchEvent(new Event("videoEnd"));
				}  else if (currentPosition > preBufferingPosition) {
					
					logger.debug("Wait for preBuffering");
					pausePlayer();
					buffering = true;
				}
			} catch (e:Error) {
				logger.error("An unexpected error occured when updating video position : "+e.errorID+" "+e.name+" "+e.message+" "+e.getStackTrace());
			}
		}
		
		private function handleVideoCompleted(event:Event):void {
			logger.debug(">> handleVideoCompleted()");
			
			videoData = (playerThread as PlayerStreamingThread).buffer;
			
			logger.debug("<< handleVideoCompleted()");
		}
		
		private function handleHangedEnd(event:TimerEvent):void {
			logger.debug(">> handleHangedEnd()");
			
			hanged = false;
			resumePlay();
				
			logger.debug("<< handleHangedEnd()");
		}
		
		private function handleVideoConnectionError(event:ErrorEvent):void {
			logger.error('Cannot load video ('+videoUrl+') : '+event.type+" "+event.text);
		}
		
		private function handleAudioConnectionError(event:ErrorEvent):void {
			logger.error('Cannot load audio ('+audioUrl+') : '+event.type+" "+event.text);
		}
		
		public function handlePreBufferingCompleted():void {
			//logger.debug(">> handlePreBufferingCompleted()");
			
			if (buffering) {
				buffering = false;
				resumePlay();
			}
			
			//logger.debug("<< handlePreBufferingCompleted()");
		}
	}
}