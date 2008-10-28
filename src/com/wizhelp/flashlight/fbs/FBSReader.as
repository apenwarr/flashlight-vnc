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
	Read a stream of data in FBS 1.0 and FBS 2.0 format
	
	TODO: create a FBS 2.0 format with the following features:
		_ total time of video just after the header
		_ timestamp before the data block instead of after (will be better for streaming)
		_ remove the constraint to have data block length a multiple of 4 bytes
		_ add supoort for different kinds of data (the idea is to add a sound track)
*/


package com.wizhelp.flashlight.fbs
{
	import com.wizhelp.flashlight.thread.DataHandler;
	
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.getQualifiedClassName;
	
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	public class FBSReader
	{	
		private static var logger:ILogger = Log.getLogger('com.wizhelp.flashlight.fbs.FBSReader');
		
		private static const TYPE_RFB_STREAM:int = 0;
		private static const TYPE_HEADER_DURATION:int = -1;
		private static const TYPE_HEADER_CLIP:int = -2;
		
		private var fbsPacketType:int;
		private var fbsPacketSize:uint;
		private var fbsPacketSizeIgnored:uint;
		private var fbsBuffer:ByteArray = new ByteArray();
		public var filePosition:int=0;
		
		public var input:IDataInput;
		public var output:ByteArray;
		
		public var newDataBlock:Boolean = false;
		public var dataBlockTime:int;
			
		private var fbsStack:Array = new Array();
		
		private var listener:FBSListener = null;
		
		public function FBSReader(listener:FBSListener = null) {
			fbsStack.push(handleFBS);
			this.listener = listener;
		}
		
		public function hasEnoughData():Boolean {
			if (fbsStack.length > 0 && input.bytesAvailable >= fbsStack[0].bytesNeeded) {
				return true;
			}
			return false;
		}
		
		public function run():void {
			var fbsHandler:DataHandler = fbsStack.shift();
			fbsHandler.call.apply(fbsHandler.object,[input]);
		}
		
		private var handleFBS:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				fbsStack.push(handleFBSVersion);
			},
			this);
		
		private var handleFBSVersion:DataHandler = new DataHandler(
			12,
			function(stream:IDataInput):void {
				var version:String = stream.readUTFBytes(12);
				
				if (Log.isDebug()) {
					logger.debug(version.slice(0,11));
				}
				
				if (version == "FBS 001.000\n") {
					fbsStack.push(handleFBS1Packet);
				} else if (version == "FBS 002.000\n")  {
					fbsStack.push(handleFBS2Packet);
				} else {
					throw new Error('Unknown FBS file format : '+version);
				}
				filePosition+=12;
			},
			this);
			
		private var handleFBS2Packet:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				newDataBlock = false;
				fbsStack.push(handleFBS2PacketHeader);
				fbsStack.push(handleFBS2PacketData);
				fbsStack.push(handleFBS2Packet);
			},
			this);
			
		private var handleFBS2PacketHeader:DataHandler = new DataHandler(
			7,
			function(stream:IDataInput):void {
				fbsPacketType = stream.readByte();
				dataBlockTime = stream.readUnsignedInt();
				fbsPacketSize = stream.readUnsignedShort();
				handleFBS2PacketData.bytesNeeded = fbsPacketSize;
				
				filePosition+=7;
			},
			this);
			
		private var handleFBS2PacketData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				switch (fbsPacketType) {
					case TYPE_HEADER_DURATION:
						var duration:int = stream.readUnsignedInt();
						if (listener != null) {
							listener.onVideoDuration(duration);
						}
						break;
						
					case TYPE_HEADER_CLIP:
						var clipRectangle:Rectangle = new Rectangle(
							stream.readUnsignedInt(),
							stream.readUnsignedInt(),
							stream.readUnsignedInt(),
							stream.readUnsignedInt());
						
						if (listener != null) {
							listener.onClipRectangle(clipRectangle);
						}
							
						break;
					case TYPE_RFB_STREAM:
						var oldPos:int = output.position;
						fbsBuffer.position = 0;
						stream.readBytes(fbsBuffer,0,fbsPacketSize);
						output.position = output.length;
						output.writeBytes(fbsBuffer,0,fbsPacketSize);
						output.position = oldPos;
						newDataBlock = true;
						break;
					default:
						throw new Error("Unknown FBS packet type : "+fbsPacketType);
				}
				
				filePosition+= handleFBS2PacketData.bytesNeeded;
			},
			this);
			
		private var handleFBS1Packet:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				newDataBlock = false;
				fbsStack.push(handleFBS1PacketHeader);
				fbsStack.push(handleFBS1PacketData);
				fbsStack.push(handleFBS1PacketTimeStamp);
				fbsStack.push(handleFBS1Packet);
			},
			this);
		
	 	private var handleFBS1PacketHeader:DataHandler = new DataHandler(
			4,
			function(stream:IDataInput):void {
				fbsPacketSize = stream.readUnsignedInt();
				fbsPacketSizeIgnored = (4 - (fbsPacketSize % 4)) % 4;
				handleFBS1PacketData.bytesNeeded = fbsPacketSize + fbsPacketSizeIgnored;
				filePosition+=4;
				/*output.text+="packet size:"+fbsPacketSize+"\n";
				output.text+="fbsPacketSizeIgnored :"+fbsPacketSizeIgnored+"\n";*/
			},
			this);
		
		private var handleFBS1PacketData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				fbsBuffer.position = 0;
				stream.readBytes(fbsBuffer,0,fbsPacketSize);
				for (var i:int=0;i<fbsPacketSizeIgnored;i++) {
					stream.readByte();
				}
				filePosition+=fbsPacketSize+fbsPacketSizeIgnored;
			},
			this);
		
		private var handleFBS1PacketTimeStamp:DataHandler = new DataHandler(
			4,
			function(stream:IDataInput):void {
				dataBlockTime = stream.readUnsignedInt();
				filePosition+=4;
				
				var oldPos:int = output.position;
				output.position = output.length;
				output.writeBytes(fbsBuffer,0,fbsPacketSize);
				output.position = oldPos;
				newDataBlock = true;
			},
			this);
	}
}