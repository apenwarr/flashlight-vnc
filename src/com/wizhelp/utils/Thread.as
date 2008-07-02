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
	Simulates multi-threading in Flash
	
	This is competly bugged and only works for one thread in NormalPriority
*/

package com.wizhelp.utils
{
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	
	import mx.controls.Text;
	
	public class Thread {
		// ************* Constants **************
		/** max time (in ms) between leaving hand to system */
		private static const MAX_BUSY_TIME:int = 500;
		
		// Thread priorities
		/** Highest priority, higher than system threads */
		public static const PRIORITY_HIGH:int = 1;
		/** Normal priority, same as system threads */
		public static const PRIORITY_NORMAL:int = 0;
		/** Lower priority, lower than system threads */
		public static const PRIORITY_LOW:int = -1;
		
		// Thread states
		/** Not started yet */
		private static const STATE_NOT_STARTED:int = 0;
		/** Running */
		private static const STATE_RUNNING:int = 1;
		/** Finished (could be start again) */
		private static const STATE_FINISHED:int = 2;
		/** Waiting on an object */
		private static const STATE_WAITING:int = 3;
		/** Sleeping */
		private static const STATE_SLEEPING:int = 4;
		
		// ************* Static fields **************
		/** Logger */
		private static var logger:Logger = new Logger(Thread);
		
		/** Array of array of Threads, group by priorities */
		private static var threads:Array = new Array();
		
		/** Thread currently executed */
		public static var currentThread:Thread = null;
		
		// ************* PseudoThread fields **************
		/** List of functions to call for this thread */
		public  var stack:Array = new Array();
		
		/** Function currently executed */
		private var currentFunction:Function = null;
		
		/** State of this thread */
		private var state:int = STATE_NOT_STARTED;
		
		/** Last time this thread has ran */
		private var lastRunTime:int = 0;
		
		/** If waiting, it waits for a particular event on this object */
		private var waitingObject:EventDispatcher = null;
		
		/** If waiting, it waits for this event type */
		private var waitingEvent:String = null;
		
		// ************* Functions **************
		/** Constructor */
		public  function Thread(runFunction:Function = null, priority:int = PRIORITY_NORMAL) {
			logger.log(">> Thread()");
			
			var threadsSamePriority:Array = threads[priority];
			
			if (threadsSamePriority == null) {
				threadsSamePriority = new Array();
				threads[priority] = threadsSamePriority;
			}
			
			threadsSamePriority.push(this);
			if (runFunction != null) {
				stack.push(runFunction);
			}
			
			systemManager.stage.addChild(displayObject);
			systemManager.stage.addEventListener(Event.ENTER_FRAME,enterFrameHandler,false,100);
			
			displayObject.addEventListener(Event.RENDER,dispatchCPUTime,false,100);
			
			state = 	STATE_NOT_STARTED;
			stack.push(this.run);
			
			logger.log("<< Thread()");
		}
		
		/** Start this thread */
		public function start():void {
			logger.log(">> start()");
			
			switch (state) {
				case STATE_NOT_STARTED:
				case STATE_FINISHED:
					awakeThread();
					break;
				default:
					throw new Error("Cannot start thread, bad state:"+state);
			}
			
			logger.log("<< start()");
		}
		
		public function run():void {
			logger.log(">> run()");
			
			logger.log("<< run()");
		}
		
		/** Sleep (time in ms) */
		public function sleep(duration:int):void {
			//logger.log(">> sleep()");
			
			state = STATE_SLEEPING;
			setTimeout(awakeThread,duration);
			
			//logger.log("<< sleep()");
		}
		
		/** Wait until the object send a specified event */
		public function wait(object:EventDispatcher, eventType:String):void {
			//logger.log(">> wait()");
			
			state = STATE_WAITING;
			object.addEventListener(eventType, awakeThread);
			waitingObject = object;
			waitingEvent = eventType;
			
			//logger.log("<< wait()");
		}
		
		/** Awake a sleeping or waiting thread */
		private function awakeThread(event:Event = null):void {
			//logger.log(">> awakeThread()");
			
			if (state == STATE_WAITING) {
				waitingObject.removeEventListener(waitingEvent,awakeThread);
			}
			
			state = STATE_RUNNING;
			
			//logger.log("<< awakeThread()");
		}
		
		/** Run the next function in functions list for this thread */
		private function runPart():void {
			//logger.log(">> runPart()");
			
			currentThread = this;
			currentFunction = stack.shift();
			lastRunTime = getTimer();
			
			if (currentFunction !=null) {
				try {
					currentFunction.call(currentThread);
				} catch (e:Error) {
					logger.log("An error occured during thread execution : "+e.getStackTrace());
				}
			} else {
				state = STATE_FINISHED;
			}
			
			currentThread = null;
			currentFunction = null;
			
			//logger.log("<< runPart()");
		}
		
		public static var systemManager:MovieClip;
		private static var start:int = 0;
		public static var out:Text;
		public static var totalTime:int;
		private static var end:int;
		
		/** Dispatch CPU time between threads and background system tasks */
		private static function dispatchCPUTime(event:Event=null):void {
			//logger.log(">> dispatchCPUTime()");
			
			if (start == 0 ) start = getTimer();
			var runningStart:int = getTimer();
			//logger.log((runningStart-last)+"");
			
			for (var i:int=PRIORITY_HIGH; i>=PRIORITY_LOW ; i--) {
				var threadsSamePriority:Array = threads[i];
				
				if (threadsSamePriority != null) {
					
					while (true) {
						var oldestRun:int = int.MAX_VALUE;
						var threadToRun:Thread = null;
						
						for each (var thread:Thread in threadsSamePriority) {
							if (thread.state == STATE_RUNNING) {
								thread.runPart();
								if (oldestRun>thread.lastRunTime) {
									oldestRun = thread.lastRunTime;
									threadToRun = thread;
								}
							}
						}
						
						if (i == PRIORITY_NORMAL) {
							var currentTime:int = getTimer();
							if (currentTime > end) {
								totalTime += currentTime-runningStart;
								//out.text = String(totalTime/(currentTime-start));
								//setTimeout(dispatchCPUTime,70);
								//Application.application.stage.invalidate();
								//logger.log("<< dispatchCPUTime()");
								return;
							}
						}
						
						if (threadToRun != null) {
							//threadToRun.runPart();
						} else {
							break;
						}
					}
					
					threads[i] = threadsSamePriority.filter(filterInactive);
				}
			}
			
			//logger.log("<< dispatchCPUTime()");
		}
		
		private static  function filterInactive(thread:Thread, index:int, arr:Array):Boolean {
			return thread.state != STATE_FINISHED;
		}
		
		private static var displayObject:DisplayObject = new Sprite();
		
		private static function enterFrameHandler(event:Event):void {
			var start:int = getTimer();
			var fr:Number = Math.floor(1000 / systemManager.stage.frameRate);
			end = start + fr;
			
			systemManager.stage.invalidate();
		 }
	}
	
}