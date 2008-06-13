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
	Simple logger to log in a Flex text control.
	(I don't like trace() function in flash ...)
*/

package com.wizhelp.fvnc
{
	import flash.utils.getQualifiedClassName;
	import mx.controls.Text;
	
	public class Logger
	{
		public static var output:Text;
		
		private var name:String;
		
		public function Logger(object:Object) {
			name = getQualifiedClassName(object); 
		}
		
		private static var timersStart:Object = new Object();
		private static var timers:Object = new Object();
		
		public function timeStart(identifier:String):void {
			timersStart[identifier] = (new Date()).getTime();
		}
		
		public function timeEnd(identifier:String):void {
			if (timers[identifier] == undefined) timers[identifier]=0; 
			timers[identifier] += (new Date()).getTime() - timersStart[identifier];
		}
		
		public static  function logTimers():void {
			for (var name:String in timers) {
				output.text+=name+" "+timers[name]+"\n";
			}
		}
		
		public function log(string:String):void {
			if (output!=null) {
				output.text+=string+"\n";
				//output.text.concat(string,"\n");
			}
		}
	}
}