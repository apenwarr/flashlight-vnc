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
	Support of cursorPos pseudo-encoding
*/

package com.wizhelp.fvnc.codec
{
	import com.wizhelp.fvnc.DataHandler;
	import com.wizhelp.fvnc.RFB;
	
	import flash.utils.IDataInput;

	public class CodecCursorPos extends DataHandler
	{
		private var rfb:RFB;
		
		public function CodecCursorPos(rfb:RFB)
		{
			super(0,
				function(stream:IDataInput):void {
					rfb.updateCursorPosition(rfb.updateRectX,rfb.updateRectY);
				});
			this.rfb = rfb;
		}
		
	}
}