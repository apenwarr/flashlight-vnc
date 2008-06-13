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

package com.wizhelp.fvnc.codec
{
	import com.wizhelp.fvnc.DataHandler;
	import com.wizhelp.fvnc.RFB;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.geom.Rectangle;
	import flash.utils.IDataInput;

	public class CodecRichCursor extends DataHandler
	{
		private var rfb:RFB;
		
		public function CodecRichCursor(rfb:RFB)
		{
			super(0, 
				function(stream:IDataInput):void {
					var bytesPerRow:int = int(( rfb.updateRectW + 7 ) / 8);
					var x:int;
					var y:int;
					
					if (rfb.pixelsBuffer.length < 4*rfb.updateRectW*rfb.updateRectH) {
						rfb.pixelsBuffer.length = 4*rfb.updateRectW*rfb.updateRectH;
					}
					rfb.pixelsBuffer.position = 0;
					
					if (rfb.rawDataBuffer.length < rfb.updateRectW*rfb.updateRectH*rfb.bytesPerPixel) {
						rfb.rawDataBuffer.length = rfb.updateRectW*rfb.updateRectH*rfb.bytesPerPixel;
					}
					rfb.rawDataBuffer.position = 0;
					
					stream.readBytes(rfb.rawDataBuffer,0,rfb.updateRectW*rfb.updateRectH*rfb.bytesPerPixel);
					rfb.rawDataBuffer.position = 0;
					
					//readPixels2(rawDataBuffer,newImageData,updateRectW*updateRectH);
					rfb.readPixels(
						rfb.rawDataBuffer,
						rfb.pixelsBuffer,
						rfb.updateRectW*rfb.updateRectH);
					
					stream.readBytes(rfb.rawDataBuffer,0,bytesPerRow * rfb.updateRectH);
					rfb.rawDataBuffer.position = 0;
					
				    for (y = 0; y < rfb.updateRectH; y++) {
						var maskPos:int = 128;
						var maskBufPos:int = y * bytesPerRow;
						var maskByte:int  = rfb.rawDataBuffer[maskBufPos];
						for (x = 0; x < rfb.updateRectW; x++) {
							if ((maskByte & maskPos) == 0) {
								rfb.pixelsBuffer[(y*rfb.updateRectW+x)*4] = 0;
							}
							
							maskPos = maskPos >> 1;
							if (maskPos==0) {
								maskPos = 128;
								maskBufPos++;
								maskByte = rfb.rawDataBuffer[maskBufPos];
							}
						}
					}
					
					var cursorShape:BitmapData = new BitmapData(rfb.updateRectW,rfb.updateRectW,true);
					
					cursorShape.setPixels(cursorShape.rect,	rfb.pixelsBuffer);
					
					rfb.updateCursorShape(rfb.updateRectX,rfb.updateRectY,cursorShape);
				});
			
			this.rfb = rfb;
		}
		
	}
}