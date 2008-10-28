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
	Uncompress a stream of Zlib data.
	Use FZlib
*/

package com.wizhelp.flashlight.zlib
{
	import com.wizhelp.fzlib.FZlib;
	import com.wizhelp.fzlib.ZStream;
	import com.wizhelp.utils.Thread;
	import com.wizhelp.utils.ThreadFunction;
	
	import flash.utils.ByteArray;
	
	public class InflaterFZlib
	{
		private var zstream:ZStream;
		public var uncompressedData:ByteArray;
		
		public function InflaterFZlib() {
			zstream = new ZStream();
			var err:int=zstream.inflateInit();
			if (err!=FZlib.Z_OK) {
				throw new Error(zstream.msg,err);
			}
		}
		
		
		public function inflate(data:ByteArray, compressedDataSize:int, uncompressedDataSize:int):void {			
			uncompressedData = new ByteArray();
			
			zstream.next_in=data;
			zstream.next_in_index=0;
			zstream.avail_in = compressedDataSize;
			
			zstream.next_out=uncompressedData;
		    zstream.next_out_index=0;
		    zstream.avail_out=uncompressedDataSize;
	        var err:int=zstream.inflate(FZlib.Z_NO_FLUSH);
	        if (err!=FZlib.Z_OK) {
			  throw new Error(zstream.msg,err);
		    }
		}
		
		private var remainingData:int;
		private static const MAX_DATA_PER_CYCLE:int = 100;
		public function inflateThreaded(data:ByteArray, compressedDataSize:int, uncompressedDataSize:int):void {			
			uncompressedData = new ByteArray();
			
			zstream.next_in=data;
			zstream.next_in_index=0;
			
			zstream.next_out=uncompressedData;
		    zstream.next_out_index=0;
		    zstream.avail_out=uncompressedDataSize;
		    
		    remainingData = compressedDataSize;
		    
		    Thread.currentThread.stack.unshift(new ThreadFunction(this,inflatePart));
		}
		
		public function inflatePart():void {
			var processDataSize:int = Math.min(MAX_DATA_PER_CYCLE,remainingData);
			zstream.avail_in = processDataSize;
			remainingData-=processDataSize;
			
	        var err:int=zstream.inflate(FZlib.Z_NO_FLUSH);
	        if (err!=FZlib.Z_OK) {
			  throw new Error(zstream.msg,err);
		    }
		    
		    if (remainingData != 0) {
		    	Thread.currentThread.stack.unshift(new ThreadFunction(this,inflatePart));
		    }
		}
	}
}