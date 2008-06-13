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

package com.wizhelp.fvnc.codec
{
	import com.wizhelp.fvnc.DataHandler;
	import com.wizhelp.fvnc.RFB;
	
	import flash.geom.Rectangle;
	import flash.utils.IDataInput;

	public class CodecRaw extends DataHandler
	{
		private var rfb:RFB;
		
		public function CodecRaw(rfb:RFB)
		{
			super(0,
				function(stream:IDataInput):void {
					if (rfb.rawDataBuffer.length < this.bytesNeeded) {
						rfb.rawDataBuffer.length = this.bytesNeeded;
					}
					rfb.rawDataBuffer.position = 0;
					
					if (rfb.pixelsBuffer.length < 4*rfb.updateRectW*rfb.updateRectH) {
						rfb.pixelsBuffer.length = 4*rfb.updateRectW*rfb.updateRectH;
					}
					rfb.pixelsBuffer.position = 0;
					
					stream.readBytes(rfb.rawDataBuffer,0,this.bytesNeeded);
					rfb.rawDataBuffer.position = 0;
					
					rfb.readPixels(
						rfb.rawDataBuffer,
						rfb.pixelsBuffer,
						rfb.updateRectW*rfb.updateRectH);
					
					rfb.updateImage(
						rfb.updateRect,
						rfb.pixelsBuffer);
				});
				
			this.rfb = rfb;
		}
		
	}
}