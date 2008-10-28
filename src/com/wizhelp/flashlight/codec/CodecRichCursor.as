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
	Support of richCursor pseudo-encoding
*/

package com.wizhelp.flashlight.codec
{
	import com.wizhelp.flashlight.rfb.RFBReader;
	import com.wizhelp.flashlight.thread.DataHandler;
	import com.wizhelp.flashlight.vnc.VNCHandler;
	import com.wizhelp.utils.BufferPool;
	
	import flash.display.BitmapData;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.getQualifiedClassName;
	
	import mx.logging.ILogger;
	import mx.logging.Log;

	public class CodecRichCursor extends DataHandler
	{	
		private static var logger:ILogger = Log.getLogger('com.wizhelp.flashlight.codec.CodecRichCursor');
		
		public function CodecRichCursor(vnc:VNCHandler, rfbReader:RFBReader)
		{
			super(0, 
				function(stream:IDataInput):void {
					//logger.debug(">> CodecRichCursor()");
					
					try {
						if (rfbReader.updateRectW==0 || rfbReader.updateRectH==0) {
							// server asks to hide cursor
							var cursorShapeEmpty:BitmapData = new BitmapData(32,32,true,0x00000000);
							vnc.handleUpdateCursorShape(32,32,cursorShapeEmpty);
						} else {
							var bytesPerRow:int = int(( rfbReader.updateRectW + 7 ) / 8);
							var x:int;
							var y:int;
							
							var rawDataBuffer:ByteArray = BufferPool.getDataBuffer(rfbReader.updateRectW*rfbReader.updateRectH*rfbReader.bytesPerPixel);
							var pixelsBuffer:ByteArray = BufferPool.getDataBuffer(4*rfbReader.updateRectW*rfbReader.updateRectH);
							
							stream.readBytes(rawDataBuffer,0,rfbReader.updateRectW*rfbReader.updateRectH*rfbReader.bytesPerPixel);
							rawDataBuffer.position = 0;
							
							//readPixels2(rawDataBuffer,newImageData,updateRectW*updateRectH);
							rfbReader.readPixels(
								rawDataBuffer,
								pixelsBuffer,
								rfbReader.updateRectW*rfbReader.updateRectH);
							
							stream.readBytes(rawDataBuffer,0,bytesPerRow * rfbReader.updateRectH);
							rawDataBuffer.position = 0;
							
						    for (y = 0; y < rfbReader.updateRectH; y++) {
								var maskPos:int = 128;
								var maskBufPos:int = y * bytesPerRow;
								var maskByte:int  = rawDataBuffer[maskBufPos];
								for (x = 0; x < rfbReader.updateRectW; x++) {
									if ((maskByte & maskPos) == 0) {
										pixelsBuffer[(y*rfbReader.updateRectW+x)*4] = 0;
									}
									
									maskPos = maskPos >> 1;
									if (maskPos==0) {
										maskPos = 128;
										maskBufPos++;
										maskByte = rawDataBuffer[maskBufPos];
									}
								}
							}
							
							var cursorShape:BitmapData = new BitmapData(rfbReader.updateRectW,rfbReader.updateRectH,true);
							
							cursorShape.setPixels(cursorShape.rect,	pixelsBuffer);
							
							BufferPool.releaseDataBuffer(rawDataBuffer);
							BufferPool.releaseDataBuffer(pixelsBuffer);
							
							vnc.handleUpdateCursorShape(rfbReader.updateRectX,rfbReader.updateRectY,cursorShape);
						}
					} catch (e:Error) {
						logger.error("An unexpected error occured in CodecRichCursor : "+e.errorID+" "+e.name+" "+e.message+" "+e.getStackTrace());
						throw e;
					}
					
					//logger.debug("<< CodecRichCursor()");
				},
				rfbReader);
		}
		
	}
}