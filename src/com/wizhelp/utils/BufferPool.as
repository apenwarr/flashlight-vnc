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
 *  Manage a pool of buffers, to reuse buffers (big objects)
*/

package com.wizhelp.utils
{
	import flash.utils.ByteArray;
	
	public class BufferPool
	{
		/* Since we are seeking speed, we don't want to rely on Flash
		 * garbage collector for heavy objects.
		 * We manage our own pool of buffers and reuse them. */
		private static var bufferPool:Array = new Array();
		
		private static const MAX_BUFFER_POOL_SIZE:int = 30;
		
		public static function getDataBuffer(minSize:int):ByteArray {
			var buffer:ByteArray;
			if (bufferPool.length == 0) {
				buffer = new ByteArray();
			} else {
				buffer = bufferPool.shift();
			}
			
			if (buffer.length < minSize) {
				buffer.length = minSize;
			}
			buffer.position = 0;
			return buffer;
		}
		
		public static function releaseDataBuffer(buffer:ByteArray):void {
			if (bufferPool.length<MAX_BUFFER_POOL_SIZE) {
				bufferPool.push(buffer);
			}
		}

	}
}