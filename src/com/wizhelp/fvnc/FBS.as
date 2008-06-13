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
	Read a stream of data in FBS 1.0 format
	
	TODO: create a FBS 2.0 format with the following features:
		_ total time of video just after the header
		_ timestamp before the data block instead of after (will be better for streaming)
		_ remove the constraint to have data block length a multiple of 4 bytes
		_ add supoort for different kinds of data (the idea is to add a sound track)
*/


package com.wizhelp.fvnc
{
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.setTimeout;
	
	public class FBS
	{	
		private var logger:Logger = new Logger(this);
		
		private var fbsPacketSize:uint;
		private var fbsPacketSizeIgnored:uint;
		private var startTime:Number;
		private var filePosition:int=0;
		
		private static const readAheadTime:int = 2000;
		
		public var onIncomingData:Function;
		
		private var handleFBS:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				fbsStack.push(handleFBSVersion);
				fbsStack.push(handleFBSPacket);
			});
		
		private var handleFBSVersion:DataHandler = new DataHandler(
			12,
			function(stream:IDataInput):void {
				var version:String = stream.readUTFBytes(12);
				logger.log(version);
				startTime=(new Date()).getTime();
				filePosition+=12;
			});
		
		private var handleFBSPacket:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				fbsStack.push(handleFBSPacketHeader);
				fbsStack.push(handleFBSPacketData);
				fbsStack.push(handleFBSPacketTimeStamp);
			});
		
	 	private var handleFBSPacketHeader:DataHandler = new DataHandler(
			4,
			function(stream:IDataInput):void {
				fbsPacketSize = stream.readUnsignedInt();
				fbsPacketSizeIgnored = (4 - (fbsPacketSize % 4)) % 4;
				handleFBSPacketData.bytesNeeded = fbsPacketSize + fbsPacketSizeIgnored;
				filePosition+=4;
				/*output.text+="packet size:"+fbsPacketSize+"\n";
				output.text+="fbsPacketSizeIgnored :"+fbsPacketSizeIgnored+"\n";*/
			});
		
		private var fbsBuffer:ByteArray;
		private var handleFBSPacketData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				fbsBuffer = new ByteArray();
				stream.readBytes(fbsBuffer,0,fbsPacketSize);
				for (var i:int=0;i<fbsPacketSizeIgnored;i++) {
					stream.readByte();
				}
				filePosition+=fbsPacketSize+fbsPacketSizeIgnored;
			});
		
		private var handleFBSPacketTimeStamp:DataHandler = new DataHandler(
			4,
			function(stream:IDataInput):void {
				var timeStamp:uint = stream.readUnsignedInt();
				filePosition+=4;
				
				var currentTime:Number = (new Date()).getTime();
				
				/*output.text+="buffer size : "+fbsBuffer.length+"\n";
				output.text+="time stamp :"+timeStamp+"\n";*/
				
				if (currentTime>startTime+timeStamp) {
					startTime = currentTime - timeStamp + 5;
				}
				
				setTimeout(handleOutcomingData,startTime+timeStamp-currentTime,stream);
			});
			
		private var fbsStack:Array = new Array();
		private var fbsHandler:DataHandler = handleFBS;
		
		public function handleData(stream:IDataInput):void {
			if (fbsHandler ==  null) {
				fbsHandler = fbsStack.shift();
			}
			while (!paused && fbsHandler != null && stream.bytesAvailable >= fbsHandler.bytesNeeded) {
				fbsHandler.call(stream);
				fbsHandler = fbsStack.shift();
			}
		}
		
		private var outcomingBuffer:ByteArray = new ByteArray();
		private function sendData():void {
			var oldPos:int = outcomingBuffer.position;
			outcomingBuffer.position = outcomingBuffer.length;
			outcomingBuffer.writeBytes(fbsBuffer);
			outcomingBuffer.position = oldPos;
			//output.text+="total buffer : "+outcomingBuffer.length+"\n";
			onIncomingData(outcomingBuffer,filePosition);
			fbsStack.push(handleFBSPacket);
		}
		
		private function handleOutcomingData(stream:IDataInput):void {
			sendData();
			handleData(stream);
		}
		
		private var paused:Boolean = false;
		public function next(stream:IDataInput):void {
			if (fbsHandler ==  null) {
				fbsHandler = fbsStack.shift();
			}
			if (fbsHandler != null && stream.bytesAvailable >= fbsHandler.bytesNeeded) {
				fbsHandler.call(stream);
				fbsHandler = fbsStack.shift();
			}
		}
		
		private var pauseStartTime:int;
		public function pause():void {
			paused = true;
			pauseStartTime = (new Date()).getTime();
		}
		
		public function play(stream:IDataInput):void {
			paused = false;
			var currentTime:int = (new Date()).getTime();
			startTime += currentTime - pauseStartTime;
			handleData(stream);
		}
	}
}