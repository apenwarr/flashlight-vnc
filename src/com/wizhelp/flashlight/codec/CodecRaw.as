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
	Support of raw encoding
*/

package com.wizhelp.flashlight.codec
{
	import com.wizhelp.flashlight.rfb.RFBReader;
	import com.wizhelp.flashlight.thread.DataHandler;
	import com.wizhelp.flashlight.vnc.VNCHandler;
	import com.wizhelp.utils.BufferPool;
	
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;

	public class CodecRaw extends DataHandler
	{
		public function CodecRaw(vnc:VNCHandler, rfbReader:RFBReader)
		{
			super(0,
				function(stream:IDataInput):void {
					var rawDataBuffer:ByteArray = BufferPool.getDataBuffer(this.bytesNeeded);
					var pixelsBuffer:ByteArray = BufferPool.getDataBuffer(4*rfbReader.updateRectW*rfbReader.updateRectH);
					
					stream.readBytes(rawDataBuffer,0,this.bytesNeeded);
					rawDataBuffer.position = 0;
					
					rfbReader.readPixels(
						rawDataBuffer,
						pixelsBuffer,
						rfbReader.updateRectW*rfbReader.updateRectH);
					
					BufferPool.releaseDataBuffer(rawDataBuffer);
					
					vnc.handleUpdateImage(
						rfbReader.updateRect,
						pixelsBuffer);
				});
		}
		
	}
}