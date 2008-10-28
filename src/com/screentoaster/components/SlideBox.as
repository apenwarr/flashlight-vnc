package com.screentoaster.components
{	
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.ui.Mouse;
	import flash.utils.Timer;
	
	import mx.containers.Box;
	import mx.core.Application;
	import mx.events.FlexEvent;
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	public class SlideBox extends Box
	{
		/* private fields*/
		private var slideDirection:int = -1;
		private var started:Boolean = false;
		private var positionsDefined:Boolean = false;
		private var yMax:int;
		private var yMin:int;
		private var realY:Number;
		private var durationFactor:int = 300;
		private var step:Number;
		
		private var timer:Timer;
		private static var logger:ILogger = Log.getLogger('com.screentoaster.components.SlideBox');
		
		public function SlideBox() {
			super();
			addEventListener(FlexEvent.CREATION_COMPLETE, handleCreationCompleted);
		}
		
		private function handleCreationCompleted(event:FlexEvent):void {
			//logger.debug(">> handleCreationCompleted()");
			
			removeEventListener(FlexEvent.CREATION_COMPLETE, handleCreationCompleted);
			Application.application.addEventListener(MouseEvent.MOUSE_MOVE, handleMouseMove);
			timer = new Timer(3000,0);
			timer.addEventListener(TimerEvent.TIMER, handleTimerComplete);
			timer.start();
			
			//logger.debug("<< handleCreationCompleted()");
		}
		
		private function handleTimerComplete(event:TimerEvent):void {
			//logger.debug(">> handleTimerComplete()");
			
			if (!Application.application.parent) {
				Mouse.hide();
			}
			slideDown();
			timer.stop();
			
			//logger.debug("<< handleTimerComplete()");
		}
		
		private function handleMouseMove(event:MouseEvent):void {
			//logger.debug(">> handleMouseMove()");
			
			if (!timer.running) {
				Mouse.show();
				slideUp();
			}
			
			timer.reset();
			timer.start();
			
			//logger.debug("<< handleMouseMove()");
		}
		
		public function slideUp():void {
			//logger.debug(">> slideUp()");
			
			slideDirection = -1;
			start();
			
			//logger.debug("<< slideUp()");
		}
		
		public function slideDown():void {
			//logger.debug(">> slideDown()");
			
			slideDirection = 1;
			start();
			
			//logger.debug("<< slideDown()");
		}
		
		/* private methods */
		
		private function start():void {
			//logger.debug(">> start()");
			
			if (!positionsDefined) {
				yMin = y ;
				yMax = y + height;
				realY = y;
				step = height * 1000 / durationFactor / stage.frameRate;
				positionsDefined = true;
			}
			
			if (!started) {
				started =  true;
				addEventListener(Event.ENTER_FRAME,slide);
			}
			
			//logger.debug("<< start()");
		}
		
		private function stop():void {
			//logger.debug(">> stop()");
			
			started = false;
			removeEventListener(Event.ENTER_FRAME,slide);
			
			//logger.debug("<< stop()");
		}

		private function slide(event:Event):void {
			//logger.debug(">> slide()");
			
			realY+= step*slideDirection;
			y = realY;
			
			if (y>yMax) {
				realY = y = yMax;
				stop();
			} else if (y < yMin) {
				realY = y = yMin;
				stop();
			}
			
			//logger.debug("<< slide()");
		}
	}
}