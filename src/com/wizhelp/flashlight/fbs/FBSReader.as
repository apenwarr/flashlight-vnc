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
	Read a stream of data in FBS 1.0 format
	
	TODO: create a FBS 2.0 format with the following features:
		_ total time of video just after the header
		_ timestamp before the data block instead of after (will be better for streaming)
		_ remove the constraint to have data block length a multiple of 4 bytes
		_ add supoort for different kinds of data (the idea is to add a sound track)
*/


package com.wizhelp.flashlight.fbs
{
	import com.wizhelp.flashlight.thread.DataHandler;
	import com.wizhelp.utils.Logger;
	
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.getTimer;
	
	public class FBSReader
	{	
		private var logger:Logger = new Logger(this);
		
		private var fbsPacketSize:uint;
		private var fbsPacketSizeIgnored:uint;
		private var startTime:int;
		public var filePosition:int=0;
		
		public var input:IDataInput;
		public var output:ByteArray;
		
		public var newDataBlock:Boolean = false;
		public var dataBlockTime:int;
			
		private var fbsStack:Array = new Array();
		
		public function FBSReader() {
			fbsStack.push(handleFBS);
		}
		
		public function hasEnoughData():Boolean {
			if (fbsStack.length > 0 && input.bytesAvailable >= fbsStack[0].bytesNeeded) {
				return true;
			}
			return false;
		}
		
		public function run():void {
			var fbsHandler:DataHandler = fbsStack.shift();
			fbsHandler.call(input);
		}
		
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
				startTime=getTimer();
				filePosition+=12;
			});
		
		private var handleFBSPacket:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				newDataBlock = false;
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
				dataBlockTime = stream.readUnsignedInt();
				filePosition+=4;
				
				var oldPos:int = output.position;
				output.position = output.length;
				output.writeBytes(fbsBuffer);
				output.position = oldPos;
				newDataBlock = true;
				fbsStack.push(handleFBSPacket);
			});
	}
}